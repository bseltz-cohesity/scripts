#!/usr/bin/env python
"""Helios cluster status prometheus exporter

Exposes per-cluster health, version, capacity and alert metrics from Helios.
Data is refreshed in a background thread (default every 5 minutes) so that
Prometheus scrapes are always fast.
"""

from prometheus_client import start_http_server, REGISTRY
from prometheus_client.core import GaugeMetricFamily
from pyhesity import *
from time import sleep, time
import threading
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-port', '--port', type=int, default=1235)
parser.add_argument('-a', '--alertdays', type=int, default=7)
parser.add_argument('-r', '--refreshseconds', type=int, default=300)
args = parser.parse_args()

HEALTH_STATE = {'Healthy': 0, 'Critical': 1, 'Unknown': 2, 'Disconnected': 3}


def fetch_clusters(alertDays):
    """query Helios and return one dict per cluster (same logic as heliosDashboardExporter.py)"""
    apiauth(vip=args.vip, username=args.username, domain=args.domain, password=args.password,
            helios=True, useApiKey=args.useApiKey, noretry=True, quiet=True)
    if not apiconnected():
        raise Exception('authentication to Helios failed')

    endUsecs = dateToUsecs()
    startUsecs = timeAgo(alertDays, 'days')

    clusterInfoResp = api('get', 'cluster-mgmt/info', mcmv2=True) or {}
    clusters = sorted(
        [c for c in (clusterInfoResp.get('cohesityClusters') or []) if c is not None],
        key=lambda c: (c.get('clusterName') or '').lower()
    )

    rawAlerts = []
    for cluster in clusters:
        if cluster.get('isConnectedToHelios') is not True:
            continue
        if cluster.get('clusterIncarnationId'):
            clusterIdentifier = '%s:%s' % (cluster.get('clusterId'), cluster.get('clusterIncarnationId'))
        else:
            clusterIdentifier = '%s' % cluster.get('clusterId')
        resp = api('get', 'alerts?alertStateList=kOpen&alertSeverityList=kCritical,kWarning&clusterIdentifiers=%s&maxAlerts=1000' % clusterIdentifier, mcmv2=True) or {}
        if resp != "null\n":
            for a in (resp.get('alertsList') or []):
                if a is None:
                    continue
                a['ResolvedClusterId'] = str(cluster.get('clusterId'))
                rawAlerts.append(a)

    openAlerts = [a for a in rawAlerts
                  if a.get('latestTimestampUsecs') and startUsecs <= a['latestTimestampUsecs'] <= endUsecs]

    alertsByCluster = {}
    for a in openAlerts:
        alertsByCluster.setdefault(a['ResolvedClusterId'], []).append(a)

    nowUsecs = dateToUsecs()
    rows = []
    for cluster in clusters:
        cid = str(cluster.get('clusterId'))
        isDisconnected = cluster.get('isConnectedToHelios') is not True

        if isDisconnected:
            health = 'Disconnected'
        else:
            h = cluster.get('health')
            health = 'Healthy' if h == 'NonCritical' else ('Critical' if h == 'Critical' else 'Unknown')

        currentVersion = cluster.get('currentVersion')
        versionShort = currentVersion.split('_release')[0] if currentVersion else ''

        total = cluster.get('totalCapacity') or 0
        used = cluster.get('usedCapacity') or 0

        group = [] if isDisconnected else alertsByCluster.get(cid, [])
        crit = [a for a in group if a.get('severity') == 'kCritical']
        warn = [a for a in group if a.get('severity') == 'kWarning']

        latest = None
        if group:
            candidates = crit if crit else group
            latest = sorted(candidates, key=lambda a: a.get('latestTimestampUsecs') or 0, reverse=True)[0]

        row = {
            'cluster': cluster.get('clusterName') or cid,
            'health': health,
            'connected': 0 if isDisconnected else 1,
            'version': '' if isDisconnected else versionShort,
            'patch': '' if isDisconnected else (cluster.get('currentPatchVersion') or ''),
            'upgradeStatus': '' if isDisconnected else (cluster.get('status') or ''),
            'nodes': None if isDisconnected else cluster.get('numberOfNodes'),
            'used': used,
            'total': total,
            'capacityPct': round(100 * used / total, 1) if total > 0 else None,
            'crit': len(crit),
            'warn': len(warn),
            'latestSeverity': None,
            'latestName': None,
            'latestAgeMinutes': None,
        }
        if latest:
            row['latestSeverity'] = 'Critical' if latest.get('severity') == 'kCritical' else 'Warning'
            doc = latest.get('alertDocument') or {}
            row['latestName'] = doc.get('alertName') or latest.get('alertCategory') or 'Unknown'
            ts = latest.get('latestTimestampUsecs')
            if ts:
                row['latestAgeMinutes'] = round((nowUsecs - ts) / 60000000, 1)
        rows.append(row)
    return rows


