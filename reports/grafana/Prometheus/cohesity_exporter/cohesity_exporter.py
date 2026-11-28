#!/usr/bin/env python3
"""
Cohesity DataProtect multi-cluster Prometheus exporter.

Polls one or more Cohesity clusters (directly by VIP + API key, or through
Helios) in a background thread and serves the cached results on /metrics.
Prometheus scrapes therefore never wait on a cluster, and one slow or
unreachable cluster cannot block the others' data from being served.

Requires pyhesity.py in the same directory (or on PYTHONPATH).

Usage:
    python3 cohesity_exporter.py --config config.yaml
"""
import argparse
import logging
import os
import signal
import sys
import threading
import time

import yaml
from prometheus_client import start_http_server
from prometheus_client.core import GaugeMetricFamily, REGISTRY

# pyhesity keeps its connection in module-level state, so every API interaction
# below happens from the single poller thread (never from the HTTP threads).
import pyhesity as ph

log = logging.getLogger('cohesity_exporter')

# Run statuses we always emit (value 0 when absent) so stacked graphs and
# alert rules never see a series appear/disappear.
CORE_RUN_STATUSES = ['Succeeded', 'SucceededWithWarning', 'Failed', 'Running',
                     'Canceled', 'Missed', 'Skipped', 'NoRun']

DEFAULTS = {
    'listen_port': 9792,
    'listen_address': '0.0.0.0',
    'scrape_interval': 60,        # seconds between polls of each target
    'request_timeout': 30,        # seconds per Cohesity API call
    'alerts_lookback_days': 365,  # window for /alerts-summary (open alerts only)
    'throughput_window_minutes': 15,
}


# --------------------------------------------------------------------------- #
# Collection helpers
# --------------------------------------------------------------------------- #
class CollectError(Exception):
    pass


def _get(uri, v=1, timeout=30):
    """GET via pyhesity; raise CollectError on anything that is not JSON data."""
    res = ph.api('get', uri, v=v, quiet=True, timeout=timeout)
    if res is None or res == '' or res == 'error' or isinstance(res, str):
        raise CollectError('%s: %s' % (uri.split('?')[0], ph.LAST_API_ERROR()))
    if isinstance(res, dict) and 'error' in res and len(res) == 1:
        raise CollectError('%s: %s' % (uri.split('?')[0], res['error']))
    return res


def _latest_point(series):
    """Return the newest numeric value from a timeSeriesStats response, or None."""
    blocks = [series] if isinstance(series, dict) else (series or [])
    best_ts, best_val = -1, None
    for blk in blocks:
        if not isinstance(blk, dict):
            continue
        for dp in blk.get('dataPointVec') or []:
            data = dp.get('data') or {}
            val = data.get('int64Value', data.get('doubleValue'))
            ts = dp.get('timestampMsecs', 0)
            if val is not None and ts >= best_ts:
                best_ts, best_val = ts, val
    return best_val


def collect_storage(cfg):
    s = _get('stats/storage', timeout=cfg['request_timeout'])
    total = s.get('totalCapacityBytes')
    used = s.get('localUsageBytes')
    free = s.get('localAvailableBytes')
    if free is None and total is not None and used is not None:
        free = max(total - used, 0)
    out = {}
    if total is not None:
        out['storage_total'] = total
    if used is not None:
        out['storage_used'] = used
    if free is not None:
        out['storage_free'] = free
    return out


def collect_nodes(cfg):
    """Inventory from /public/nodes; liveness from /public/cluster/status.

    The API has no explicit up/down flag per node. A node is reported up when it
    answered the cluster-status fan-out (appears in nodeStatuses and inCluster).
    """
    nodes = _get('nodes', timeout=cfg['request_timeout'])
    status = _get('cluster/status', timeout=cfg['request_timeout'])
    reported = {}
    for ns in status.get('nodeStatuses') or []:
        reported[ns.get('id')] = ns
    out = []
    for n in nodes:
        nid = n.get('id')
        ns = reported.get(nid)
        out.append({
            'node_id': str(nid),
            'node_ip': n.get('ip') or (ns or {}).get('ip') or '',
            'hostname': n.get('hostName') or '',
            'up': 1 if (ns is not None and ns.get('inCluster', True)) else 0,
            'maintenance': 1 if (n.get('inMaintenanceMode') or (ns or {}).get('inMaintenanceMode')) else 0,
            'removal': 1 if n.get('isMarkedForRemoval') else 0,
            'offline_disks': n.get('offlineDiskCount') or 0,
            'upgrading': 1 if n.get('upgradeInProgress') else 0,
        })
    return {'nodes': out, 'stopped_services': len(status.get('stoppedServices') or [])}


