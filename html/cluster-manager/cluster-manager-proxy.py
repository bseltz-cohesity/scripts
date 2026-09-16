#!/usr/bin/env python3
"""
Cluster Manager local proxy
============================
A tiny local helper that lets the companion cluster-manager.html page
(GFlags tab + Cluster State tab) talk to a Cohesity cluster (or Helios/MCM)
from a browser.

Why this exists: Cohesity's cluster REST API does not send CORS headers, so a
browser cannot call it directly from a page hosted anywhere other than the
cluster itself. This script runs on your own machine, adds the CORS headers
the browser requires, and forwards the actual requests to the cluster over
plain HTTPS (which is not subject to browser CORS rules).

This is the combined replacement for the old cluster-manager-proxy.py (port
8766) and gflag-manager-proxy.py (port 8765) - both tools now share a single
login session and a single proxy process on one port.

No third-party packages required - standard library only (Python 3.6+).

Usage:
    python3 cluster-manager-proxy.py
    (then open cluster-manager.html in your browser)

The proxy listens on 127.0.0.1 only - it is not reachable from the network.
It holds one login session at a time, mirroring how the cohesity-api.ps1 /
pyhesity.py command-line tools work.
"""
import json
import ssl
import urllib.request
import urllib.error
import urllib.parse
import http.cookiejar
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8765


def _now_str():
    import datetime
    return datetime.datetime.now().strftime('%H:%M:%S')


# services that, if stopped/restarted, will also tear down the API session
# this proxy is using to talk to the cluster - flagged in the UI, not blocked.
SESSION_RISK_SERVICES = {'kNexus', 'kGandalf'}

FINISHED_STATES = ('kServiceRunning', 'kServiceStopped')

# service name -> port, used to look up available gflags per service (direct
# cluster connections only - not available through Helios/MCM). Mirrors the
# port map in gflagList.py.
SERVICE_PORTS = {
    "iris": "443",
    "nexus": "23456",
    "stats": "25566",
    "eagle_agent": "23460",
    "vault_proxy": "11115",
    "athena": "25681",
    "iris_proxy": "24567",
    "atom": "20005",
    "smb2_proxy": "20007",
    "bifrost_broker": "29992",
    "bifrost": "29994",
    "alerts": "21111",
    "bridge": "11111",
    "keychain": "22000",
    "smb_proxy": "20003",
    "bridge_proxy": "11116",
    "groot": "26999",
    "apollo": "24680",
    "tricorder": "23458",
    "magneto": "20000",
    "rtclient": "12321",
    "nexus_proxy": "23457",
    "gandalf": "22222",
    "patch": "30000",
    "librarian": "26000",
    "yoda": "25999",
    "storage_proxy": "20001",
    "statscollector": "25680",
    "newscribe": "12222",
    "icebox": "29999",
    "janus": "64001",
    "pushclient": "64002",
    "nfs_proxy": "20010",
    "throttler": "20008",
    "elrond": "26002",
    "heimdall": "26200",
    "node_exporter": "9100",
    "compass": "25555",
    "etl_server": "23462",
}


def _to_service_display_name(key):
    """Convert a gflagList.py-style port-map key (e.g. 'eagle_agent') into the
    raw API service name format (e.g. 'kEagleAgent')."""
    return 'k' + ''.join(part[:1].upper() + part[1:] for part in key.split('_') if part)


# display name (raw API format, e.g. "kMagneto") -> internal port-map key ("magneto")
SERVICE_DISPLAY_NAMES = {key: _to_service_display_name(key) for key in SERVICE_PORTS}
SERVICE_KEY_BY_DISPLAY = {v.lower(): k for k, v in SERVICE_DISPLAY_NAMES.items()}

# ---------------------------------------------------------------------------
# session state - one global session, shared by both the gflag and cluster
# features, mirrors cohesity-api.ps1's / pyhesity's global auth state
# ---------------------------------------------------------------------------
STATE = {
    'connected': False,
    'vip': None,
    'mode': None,  # 'password' | 'apikey' | 'helios'
    'headers': {'accept': 'application/json', 'content-type': 'application/json'},
    'clustername': None,
    'clusterId': None,
}

_ctx = ssl.create_default_context()
_ctx.check_hostname = False
_ctx.verify_mode = ssl.CERT_NONE

