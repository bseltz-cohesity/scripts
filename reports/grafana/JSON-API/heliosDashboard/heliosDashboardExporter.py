#!/usr/bin/env python3
from flask import Flask, request
from flask_cors import CORS
from pyhesity import *
from datetime import date
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'some random string'
app.debug = True
CORS(app)

@app.route("/clusterstatus", methods=['GET'])
def getclusterstatus():
    """Helios cluster status table"""
    apiKey = request.headers.get('apiKey', 0)
    if apiKey == 0:
        return "", 403
    vip = request.args.get('vip', 'helios.cohesity.com')
    alertDays = int(request.args.get('alertdays', 7))

    apiauth(vip=vip, username='helios', domain='local', password=apiKey, helios=True, useApiKey=True, noretry=True)
    if not apiconnected():
        return {"clusters": []}, 502

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
        clusterAlertsResp = api('get', 'alerts?alertStateList=kOpen&alertSeverityList=kCritical,kWarning&clusterIdentifiers=%s&maxAlerts=1000' % clusterIdentifier, mcmv2=True) or {}
        if clusterAlertsResp != "null\n":
            for a in (clusterAlertsResp.get('alertsList') or []):
                if a is None:
                    continue
                a['ResolvedClusterId'] = str(cluster.get('clusterId'))
                rawAlerts.append(a)

    openAlerts = [
        a for a in rawAlerts
        if a.get('latestTimestampUsecs') and startUsecs <= a['latestTimestampUsecs'] <= endUsecs
    ]

    statsByClusterMap = {}
    for a in openAlerts:
        cid = a['ResolvedClusterId']
        statsByClusterMap.setdefault(cid, {'numCriticalAlerts': 0, 'numWarningAlerts': 0})
        if a.get('severity') == 'kCritical':
            statsByClusterMap[cid]['numCriticalAlerts'] += 1
        elif a.get('severity') == 'kWarning':
            statsByClusterMap[cid]['numWarningAlerts'] += 1

    # latest alert per cluster prefers open criticals over warnings, newest first
    alertsByClusterId = {}
    for a in openAlerts:
        alertsByClusterId.setdefault(a['ResolvedClusterId'], []).append(a)

    latestAlertMap = {}
    for cid, group in alertsByClusterId.items():
        criticalAlerts = [a for a in group if a.get('severity') == 'kCritical']
        candidates = criticalAlerts if len(criticalAlerts) > 0 else group
        latestAlertMap[cid] = sorted(candidates, key=lambda a: a.get('latestTimestampUsecs') or 0, reverse=True)[0]

    # 3) flatten into one row per cluster
    nowUsecs = dateToUsecs()
    rows = []
    for cluster in clusters:
        cid = str(cluster.get('clusterId'))
        isDisconnected = cluster.get('isConnectedToHelios') is not True

        if isDisconnected:
            health = 'Disconnected'
        else:
            h = cluster.get('health')
            if h == 'NonCritical':
                health = 'Healthy'
            elif h == 'Critical':
                health = 'Critical'
            else:
                health = 'Unknown'

        currentVersion = cluster.get('currentVersion')
        versionShort = currentVersion.split('_release')[0] if currentVersion else None

        total = cluster.get('totalCapacity') or 0
        used = cluster.get('usedCapacity') or 0
        capacityPct = round((100 * used / total), 1) if total > 0 else None

        clusterAlertStats = statsByClusterMap.get(cid, {})
        critCount = 0 if isDisconnected else clusterAlertStats.get('numCriticalAlerts', 0)
        warnCount = 0 if isDisconnected else clusterAlertStats.get('numWarningAlerts', 0)

        latestAlert = None if isDisconnected else latestAlertMap.get(cid)
        latestAlertSeverity = None
        latestAlertName = None
        latestAlertAgeMinutes = None
        if latestAlert:
            severity = latestAlert.get('severity')
            latestAlertSeverity = 'Critical' if severity == 'kCritical' else ('Warning' if severity == 'kWarning' else severity)
            alertDoc = latestAlert.get('alertDocument') or {}
            latestAlertName = alertDoc.get('alertName') or latestAlert.get('alertCategory')
            ts = latestAlert.get('latestTimestampUsecs')
            if ts:
                latestAlertAgeMinutes = round((nowUsecs - ts) / 60000000, 1)

        rows.append({
            'clusterName': cluster.get('clusterName'),
            'health': health,
            'isConnected': 0 if isDisconnected else 1,
            'isDisconnected': 1 if isDisconnected else 0,
            'isCriticalHealth': 1 if health == 'Critical' else 0,
            'version': versionShort if not isDisconnected else None,
            'patch': cluster.get('currentPatchVersion') if not isDisconnected else None,
            'upgradeStatus': cluster.get('status') if not isDisconnected else None,
            'nodes': cluster.get('numberOfNodes') if not isDisconnected else None,
            'usedCapacityBytes': used if used else None,
            'totalCapacityBytes': total if total else None,
            'capacityPct': capacityPct,
            'numCriticalAlerts': critCount,
            'numWarningAlerts': warnCount,
            'latestAlertSeverity': latestAlertSeverity,
            'latestAlertName': latestAlertName,
            'latestAlertAgeMinutes': latestAlertAgeMinutes,
        })

    return {'clusters': rows}

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8444, ssl_context=('flaskdev_crt.pem', 'flaskdev_key.pem'))