def collect_throughput(cfg, cluster_id):
    now_ms = int(time.time() * 1000)
    start_ms = now_ms - cfg['throughput_window_minutes'] * 60 * 1000
    # Same query the existing jsonExporter uses for write throughput.
    uri = ('statistics/timeSeriesStats?metricName=kNumBytesWritten&metricUnitType=5'
           '&rollupFunction=max&rollupIntervalSecs=180&schemaName=kBridgeClusterStats'
           '&startTimeMsecs=%s&entityId=%s&endTimeMsecs=%s' % (start_ms, cluster_id, now_ms))
    val = _latest_point(_get(uri, timeout=cfg['request_timeout']))
    return {} if val is None else {'write_throughput': val}


# When a run has several archival targets, report the most severe status.
_STATUS_SEVERITY = ['Failed', 'Missed', 'Canceled', 'Canceling', 'Running', 'Accepted',
                    'SucceededWithWarning', 'Skipped', 'Succeeded']


def last_run_status(last_run):
    """Status of a protection group's most recent run, or 'NoRun'.

    Local backup groups report it under localBackupInfo (originalBackupInfo for
    replicated runs). Cloud Archive Direct (CAD) groups have no local backup, so
    their status is under archivalInfo.archivalTargetResults[].status.
    """
    last_run = last_run or {}
    for key in ('localBackupInfo', 'originalBackupInfo'):
        status = (last_run.get(key) or {}).get('status')
        if status:
            return status
    found = [t.get('status') for t in ((last_run.get('archivalInfo') or {}).get('archivalTargetResults') or [])
             if t.get('status')]
    if found:
        return min(found, key=lambda s: _STATUS_SEVERITY.index(s) if s in _STATUS_SEVERITY else len(_STATUS_SEVERITY))
    return 'NoRun'


def collect_runs(cfg):
    """Count protection groups by the status of their most recent run."""
    counts = {s: 0 for s in CORE_RUN_STATUSES}
    total = paused = 0
    cookie = None
    while True:
        uri = 'data-protect/protection-groups?includeLastRunInfo=true&isDeleted=false'
        if cookie:
            uri += '&paginationCookie=%s' % cookie
        res = _get(uri, v=2, timeout=cfg['request_timeout'])
        for pg in res.get('protectionGroups') or []:
            total += 1
            if pg.get('isPaused'):
                paused += 1
            status = last_run_status(pg.get('lastRun'))
            counts[status] = counts.get(status, 0) + 1
        cookie = res.get('paginationCookie')
        if not cookie:
            break
    return {'run_status': counts, 'pg_total': total, 'pg_paused': paused}


def collect_alerts(cfg):
    end_us = int(time.time() * 1e6)
    start_us = end_us - cfg['alerts_lookback_days'] * 86400 * 1000000
    # statesList=kOpen: count only open alerts (excludes kResolved, kSuppressed, kNote).
    # The API defaults to open alerts, but we state it explicitly.
    res = _get('alerts-summary?startTimeUsecs=%d&endTimeUsecs=%d&statesList=kOpen' % (start_us, end_us),
               v=2, timeout=cfg['request_timeout'])
    sev = {'critical': 0, 'warning': 0, 'info': 0}
    by_cat = {}
    for g in res.get('alertsSummary') or []:
        c, w, i = (g.get('criticalCount') or 0, g.get('warningCount') or 0, g.get('infoCount') or 0)
        sev['critical'] += c
        sev['warning'] += w
        sev['info'] += i
        cat = (g.get('category') or 'Unknown')
        for name, val in (('critical', c), ('warning', w)):
            if val:
                by_cat[(cat, name)] = by_cat.get((cat, name), 0) + val
    return {'alerts': sev, 'alerts_by_category': by_cat}