_cj = http.cookiejar.CookieJar()
_opener = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(_cj),
    urllib.request.HTTPSHandler(context=_ctx),
)


def upstream(method, url, body=None, timeout=30):
    """Make an HTTPS call to the cluster/Helios, using the current session headers/cookies."""
    hdrs = dict(STATE['headers'])
    data = None
    if body is not None:
        data = json.dumps(body).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    try:
        with _opener.open(req, timeout=timeout) as resp:
            raw = resp.read()
            status = resp.status
    except urllib.error.HTTPError as e:
        raw = e.read()
        status = e.code
    except Exception as e:
        return 599, {'error': str(e)}
    if not raw:
        return status, {}
    try:
        return status, json.loads(raw.decode('utf-8'))
    except Exception:
        return status, {'raw': raw.decode('utf-8', errors='replace')}


def upstream_text(method, url, timeout=15):
    """Like upstream(), but returns raw text instead of trying to parse JSON - used for
    the plaintext /flagz endpoints."""
    hdrs = dict(STATE['headers'])
    req = urllib.request.Request(url, headers=hdrs, method=method)
    try:
        with _opener.open(req, timeout=timeout) as resp:
            raw = resp.read()
            status = resp.status
    except urllib.error.HTTPError as e:
        raw = e.read()
        status = e.code
    except Exception:
        return 599, None
    try:
        return status, raw.decode('utf-8', errors='replace')
    except Exception:
        return status, None


# ---------------------------------------------------------------------------
# shared login/logout - mirrors the relevant parts of cohesity-api.ps1 /
# pyhesity.py
# ---------------------------------------------------------------------------
def do_login(body):
    vip = (body.get('vip') or '').strip()
    mode = body.get('mode', 'password')
    username = body.get('username', '')
    domain = body.get('domain', 'local')
    password = body.get('password', '')
    clustername = (body.get('clustername') or '').strip()
    mfacode = body.get('mfaCode')

    if not vip or not password:
        return {'ok': False, 'error': 'Cluster/Helios address and password (or API key) are required'}

    STATE['headers'] = {'accept': 'application/json', 'content-type': 'application/json'}
    STATE['vip'] = vip
    STATE['mode'] = mode
    STATE['clustername'] = clustername
    STATE['clusterId'] = None
    STATE['connected'] = False
    _cj.clear()

    if mode == 'apikey':
        STATE['headers']['apiKey'] = password
        status, resp = upstream('GET', 'https://%s/irisservices/api/v1/public/sessionUser/preferences' % vip)
        if status == 200 and isinstance(resp, dict) and 'preferences' in resp:
            STATE['connected'] = True
            return {'ok': True, 'mode': 'apikey'}
        msg = resp.get('message') if isinstance(resp, dict) else None
        return {'ok': False, 'error': msg or 'API key authentication failed'}

    if mode == 'helios':
        STATE['headers']['apiKey'] = password
        status, resp = upstream('GET', 'https://%s/mcm/clusters/connectionStatus' % vip)
        if status != 200 or not isinstance(resp, list):
            msg = resp.get('message') if isinstance(resp, dict) else None
            return {'ok': False, 'error': msg or 'Helios/MCM authentication failed'}
        connected = [c for c in resp if c.get('connectedToCluster') is True]
        if not clustername:
            return {'ok': False, 'error': 'Cluster name is required for Helios/MCM',
                     'clusters': [c.get('name') for c in connected]}
        match = [c for c in connected if (c.get('name') or '').lower() == clustername.lower()]
        if not match:
            return {'ok': False, 'error': 'Cluster "%s" is not connected to Helios/MCM' % clustername,
                     'clusters': [c.get('name') for c in connected]}
        STATE['headers']['accessClusterId'] = str(match[0]['clusterId'])
        STATE['connected'] = True
        return {'ok': True, 'mode': 'helios', 'cluster': match[0].get('name')}

    # username/password mode
    creds = {'domain': domain, 'password': password, 'username': username}
    status, resp = upstream('POST', 'https://%s/login' % vip, body=creds)
    if status not in (200, 201):
        msg = resp.get('message') if isinstance(resp, dict) else None
        return {'ok': False, 'error': msg or 'invalid username or password'}

    if mfacode:
        status2, resp2 = upstream(
            'POST',
            'https://%s/irisservices/api/v1/public/verify-otp' % vip,
            body={'otpCode': mfacode, 'otpType': 'Totp'},
        )
        if isinstance(resp2, dict) and resp2.get('errorCode') == 'KValidationError':
            return {'ok': False, 'error': 'MFA verification failed'}

    STATE['connected'] = True
    return {'ok': True, 'mode': 'password'}