class HeliosExporter():
    def __init__(self):
        self.lock = threading.Lock()
        self.rows = []
        self.lastSuccess = 0
        self.lastOk = 0

    def refresh_loop(self):
        while True:
            try:
                rows = fetch_clusters(args.alertdays)
                with self.lock:
                    self.rows = rows
                    self.lastSuccess = time()
                    self.lastOk = 1
                print('refreshed %s clusters' % len(rows))
            except Exception as e:
                print('refresh failed: %s' % e)
                with self.lock:
                    self.lastOk = 0
            sleep(args.refreshseconds)

    def collect(self):
        with self.lock:
            rows = list(self.rows)
            lastSuccess = self.lastSuccess
            lastOk = self.lastOk

        info = GaugeMetricFamily('helios_cluster_info', 'cluster version, patch, upgrade status and health',
                                 labels=['cluster', 'health', 'version', 'patch', 'upgrade_status'])
        connected = GaugeMetricFamily('helios_cluster_connected', '1 if cluster is connected to Helios', labels=['cluster'])
        healthState = GaugeMetricFamily('helios_cluster_health_state', '0=Healthy 1=Critical 2=Unknown 3=Disconnected', labels=['cluster'])
        nodes = GaugeMetricFamily('helios_cluster_nodes', 'number of nodes', labels=['cluster'])
        used = GaugeMetricFamily('helios_cluster_capacity_used_bytes', 'used capacity', labels=['cluster'])
        total = GaugeMetricFamily('helios_cluster_capacity_total_bytes', 'total capacity', labels=['cluster'])
        pct = GaugeMetricFamily('helios_cluster_capacity_percent', 'percent capacity used', labels=['cluster'])
        alerts = GaugeMetricFamily('helios_cluster_open_alerts', 'open alerts within the alert window', labels=['cluster', 'severity'])
        latest = GaugeMetricFamily('helios_cluster_latest_alert_info', 'latest alert (criticals preferred)',
                                   labels=['cluster', 'severity', 'alert_name'])
        latestAge = GaugeMetricFamily('helios_cluster_latest_alert_age_minutes', 'age of latest alert in minutes', labels=['cluster'])

        for r in rows:
            c = r['cluster']
            info.add_metric([c, r['health'], r['version'], r['patch'], r['upgradeStatus']], 1)
            connected.add_metric([c], r['connected'])
            healthState.add_metric([c], HEALTH_STATE[r['health']])
            if r['nodes'] is not None:
                nodes.add_metric([c], r['nodes'])
            if r['total']:
                used.add_metric([c], r['used'])
                total.add_metric([c], r['total'])
            if r['capacityPct'] is not None:
                pct.add_metric([c], r['capacityPct'])
            alerts.add_metric([c, 'critical'], r['crit'])
            alerts.add_metric([c, 'warning'], r['warn'])
            if r['latestName']:
                latest.add_metric([c, r['latestSeverity'], r['latestName']], 1)
                if r['latestAgeMinutes'] is not None:
                    latestAge.add_metric([c], r['latestAgeMinutes'])

        for m in (info, connected, healthState, nodes, used, total, pct, alerts, latest, latestAge):
            yield m

        ok = GaugeMetricFamily('helios_exporter_last_refresh_success', '1 if the last Helios refresh succeeded')
        ok.add_metric([], lastOk)
        yield ok
        ts = GaugeMetricFamily('helios_exporter_last_success_timestamp_seconds', 'unix time of last successful refresh')
        ts.add_metric([], lastSuccess)
        yield ts


if __name__ == '__main__':
    exporter = HeliosExporter()
    threading.Thread(target=exporter.refresh_loop, daemon=True).start()
    REGISTRY.register(exporter)
    start_http_server(port=args.port)
    print('serving metrics on :%s' % args.port)
    while True:
        sleep(5)