def collect_cluster(cfg, label_override=None):
    """Collect everything from the currently selected cluster. Returns a snapshot dict."""
    t0 = time.time()
    snap = {'ok': {}, 'data': {}, 'errors': {}}
    cluster = _get('cluster', timeout=cfg['request_timeout'])
    name = label_override or cluster.get('name') or str(cluster.get('id'))
    snap['name'] = name
    snap['info'] = {
        'cluster_id': str(cluster.get('id', '')),
        'version': cluster.get('clusterSoftwareVersion') or '',
        'cluster_type': cluster.get('clusterType') or '',
    }
    collectors = [
        ('storage', lambda: collect_storage(cfg)),
        ('nodes', lambda: collect_nodes(cfg)),
        ('throughput', lambda: collect_throughput(cfg, cluster.get('id'))),
        ('runs', lambda: collect_runs(cfg)),
        ('alerts', lambda: collect_alerts(cfg)),
    ]
    for cname, fn in collectors:
        try:
            snap['data'].update(fn())
            snap['ok'][cname] = 1
        except Exception as e:  # keep going: one failing endpoint must not hide the rest
            snap['ok'][cname] = 0
            snap['errors'][cname] = str(e)
            log.warning('%s: collector %s failed: %s', name, cname, e)
    snap['duration'] = time.time() - t0
    snap['timestamp'] = time.time()
    return snap


# --------------------------------------------------------------------------- #
# Polling (single thread)
# --------------------------------------------------------------------------- #
class Store:
    """Thread-safe snapshot store: label -> snapshot."""

    def __init__(self):
        self._lock = threading.Lock()
        self._snaps = {}

    def set(self, label, snap):
        with self._lock:
            self._snaps[label] = snap

    def mark_down(self, label, err, duration):
        with self._lock:
            prev = self._snaps.get(label, {})
            self._snaps[label] = {
                'name': label, 'down': True, 'errors': {'connect': err},
                'duration': duration, 'timestamp': time.time(),
                'last_success': prev.get('last_success'),
            }

    def all(self):
        with self._lock:
            return dict(self._snaps)


def _auth(target, cfg):
    key = target.get('api_key') or os.environ.get(target.get('api_key_env', ''), '')
    if not key:
        raise CollectError('no API key (set api_key or api_key_env)')
    helios = bool(target.get('helios'))
    # pyhesity reads COH_SECRET before touching its on-disk password store, and
    # only persists a key to disk when it is passed as an argument. Passing it
    # through the environment keeps API keys off disk.
    os.environ['COH_SECRET'] = key
    try:
        ph.apiauth(vip=target['vip'], username=target.get('username', 'helios'),
                   domain=target.get('domain', 'local'), password=None,
                   useApiKey=True, helios=helios, prompt=False, quiet=True,
                   noretry=True, timeout=cfg['request_timeout'])
    finally:
        os.environ.pop('COH_SECRET', None)
    if not ph.apiconnected():
        raise CollectError('authentication failed: %s' % ph.LAST_API_ERROR())


def poll_target(target, cfg, store):
    vip = target['vip']
    helios = bool(target.get('helios'))
    t0 = time.time()
    try:
        _auth(target, cfg)
    except Exception as e:
        # A Helios target fans out to many clusters; mark each known one down.
        labels = target.get('helios_clusters') or [target.get('name') or vip]
        for lbl in labels:
            store.mark_down(lbl, str(e), time.time() - t0)
        log.error('%s: %s', vip, e)
        return
    if helios:
        wanted = target.get('helios_clusters')
        # pyhesity.heliosClusters() only returns clusters that are connected to Helios.
        # HELIOSCLUSTERS holds every registered cluster, so disconnected ones can be
        # reported as down instead of silently vanishing from the dashboard.
        registered = getattr(ph, 'HELIOSCLUSTERS', None)
        if not isinstance(registered, list):
            registered = ph.heliosClusters()
        all_names = {c['name'].lower(): c['name'] for c in registered if c.get('name')}
        connected = {c['name'].lower() for c in ph.heliosClusters()}
        if wanted:
            for w in wanted:
                if w.lower() not in all_names:
                    store.mark_down(w, 'cluster not registered in Helios', 0)
            selected = [all_names[w.lower()] for w in wanted if w.lower() in all_names]
        else:
            selected = list(all_names.values())
        names = []
        for n in selected:
            if n.lower() in connected:
                names.append(n)
            else:
                store.mark_down(n, 'cluster disconnected from Helios', 0)
        for n in names:
            ph.heliosCluster(n)
            if ph.LAST_API_ERROR() != 'OK':
                store.mark_down(n, ph.LAST_API_ERROR(), 0)
                continue
            _collect_into(store, cfg, label=n)
        ph.heliosCluster('-')
    else:
        _collect_into(store, cfg, label=target.get('name'), fallback=vip)