def do_logout():
    STATE['connected'] = False
    STATE['vip'] = None
    STATE['clusterId'] = None
    _cj.clear()
    return {'ok': True}


# ---------------------------------------------------------------------------
# gflags feature - mirrors the relevant parts of pyhesity.py / gflags.py
# ---------------------------------------------------------------------------
def do_get_gflags():
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    _, cluster = upstream('GET', 'https://%s/irisservices/api/v1/public/cluster' % STATE['vip'])
    status, flags = upstream('GET', 'https://%s/irisservices/api/v1/clusters/gflag' % STATE['vip'])
    if status != 200:
        return status, {'error': 'Failed to fetch gflags', 'detail': flags}
    return 200, {'cluster': cluster.get('name') if isinstance(cluster, dict) else None, 'services': flags}


def do_set_flag(body):
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    service = body.get('serviceName')
    name = body.get('flagName')
    reason = body.get('reason')
    clear = bool(body.get('clear'))
    value = body.get('flagValue')
    effective_now = bool(body.get('effectiveNow'))
    if not service or not name or not reason or (not clear and (value is None or value == '')):
        return 400, {'error': 'serviceName, flagName, reason and (flagValue or clear) are required'}
    entry = {'name': name, 'reason': reason}
    if clear:
        entry['clear'] = True
    else:
        entry['value'] = value
    payload = {'serviceName': service, 'gflags': [entry], 'effectiveNow': effective_now}
    status, resp = upstream('PUT', 'https://%s/irisservices/api/v1/clusters/gflag' % STATE['vip'], body=payload)
    if status not in (200, 201, 204):
        return status, {'error': 'Failed to set gflag', 'detail': resp}
    return 200, {'ok': True}


def do_gflag_restart(body):
    """Restart the services touched by gflag changes this session. Mirrors
    gflags.py's auto-restart-on-exit behavior."""
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    services = body.get('services', [])
    restartable = [s for s in services if s not in ('kNexus', 'kGandalf')]
    skipped = [s for s in services if s in ('kNexus', 'kGandalf')]
    if restartable:
        status, resp = upstream(
            'POST',
            'https://%s/irisservices/api/v1/public/clusters/services/states' % STATE['vip'],
            body={'action': 'kRestart', 'services': restartable},
        )
        # The cluster accepts this asynchronously (202, with a statusUrl to poll) as
        # well as answering synchronously - treat both as success.
        if status not in (200, 201, 202, 204):
            return status, {'error': 'Restart failed', 'detail': resp}
    return 200, {'ok': True, 'restarted': restartable, 'skipped': skipped}


def _parse_flagz(text):
    """Parse a /flagz text response (lines like '--flagname=value [default: ...]')."""
    flags = []
    if not text:
        return flags
    for line in text.replace('\r\n', '\n').split('\n'):
        line = line.strip()
        if line[:2] != '--':
            continue
        body = line[2:]
        if '=' in body:
            name, value = body.split('=', 1)
            value = value.split(' [default')[0]
        else:
            name, value = body, None
        if name:
            flags.append({'name': name, 'value': value})
    return flags


def do_get_flaglist(qs):
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    requested = (qs.get('service') or [''])[0].strip()
    service = SERVICE_KEY_BY_DISPLAY.get(requested.lower())
    if service is None:
        return 400, {'error': 'Unknown service "%s"' % requested}
    vip = STATE['vip']
    port = SERVICE_PORTS[service]

    if service == 'iris':
        # This hits the VIP directly on its own port rather than going through the
        # normal API root, so it can't be routed through Helios/MCM to the actual cluster.
        if STATE['mode'] == 'helios':
            return 400, {'error': 'kIris flag lookup connects directly to the cluster port and is not available through Helios/MCM.'}
        status, text = upstream_text('GET', 'https://%s:%s/flagz' % (vip, port))
        flags = _parse_flagz(text) if status == 200 else []
        if flags:
            return 200, {'ok': True, 'flags': flags}
        return 502, {'error': 'Could not reach the flagz endpoint for %s' % service}

    # Every other service is looked up via the cluster's own siren relay, which rides
    # the normal API root - this is routed correctly through Helios/MCM via the
    # accessClusterId header, same as the other API calls in this app.
    status_n, nodes = upstream('GET', 'https://%s/irisservices/api/v1/public/nodes' % vip)
    if status_n != 200 or not isinstance(nodes, list):
        return 502, {'error': 'Failed to list cluster nodes'}
    for node in nodes:
        ip = node.get('ip')
        if not ip:
            continue
        remote = 'http://%s:%s/flagz' % (ip, port)
        url = 'https://%s/siren/v1/remote?relPath=&remoteUrl=%s' % (vip, urllib.parse.quote(remote, safe=''))
        status, text = upstream_text('GET', url)
        if status == 200:
            flags = _parse_flagz(text)
            if flags:
                return 200, {'ok': True, 'flags': flags}
    return 502, {'error': 'Could not reach the flagz endpoint for %s on any node%s' % (
        service, ' via Helios/MCM' if STATE['mode'] == 'helios' else '')}


def do_list_gflag_services():
    return 200, {'services': sorted(SERVICE_DISPLAY_NAMES.values())}


# ---------------------------------------------------------------------------
# cluster state feature - mirrors startStopCluster.ps1 / serviceManager.ps1
# ---------------------------------------------------------------------------
def do_get_cluster_status():
    """Mirrors startStopCluster.ps1: GET /nexus/cluster/status, plus the cluster
    name from GET /public/cluster for display."""
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    vip = STATE['vip']
    _, cluster = upstream('GET', 'https://%s/irisservices/api/v1/public/cluster' % vip)
    status, stat = upstream('GET', 'https://%s/irisservices/api/v1/nexus/cluster/status' % vip)
    if status != 200 or not isinstance(stat, dict):
        return status, {'error': 'Failed to fetch cluster status', 'detail': stat}
    if stat.get('clusterId'):
        STATE['clusterId'] = stat.get('clusterId')
    bulletin = stat.get('bulletinState') or {}
    synced = stat.get('isServiceStateSynced')
    running = bulletin.get('runAllServices')
    if synced is not True:
        phase = 'syncing'
    elif running is True:
        phase = 'running'
    elif running is False:
        phase = 'stopped'
    else:
        phase = 'unknown'
    return 200, {
        'ok': True,
        'cluster': cluster.get('name') if isinstance(cluster, dict) else None,
        'clusterId': stat.get('clusterId'),
        'isServiceStateSynced': synced,
        'runAllServices': running,
        'phase': phase,
    }


def do_cluster_action(body):
    """Mirrors startStopCluster.ps1's -stop / -start."""
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    action = body.get('action')
    if action not in ('stop', 'start'):
        return 400, {'error': 'action must be "stop" or "start"'}
    vip = STATE['vip']
    cluster_id = STATE.get('clusterId')
    if not cluster_id:
        status, stat = upstream('GET', 'https://%s/irisservices/api/v1/nexus/cluster/status' % vip)
        if status != 200 or not isinstance(stat, dict) or not stat.get('clusterId'):
            return 502, {'error': 'Could not determine clusterId'}
        cluster_id = stat['clusterId']
        STATE['clusterId'] = cluster_id
    path = 'stop' if action == 'stop' else 'start'
    status, resp = upstream(
        'POST',
        'https://%s/irisservices/api/v1/nexus/cluster/%s' % (vip, path),
        body={'clusterId': cluster_id},
    )
    if status not in (200, 201, 202, 204):
        return status, {'error': 'Cluster %s failed' % action, 'detail': resp}
    message = resp.get('message') if isinstance(resp, dict) else None
    return 200, {'ok': True, 'action': action, 'message': message}