def _collect_into(store, cfg, label, fallback=None):
    try:
        snap = collect_cluster(cfg, label_override=label)
        # a cluster whose basic /cluster call worked is "up", even if some collectors failed
        snap['last_success'] = snap['timestamp']
        store.set(snap['name'], snap)
    except Exception as e:
        store.mark_down(label or fallback, str(e), 0)
        log.error('%s: %s', label or fallback, e)


def poller(targets, cfg, store, stop):
    while not stop.is_set():
        started = time.time()
        for t in targets:
            if stop.is_set():
                break
            try:
                poll_target(t, cfg, store)
            except Exception:
                log.exception('unexpected error polling %s', t.get('vip'))
        stop.wait(max(1, cfg['scrape_interval'] - (time.time() - started)))


# --------------------------------------------------------------------------- #
# Prometheus collector (reads the cache only)
# --------------------------------------------------------------------------- #
class CohesityCollector:
    def __init__(self, store):
        self.store = store

    def collect(self):
        G = GaugeMetricFamily
        up = G('cohesity_up', '1 if the cluster API was reachable on the last poll', labels=['cluster'])
        dur = G('cohesity_exporter_poll_duration_seconds', 'Duration of the last poll of the cluster', labels=['cluster'])
        last = G('cohesity_exporter_last_success_timestamp_seconds', 'Unix time of the last successful poll', labels=['cluster'])
        cok = G('cohesity_exporter_collector_success', '1 if the named collector succeeded on the last poll', labels=['cluster', 'collector'])
        info = G('cohesity_cluster_info', 'Cluster metadata (value is always 1)', labels=['cluster', 'cluster_id', 'version', 'cluster_type'])
        total = G('cohesity_cluster_storage_total_bytes', 'Total cluster storage capacity in bytes', labels=['cluster'])
        used = G('cohesity_cluster_storage_used_bytes', 'Used cluster storage in bytes', labels=['cluster'])
        free = G('cohesity_cluster_storage_free_bytes', 'Available cluster storage in bytes', labels=['cluster'])
        nodes = G('cohesity_cluster_nodes', 'Number of nodes in the cluster', labels=['cluster'])
        nodes_up = G('cohesity_cluster_nodes_up', 'Number of nodes reporting up', labels=['cluster'])
        stopped = G('cohesity_cluster_stopped_services', 'Number of stopped cluster services', labels=['cluster'])
        n_up = G('cohesity_node_up', '1 if the node answered the cluster status request', labels=['cluster', 'node_id', 'node_ip', 'hostname'])
        n_mnt = G('cohesity_node_maintenance_mode', '1 if the node is in maintenance mode', labels=['cluster', 'node_id', 'node_ip', 'hostname'])
        n_rem = G('cohesity_node_marked_for_removal', '1 if the node is marked for removal', labels=['cluster', 'node_id', 'node_ip', 'hostname'])
        n_dsk = G('cohesity_node_offline_disks', 'Number of offline disks on the node', labels=['cluster', 'node_id', 'node_ip', 'hostname'])
        n_upg = G('cohesity_node_upgrade_in_progress', '1 if an upgrade is in progress on the node', labels=['cluster', 'node_id', 'node_ip', 'hostname'])
        thr = G('cohesity_cluster_write_throughput_bytes_per_second', 'Most recent cluster write throughput (kNumBytesWritten, 180s max rollup)', labels=['cluster'])
        runs = G('cohesity_protection_groups_by_last_run_status', 'Protection groups grouped by the status of their last run', labels=['cluster', 'status'])
        pg_t = G('cohesity_protection_groups', 'Total protection groups', labels=['cluster'])
        pg_p = G('cohesity_protection_groups_paused', 'Paused protection groups', labels=['cluster'])
        alerts = G('cohesity_alerts', 'Open alerts by severity', labels=['cluster', 'severity'])
        alerts_c = G('cohesity_alerts_by_category', 'Open critical/warning alerts by category', labels=['cluster', 'category', 'severity'])

        for label, s in sorted(self.store.all().items()):
            is_down = bool(s.get('down'))
            up.add_metric([label], 0 if is_down else 1)
            dur.add_metric([label], s.get('duration', 0))
            if s.get('last_success'):
                last.add_metric([label], s['last_success'])
            if is_down:
                continue  # never serve stale values for an unreachable cluster
            for cname, ok in s['ok'].items():
                cok.add_metric([label, cname], ok)
            i = s['info']
            info.add_metric([label, i['cluster_id'], i['version'], i['cluster_type']], 1)
            d = s['data']
            if 'storage_total' in d:
                total.add_metric([label], d['storage_total'])
            if 'storage_used' in d:
                used.add_metric([label], d['storage_used'])
            if 'storage_free' in d:
                free.add_metric([label], d['storage_free'])
            if 'nodes' in d:
                nodes.add_metric([label], len(d['nodes']))
                nodes_up.add_metric([label], sum(n['up'] for n in d['nodes']))
                stopped.add_metric([label], d.get('stopped_services', 0))
                for n in d['nodes']:
                    lv = [label, n['node_id'], n['node_ip'], n['hostname']]
                    n_up.add_metric(lv, n['up'])
                    n_mnt.add_metric(lv, n['maintenance'])
                    n_rem.add_metric(lv, n['removal'])
                    n_dsk.add_metric(lv, n['offline_disks'])
                    n_upg.add_metric(lv, n['upgrading'])
            if 'write_throughput' in d:
                thr.add_metric([label], d['write_throughput'])
            if 'run_status' in d:
                for st, c in sorted(d['run_status'].items()):
                    runs.add_metric([label, st], c)
                pg_t.add_metric([label], d['pg_total'])
                pg_p.add_metric([label], d['pg_paused'])
            if 'alerts' in d:
                for sev, c in d['alerts'].items():
                    alerts.add_metric([label, sev], c)
                for (cat, sev), c in sorted(d.get('alerts_by_category', {}).items()):
                    alerts_c.add_metric([label, cat, sev], c)

        for fam in (up, dur, last, cok, info, total, used, free, nodes, nodes_up, stopped,
                    n_up, n_mnt, n_rem, n_dsk, n_upg, thr, runs, pg_t, pg_p, alerts, alerts_c):
            yield fam