def do_get_cluster_services():
    """Mirrors serviceManager.ps1: GET clusters/services/states."""
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    status, resp = upstream(
        'GET', 'https://%s/irisservices/api/v1/public/clusters/services/states' % STATE['vip'])
    if status != 200 or not isinstance(resp, list):
        return status, {'error': 'Failed to fetch service states', 'detail': resp}
    services = sorted(resp, key=lambda s: s.get('service', ''))
    all_finished = all(s.get('state') in FINISHED_STATES for s in services)
    return 200, {'ok': True, 'services': services, 'allFinished': all_finished}


def do_cluster_services_action(body):
    """Mirrors serviceManager.ps1's -stop / -start / -restart against a list of
    -serviceNames."""
    if not STATE['connected']:
        return 401, {'error': 'Not connected'}
    services = body.get('services') or []
    action = body.get('action')
    if not services:
        return 400, {'error': 'services list is required'}
    if action not in ('kStop', 'kStart', 'kRestart'):
        return 400, {'error': 'action must be kStop, kStart, or kRestart'}
    status, resp = upstream(
        'POST',
        'https://%s/irisservices/api/v1/public/clusters/services/states' % STATE['vip'],
        body={'action': action, 'services': services},
    )
    if status not in (200, 201, 202, 204):
        return status, {'error': 'Service action failed', 'detail': resp}
    message = resp.get('message') if isinstance(resp, dict) else None
    return 200, {'ok': True, 'action': action, 'services': services, 'message': message}


# ---------------------------------------------------------------------------
# HTTP server
# ---------------------------------------------------------------------------
class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def _send(self, status, payload):
        body = json.dumps(payload).encode('utf-8')
        self.send_response(status)
        self._cors()
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        # This is a stateful local API - never let the browser (or an intermediary)
        # cache a response, or a repeated GET (e.g. status polling) can come back
        # from cache instead of hitting the proxy/cluster again.
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.end_headers()
        self.wfile.write(body)
        if status >= 400:
            print('[%s] %s %s -> %s : %s' % (
                _now_str(), self.command, self.path, status, json.dumps(payload)))

    def _read_json(self):
        length = int(self.headers.get('Content-Length', 0) or 0)
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode('utf-8'))
        except Exception:
            return {}

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)
        if path == '/api/ping':
            self._send(200, {'ok': True, 'connected': STATE['connected'], 'vip': STATE['vip']})
        elif path == '/api/gflag/flags':
            status, payload = do_get_gflags()
            self._send(status, payload)
        elif path == '/api/gflag/servicelist':
            status, payload = do_list_gflag_services()
            self._send(status, payload)
        elif path == '/api/gflag/flaglist':
            status, payload = do_get_flaglist(qs)
            self._send(status, payload)
        elif path == '/api/cluster/status':
            status, payload = do_get_cluster_status()
            self._send(status, payload)
        elif path == '/api/cluster/services':
            status, payload = do_get_cluster_services()
            self._send(status, payload)
        else:
            self._send(404, {'error': 'not found'})

    def do_POST(self):
        body = self._read_json()
        if self.path == '/api/login':
            self._send(200, do_login(body))
        elif self.path == '/api/logout':
            self._send(200, do_logout())
        elif self.path == '/api/gflag/setflag':
            status, payload = do_set_flag(body)
            self._send(status, payload)
        elif self.path == '/api/gflag/import':
            rows = body.get('rows', [])
            results = []
            for row in rows:
                status, payload = do_set_flag(row)
                results.append({'row': row, 'status': status, 'result': payload})
            self._send(200, {'results': results})
        elif self.path == '/api/gflag/restart':
            status, payload = do_gflag_restart(body)
            self._send(status, payload)
        elif self.path == '/api/cluster/action':
            status, payload = do_cluster_action(body)
            self._send(status, payload)
        elif self.path == '/api/cluster/servicesaction':
            status, payload = do_cluster_services_action(body)
            self._send(status, payload)
        else:
            self._send(404, {'error': 'not found'})

    def log_message(self, format, *args):
        pass  # quiet; comment out (or remove) this method to see request logs


if __name__ == '__main__':
    server = ThreadingHTTPServer(('127.0.0.1', PORT), Handler)
    print('Cluster Manager local proxy running at http://127.0.0.1:%d' % PORT)
    print('Open cluster-manager.html in your browser - it talks only to this proxy.')
    print('Press Ctrl+C to stop.')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nStopped.')