# --------------------------------------------------------------------------- #
def load_config(path, args):
    with open(path) as f:
        raw = yaml.safe_load(f) or {}
    cfg = dict(DEFAULTS)
    cfg.update({k: v for k, v in raw.items() if k != 'clusters'})
    if args.port:
        cfg['listen_port'] = args.port
    if args.interval:
        cfg['scrape_interval'] = args.interval
    targets = raw.get('clusters') or []
    if not targets:
        raise SystemExit('config has no "clusters" entries')
    for t in targets:
        if 'vip' not in t:
            raise SystemExit('every cluster entry needs a "vip": %s' % t)
    return cfg, targets


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('-c', '--config', default='config.yaml')
    ap.add_argument('-p', '--port', type=int)
    ap.add_argument('-i', '--interval', type=int, help='seconds between polls')
    ap.add_argument('-v', '--verbose', action='store_true')
    args = ap.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format='%(asctime)s %(levelname)s %(message)s')
    cfg, targets = load_config(args.config, args)

    store = Store()
    REGISTRY.register(CohesityCollector(store))
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())

    start_http_server(cfg['listen_port'], addr=cfg['listen_address'])
    log.info('serving metrics on %s:%s for %d target(s)', cfg['listen_address'], cfg['listen_port'], len(targets))
    t = threading.Thread(target=poller, args=(targets, cfg, store, stop), daemon=True)
    t.start()
    stop.wait()
    log.info('shutting down')


if __name__ == '__main__':
    sys.exit(main())
