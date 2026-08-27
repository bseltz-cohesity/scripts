#!/usr/bin/env python
"""
heliosDashboard.py
Builds an HTML health/status dashboard for all clusters connected to Helios.

Python port of heliosDashboard.ps1. Authentication and cluster access follow
the same pattern as heliosSlaMonitor.py (apiauth / heliosCluster / api from
pyhesity.py).
"""

### import Cohesity python module
from pyhesity import *

import argparse
import html
import os
import webbrowser
from datetime import datetime

### command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-un', '--unit', type=str, choices=['GiB', 'TiB'], default='TiB')
parser.add_argument('-th', '--theme', type=str, choices=['Light', 'Dark'], default='Dark')
parser.add_argument('-a', '--alertdays', type=int, default=7)
parser.add_argument('-o', '--outfilename', type=str, default=None)
parser.add_argument('-s', '--show', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
unit = args.unit
theme = args.theme
alertDays = args.alertdays
outfileName = args.outfilename
show = args.show

### authenticate to Helios
apiauth(vip=vip, username=username, domain=domain, password=password, helios=True)

if not apiconnected():
    print('Unable to authenticate to %s' % vip)
    exit(1)

dateString = datetime.now().strftime('%Y-%m-%d_%H%M')
if not outfileName:
    outfileName = 'heliosDashboard-%s.html' % dateString

conversion = {'GiB': 1024 ** 3, 'TiB': 1024 ** 4}


def formatBytes(val):
    if val is None or val == 0:
        return '0 %s' % unit
    return '{0:,.1f} {1}'.format(val / conversion[unit], unit)


def formatAge(usecs):
    if not usecs:
        return 'n/a'
    dt = usecsToDateTime(usecs)
    span = datetime.now() - dt
    totalSeconds = span.total_seconds()
    if totalSeconds >= 86400:
        return '{0:,.0f}d ago'.format(totalSeconds / 86400)
    elif totalSeconds >= 3600:
        return '{0:,.0f}h ago'.format(totalSeconds / 3600)
    elif totalSeconds >= 60:
        return '{0:,.0f}m ago'.format(totalSeconds / 60)
    else:
        return 'just now'


def formatTimestamp(usecs):
    if not usecs:
        return 'n/a'
    return usecsToDate(usecs, '%Y-%m-%d %H:%M')


def htmlEncode(text):
    if text is None:
        return ''
    return html.escape(str(text))


def formatEnvironment(env):
    if not env:
        return '&ndash;'
    if env.startswith('k'):
        env = env[1:]
    return htmlEncode(env)


def getHealthBadge(cluster):
    if cluster.get('isConnectedToHelios') is not True:
        return '<span class="badge badge-muted">Disconnected</span>'
    health = cluster.get('health')
    if health == 'NonCritical':
        return '<span class="badge badge-ok">Healthy</span>'
    elif health == 'Critical':
        return '<span class="badge badge-critical">Critical</span>'
    else:
        return '<span class="badge badge-muted">Unknown</span>'


def getStatusBadge(status):
    mapping = {
        'UpToDate': '<span class="badge badge-ok">Up To Date</span>',
        'UpgradeAvailable': '<span class="badge badge-info">Upgrade Available</span>',
        'InProgress': '<span class="badge badge-info">Upgrading</span>',
        'Scheduled': '<span class="badge badge-info">Scheduled</span>',
        'Failed': '<span class="badge badge-critical">Upgrade Failed</span>',
        'ClusterUnreachable': '<span class="badge badge-muted">Unreachable</span>',
    }
    return mapping.get(status, '<span class="badge badge-muted">n/a</span>')


def getSeverityBadge(severity):
    mapping = {
        'kCritical': '<span class="badge badge-critical">Critical</span>',
        'kWarning': '<span class="badge badge-warning">Warning</span>',
        'kInfo': '<span class="badge badge-info">Info</span>',
    }
    return mapping.get(severity, '<span class="badge badge-muted">n/a</span>')


def getRunStatusBadge(status):
    mapping = {
        'Succeeded': '<span class="badge badge-ok">Succeeded</span>',
        'SucceededWithWarning': '<span class="badge badge-warning">Succeeded w/ Warning</span>',
        'Failed': '<span class="badge badge-critical">Failed</span>',
        'Running': '<span class="badge badge-info">Running</span>',
        'Accepted': '<span class="badge badge-info">Accepted</span>',
        'Finalizing': '<span class="badge badge-info">Finalizing</span>',
        'Canceling': '<span class="badge badge-muted">Canceling</span>',
        'Canceled': '<span class="badge badge-muted">Canceled</span>',
        'Skipped': '<span class="badge badge-muted">Skipped</span>',
        'Missed': '<span class="badge badge-muted">Missed</span>',
        'OnHold': '<span class="badge badge-muted">On Hold</span>',
        'LegalHold': '<span class="badge badge-muted">Legal Hold</span>',
        'Paused': '<span class="badge badge-muted">Paused</span>',
    }
    return mapping.get(status, '<span class="badge badge-muted">n/a</span>')


def getPausedBadge(isPaused):
    if isPaused is True:
        return '<span class="badge badge-warning">Paused</span>'
    return '<span class="no-data">&ndash;</span>'


def getPieColor(pct):
    if pct >= 90:
        return '#e74c3c'
    elif pct >= 70:
        return '#f39c12'
    else:
        return '#2ecc71'


def getPieHtml(pct):
    color = getPieColor(pct)
    pctDisplay = int(round(pct))
    gradient = 'conic-gradient({0} 0% {1}%, #e2e8f0 {1}% 100%)'.format(color, pct)
    return '<div class="pie-wrap"><div class="pie" style="background: {0}"></div><div class="pie-hole">{1}%</div></div>'.format(gradient, pctDisplay)


def getAlertCountHtml(critCount, warnCount):
    critClass = 'crit' if critCount > 0 else 'zero'
    warnClass = 'warn' if warnCount > 0 else 'zero'
    return '<span class="{0}">{1} critical</span><span class="{2}">{3} warning</span>'.format(critClass, critCount, warnClass, warnCount)


# returns the most relevant run-summary object (local/replication/archival) for a
# protection group's last run, so we have one place to pull status/time/messages from
def getLastRunSummary(pg):
    lastRun = pg.get('lastRun')
    if not lastRun:
        return None
    if lastRun.get('localBackupInfo'):
        return lastRun['localBackupInfo']
    if lastRun.get('originalBackupInfo'):
        return lastRun['originalBackupInfo']
    if lastRun.get('archivalInfo'):
        targets = lastRun['archivalInfo'].get('archivalTargetResults')
        if targets:
            return targets[0]
    return None


showProtectionGroups = True

print('\nGathering cluster and alert data from %s...\n' % vip)

# time window for alert queries
endUsecs = dateToUsecs()
startUsecs = timeAgo(alertDays, 'days')

# 1) cluster list, status, and health -----------------------------------------------------------
clusterInfoResp = api('get', 'cluster-mgmt/info', mcmv2=True) or {}
clusters = sorted(
    [c for c in (clusterInfoResp.get('cohesityClusters') or []) if c is not None],
    key=lambda c: (c.get('clusterName') or '').lower()
)

if len(clusters) == 0:
    print('No clusters returned from cluster-mgmt/info')

# 2) open critical/warning alerts, used for the Active Alerts counts, the latest alert per
#    cluster, and the detail table below -----------------------------------------------------
# note: queried per-cluster (via clusterIdentifiers) rather than one global call. The global
# /mcm/alerts call appears to hard-cap its response around 1000 alerts regardless of the
# maxAlerts value requested, which can silently truncate results in a busy environment and make
# alerts from some clusters vanish entirely. Querying per cluster keeps each response well under
# that cap. Each alert is also tagged with the cluster identity from this loop (rather than
# trusting the clusterId/clusterName fields on the alert itself), which sidesteps any possible
# ID-format mismatch between this endpoint and cluster-mgmt/info.
# note: the API's startDateUsecs/endDateUsecs filter on when an alert was first raised, not on
# when it was last seen. A recurring alert first raised well before the window, but still
# actively occurring (deduped) within it, would be dropped entirely by that filter even though
# it's genuinely active right now - showing up nowhere and with zero counts. So instead we pull
# all open alerts per cluster and filter client-side on latestTimestampUsecs (most recent
# occurrence), which is what "active within the alert window" actually means. Counts are derived
# from this same list so the Active Alerts column always matches the latest alert column and the
# detail table.
rawAlerts = []
for cluster in clusters:
    if cluster.get('isConnectedToHelios') is not True:
        # skip disconnected clusters - there's nothing current to fetch, and it saves a call
        continue
    if cluster.get('clusterIncarnationId'):
        clusterIdentifier = '%s:%s' % (cluster.get('clusterId'), cluster.get('clusterIncarnationId'))
    else:
        clusterIdentifier = '%s' % cluster.get('clusterId')
    clusterAlertsResp = api('get', 'alerts?alertStateList=kOpen&alertSeverityList=kCritical,kWarning&clusterIdentifiers=%s&maxAlerts=1000' % clusterIdentifier, mcmv2=True) or {}
    if clusterAlertsResp != "null\n":
        clusterRawAlerts = [a for a in (clusterAlertsResp.get('alertsList') or []) if a is not None]
        for a in clusterRawAlerts:
            a['ResolvedClusterId'] = str(cluster.get('clusterId'))
            a['ResolvedClusterName'] = cluster.get('clusterName')
            rawAlerts.append(a)

openAlerts = [
    a for a in rawAlerts
    if a.get('latestTimestampUsecs') and startUsecs <= a['latestTimestampUsecs'] <= endUsecs
]

statsByClusterMap = {}
for a in openAlerts:
    cid = a['ResolvedClusterId']
    if cid not in statsByClusterMap:
        statsByClusterMap[cid] = {'numCriticalAlerts': 0, 'numWarningAlerts': 0}
    if a.get('severity') == 'kCritical':
        statsByClusterMap[cid]['numCriticalAlerts'] += 1
    elif a.get('severity') == 'kWarning':
        statsByClusterMap[cid]['numWarningAlerts'] += 1

# "latest alert" per cluster prefers critical alerts over warnings - if a cluster has any open
# critical alert, its most recent critical alert is shown here even if a warning came in more
# recently. Only when a cluster has no open critical alerts does its most recent warning show.
alertsByClusterId = {}
for a in openAlerts:
    alertsByClusterId.setdefault(a['ResolvedClusterId'], []).append(a)

latestAlertMap = {}
for cid, group in alertsByClusterId.items():
    criticalAlerts = [a for a in group if a.get('severity') == 'kCritical']
    candidates = criticalAlerts if len(criticalAlerts) > 0 else group
    latestAlertMap[cid] = sorted(candidates, key=lambda a: a.get('latestTimestampUsecs') or 0, reverse=True)[0]

# group alerts by cluster (alphabetical), cap at 3 per cluster. Which 3 alerts get chosen still
# prefers criticals over warnings (criticals fill the slots first, newest first; warnings only
# fill any slots criticals don't use) - but the chosen rows are then re-sorted newest-to-oldest
# for display, so the secondary sort within each cluster is strictly by time, not severity.
alertsByClusterName = {}
for a in openAlerts:
    alertsByClusterName.setdefault(a.get('ResolvedClusterName') or '', []).append(a)

sortedAlertDetails = []
zebraIndex = 0
for clusterName in sorted(alertsByClusterName.keys(), key=lambda n: n.lower()):
    group = alertsByClusterName[clusterName]
    criticalRows = sorted([a for a in group if a.get('severity') == 'kCritical'], key=lambda a: a.get('latestTimestampUsecs') or 0, reverse=True)[:3]
    remainingSlots = 3 - len(criticalRows)
    warningRows = []
    if remainingSlots > 0:
        warningRows = sorted([a for a in group if a.get('severity') == 'kWarning'], key=lambda a: a.get('latestTimestampUsecs') or 0, reverse=True)[:remainingSlots]
    groupRows = sorted(criticalRows + warningRows, key=lambda a: a.get('latestTimestampUsecs') or 0, reverse=True)
    for row in groupRows:
        row['ZebraGroup'] = zebraIndex
    sortedAlertDetails.extend(groupRows)
    zebraIndex += 1

# 3) protection groups per cluster, used for the optional Protection Groups table -----------------
# only fetched when showProtectionGroups is set, since it's an extra round of calls that isn't
# needed for the core dashboard. The Helios-wide /mcm/data-protect/protection-groups endpoint
# doesn't return correct/complete data, so instead this queries each cluster's own v2 API
# (/v2/data-protect/protection-groups) individually. heliosCluster switches the API session's
# access-cluster context so calls route through Helios to that specific cluster; it's reset back
# to the Helios-wide context (heliosCluster('-')) once all clusters have been queried.
# includeLastRunInfo=true pulls back each group's most recent run (status, start time, and any
# error/warning messages) in the same call. Paginated via paginationCookie in case a cluster has
# more Protection Groups than fit in a single page.
sortedProtectionGroups = []
if showProtectionGroups:
    print('Gathering protection group data from %s...\n' % vip)

    pgByCluster = {}
    for cluster in clusters:
        if cluster.get('isConnectedToHelios') is not True:
            # skip disconnected clusters - there's nothing current to fetch
            continue
        heliosCluster(cluster.get('clusterName'))

        clusterProtectionGroups = []
        paginationCookie = None
        while True:
            uri = 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=true'
            if paginationCookie:
                uri += '&paginationCookie=%s' % paginationCookie
            pgResp = api('get', uri, v=2) or {}
            clusterProtectionGroups.extend([p for p in (pgResp.get('protectionGroups') or []) if p is not None])
            paginationCookie = pgResp.get('paginationCookie')
            if not paginationCookie:
                break

        if len(clusterProtectionGroups) > 0:
            for pg in clusterProtectionGroups:
                pg['ResolvedClusterName'] = cluster.get('clusterName')
            pgByCluster[cluster.get('clusterName')] = clusterProtectionGroups

    # return the API session to the Helios-wide context
    heliosCluster('-')

    # group by cluster (alphabetically), groups within a cluster sorted by name, zebra striped
    # per cluster like the alert detail table above
    pgZebraIndex = 0
    for clusterName in sorted(pgByCluster.keys(), key=lambda n: n.lower()):
        groupRows = sorted(pgByCluster[clusterName], key=lambda p: (p.get('name') or '').lower())
        for row in groupRows:
            row['ZebraGroup'] = pgZebraIndex
        sortedProtectionGroups.extend(groupRows)
        pgZebraIndex += 1

# 4) build summary counters ----------------------------------------------------------------------
totalClusters = len(clusters)
connectedClusters = len([c for c in clusters if c.get('isConnectedToHelios') is True])
disconnectedClusters = totalClusters - connectedClusters
criticalHealthClusters = len([c for c in clusters if c.get('health') == 'Critical'])
totalCriticalAlerts = len([a for a in openAlerts if a.get('severity') == 'kCritical'])
totalWarningAlerts = len([a for a in openAlerts if a.get('severity') == 'kWarning'])

print('\nFound %s clusters (%s connected, %s disconnected)' % (totalClusters, connectedClusters, disconnectedClusters))
print('%s active critical alerts, %s active warning alerts (last %s days)\n' % (totalCriticalAlerts, totalWarningAlerts, alertDays))
if showProtectionGroups:
    print('%s protection groups found across all clusters\n' % len(sortedProtectionGroups))

sessionUser = api('get', 'sessionUser') or {}
tenantName = ''
if sessionUser.get('profiles'):
    tenantName = sessionUser['profiles'][0].get('tenantName') or ''

# 5) build the HTML ------------------------------------------------------------------------------
sb = []

sb.append('''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Helios Cluster Health Dashboard</title>
<style>
  :root {
    --ok: #3fa66a;
    --warning: #f39c12;
    --critical: #e74c3c;
    --warning-badge: #c68a26;
    --critical-badge: #bd5045;
    --info: #4a80b0;
    --muted: #95a5a6;
    --bg: #f4f6f8;
    --card-bg: #ffffff;
    --panel: #fafbfc;
    --border: #e2e8f0;
    --text: #2c3e50;
    --subtext: #7f8c8d;
    --zebra: #eef2f5;
  }
  body.dark {
    --bg: #10151b;
    --card-bg: #1b232c;
    --panel: #212b36;
    --border: #2c3846;
    --text: #e6edf3;
    --subtext: #9fb0bd;
    --zebra: #202a35;
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    margin: 0;
    padding: 24px;
  }
  .container { max-width: 1320px; margin: 0 auto; }
  h1 { margin: 0 0 4px 0; font-size: 24px; }
  h2.section-title { margin: 32px 0 12px 0; font-size: 16px; color: var(--text); }
  .subtitle { color: var(--subtext); margin-bottom: 24px; font-size: 13px; }
  .cards {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    margin-bottom: 28px;
  }
  .card {
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px 20px;
    min-width: 150px;
    flex: 1;
    box-shadow: 0 1px 2px rgba(0,0,0,0.08);
  }
  .card .value { font-size: 26px; font-weight: 700; }
  .card .label { font-size: 12px; color: var(--subtext); text-transform: uppercase; letter-spacing: 0.04em; margin-top: 4px; }
  .card.ok .value { color: var(--ok); }
  .card.warning .value { color: var(--warning); }
  .card.critical .value { color: var(--critical); }
  .card.muted .value { color: var(--muted); }
  table.dashboard-table {
    width: 100%;
    border-collapse: collapse;
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 1px 2px rgba(0,0,0,0.08);
  }
  table.dashboard-table th {
    text-align: left;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--subtext);
    background: var(--panel);
    padding: 10px 14px;
    border-bottom: 1px solid var(--border);
  }
  table.dashboard-table td {
    padding: 10px 14px;
    border-bottom: 1px solid var(--border);
    font-size: 13px;
    vertical-align: middle;
  }
  table.dashboard-table tr:last-child td { border-bottom: none; }
  table.dashboard-table tr:hover td { background: var(--panel); }
  table.dashboard-table tr.zebra-b td { background: var(--zebra); }
  table.dashboard-table.alerts-table tr:hover td { background: var(--card-bg); }
  table.dashboard-table.alerts-table tr.zebra-b:hover td { background: var(--zebra); }
  table.alert-detail-table th, table.alert-detail-table td { padding: 6px 10px; }
  .date-cell { white-space: nowrap; }
  .cluster-name { font-weight: 600; text-transform: uppercase; }
  .badge {
    display: inline-block;
    padding: 3px 9px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
    color: #fff;
    white-space: nowrap;
  }
  .badge-ok { background: var(--ok); }
  .badge-warning { background: var(--warning-badge); }
  .badge-critical { background: var(--critical-badge); }
  .badge-info { background: var(--info); }
  .badge-muted { background: var(--muted); }
  .pie-wrap { position: relative; width: 48px; height: 48px; flex: none; }
  .pie { width: 48px; height: 48px; border-radius: 50%; }
  .pie-hole {
    position: absolute;
    top: 6px; left: 6px;
    width: 36px; height: 36px;
    border-radius: 50%;
    background: var(--card-bg);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: 700;
  }
  .capacity-cell { display: flex; align-items: center; gap: 10px; }
  .capacity-text { font-size: 11px; color: var(--subtext); }
  .alert-counts { min-width: 84px; }
  .alert-counts span { display: block; font-size: 12px; line-height: 1.5; white-space: nowrap; }
  .alert-counts .crit { color: var(--critical); font-weight: 700; }
  .alert-counts .warn { color: var(--warning); font-weight: 700; }
  .alert-counts .zero { color: var(--subtext); font-weight: 400; }
  .latest-alert-name { font-weight: 600; }
  .latest-alert-age { font-size: 11px; color: var(--subtext); display: block; }
  .no-alert, .no-data { color: var(--subtext); font-size: 12px; }
  .alert-summary { max-width: 320px; }
  .alert-summary .desc { font-size: 12px; color: var(--subtext); display: block; margin-top: 2px; }
  table.pg-table { table-layout: fixed; }
  table.pg-table .alert-summary { max-width: none; overflow-wrap: break-word; }
  footer { margin-top: 20px; font-size: 11px; color: var(--subtext); }
</style>
</head>''')

bodyClass = ' class="dark"' if theme == 'Dark' else ''
sb.append('<body%s>' % bodyClass)
sb.append('<div class="container">')

sb.append('<h1>Helios Cluster Health Dashboard - %s</h1>' % htmlEncode(tenantName))
sb.append('<div class="subtitle">Source: %s &nbsp;|&nbsp; Generated %s &nbsp;|&nbsp; Active alert stats window: last %s day(s)</div>' % (
    htmlEncode(vip), datetime.now().strftime('%Y-%m-%d %H:%M'), alertDays))

# summary cards
sb.append('<div class="cards">')
sb.append('<div class="card"><div class="value">%s</div><div class="label">Total Clusters</div></div>' % totalClusters)
sb.append('<div class="card ok"><div class="value">%s</div><div class="label">Connected</div></div>' % connectedClusters)
sb.append('<div class="card muted"><div class="value">%s</div><div class="label">Disconnected</div></div>' % disconnectedClusters)
sb.append('<div class="card critical"><div class="value">%s</div><div class="label">Clusters w/ Critical Health</div></div>' % criticalHealthClusters)
sb.append('<div class="card critical"><div class="value">%s</div><div class="label">Active Critical Alerts</div></div>' % totalCriticalAlerts)
sb.append('<div class="card warning"><div class="value">%s</div><div class="label">Active Warning Alerts</div></div>' % totalWarningAlerts)
sb.append('</div>')

# cluster table
sb.append('''<table class="dashboard-table">
<thead>
<tr>
  <th>Cluster</th>
  <th>Health</th>
  <th>Version</th>
  <th>Latest Patch</th>
  <th>Upgrade Status</th>
  <th>Nodes</th>
  <th>Capacity</th>
  <th>Active Alerts</th>
  <th>Latest Alert</th>
</tr>
</thead>
<tbody>''')

for cluster in clusters:
    cid = str(cluster.get('clusterId'))
    name = htmlEncode(cluster.get('clusterName'))
    isDisconnected = cluster.get('isConnectedToHelios') is not True
    currentVersion = cluster.get('currentVersion')
    versionShort = currentVersion.split('_release')[0] if currentVersion else None
    version = '&ndash;' if (isDisconnected or not versionShort) else htmlEncode(versionShort)
    patch = '&ndash;' if (isDisconnected or not cluster.get('currentPatchVersion')) else htmlEncode(cluster.get('currentPatchVersion'))
    upgradeStatusHtml = '&ndash;' if isDisconnected else getStatusBadge(cluster.get('status'))
    nodes = '&ndash;' if (isDisconnected or cluster.get('numberOfNodes') is None) else cluster.get('numberOfNodes')

    total = cluster.get('totalCapacity')
    used = cluster.get('usedCapacity')
    pct = 0
    if total and total > 0:
        pct = round((100 * used / total), 1)
    capacityText = '%s / %s' % (formatBytes(used), formatBytes(total))
    hasCapacityData = bool(total and total > 0)
    if isDisconnected or not hasCapacityData:
        capacityCellHtml = '<span class="no-data">&ndash;</span>'
    else:
        capacityCellHtml = '%s<span class="capacity-text">%s</span>' % (getPieHtml(pct), capacityText)

    clusterAlertStats = statsByClusterMap.get(cid)
    critCount = 0
    warnCount = 0
    if clusterAlertStats:
        critCount = clusterAlertStats.get('numCriticalAlerts', 0)
        warnCount = clusterAlertStats.get('numWarningAlerts', 0)
    alertCountsHtml = '<span class="no-data">&ndash;</span>' if isDisconnected else getAlertCountHtml(critCount, warnCount)

    latestAlert = latestAlertMap.get(cid)
    if isDisconnected:
        latestAlertHtml = '<span class="no-alert">Cluster disconnected from Helios</span>'
    elif latestAlert:
        alertName = htmlEncode((latestAlert.get('alertDocument') or {}).get('alertName'))
        if not alertName:
            alertName = htmlEncode(latestAlert.get('alertCategory'))
        alertAge = formatAge(latestAlert.get('latestTimestampUsecs'))
        latestAlertHtml = '%s<br/><span class="latest-alert-name">%s</span><span class="latest-alert-age">%s</span>' % (
            getSeverityBadge(latestAlert.get('severity')), alertName, alertAge)
    else:
        latestAlertHtml = '<span class="no-alert">No open critical/warning alerts</span>'

    sb.append('<tr>')
    sb.append('<td class="cluster-name">%s</td>' % name)
    sb.append('<td>%s</td>' % getHealthBadge(cluster))
    sb.append('<td>%s</td>' % version)
    sb.append('<td>%s</td>' % patch)
    sb.append('<td>%s</td>' % upgradeStatusHtml)
    sb.append('<td>%s</td>' % nodes)
    sb.append('<td><div class="capacity-cell">%s</div></td>' % capacityCellHtml)
    sb.append('<td><div class="alert-counts">%s</div></td>' % alertCountsHtml)
    sb.append('<td>%s</td>' % latestAlertHtml)
    sb.append('</tr>')

sb.append('</tbody></table>')

# optional protection groups table ----------------------------------------------------------------
if showProtectionGroups:
    sb.append('<h2 class="section-title">Protection Groups (%s total, grouped by cluster)</h2>' % len(sortedProtectionGroups))
    sb.append('''<table class="dashboard-table alerts-table pg-table">
<colgroup>
  <col style="width:13%">
  <col style="width:19%">
  <col style="width:10%">
  <col style="width:12%">
  <col style="width:11%">
  <col style="width:8%">
  <col style="width:27%">
</colgroup>
<thead>
<tr>
  <th>Cluster</th>
  <th>Protection Group</th>
  <th>Environment</th>
  <th>Last Run</th>
  <th>Last Status</th>
  <th>Paused</th>
  <th>Errors / Warnings</th>
</tr>
</thead>
<tbody>''')

    if len(sortedProtectionGroups) == 0:
        sb.append('<tr><td colspan="7"><span class="no-data">No protection groups found.</span></td></tr>')
    else:
        for pg in sortedProtectionGroups:
            pgClusterName = htmlEncode(pg.get('ResolvedClusterName'))
            pgName = htmlEncode(pg.get('name'))
            pgEnvironment = formatEnvironment(pg.get('environment'))

            runSummary = getLastRunSummary(pg)
            if runSummary and runSummary.get('startTimeUsecs'):
                lastRunHtml = htmlEncode(formatTimestamp(runSummary.get('startTimeUsecs')))
            else:
                lastRunHtml = '<span class="no-data">&ndash;</span>'
            lastStatusHtml = getRunStatusBadge(runSummary.get('status')) if (runSummary and runSummary.get('status')) else '<span class="badge badge-muted">n/a</span>'
            pausedHtml = getPausedBadge(pg.get('isPaused'))

            messages = []
            if runSummary and runSummary.get('messages'):
                messages = [m for m in runSummary.get('messages') if m]
            issuesHtml = '<span class="desc">%s</span>' % htmlEncode('; '.join(messages)) if len(messages) > 0 else '<span class="no-data">&ndash;</span>'

            zebraClass = 'zebra-a' if (pg.get('ZebraGroup', 0) % 2) == 0 else 'zebra-b'

            sb.append('<tr class="%s">' % zebraClass)
            sb.append('<td class="cluster-name">%s</td>' % pgClusterName)
            sb.append('<td>%s</td>' % pgName)
            sb.append('<td>%s</td>' % pgEnvironment)
            sb.append('<td>%s</td>' % lastRunHtml)
            sb.append('<td>%s</td>' % lastStatusHtml)
            sb.append('<td>%s</td>' % pausedHtml)
            sb.append('<td class="alert-summary">%s</td>' % issuesHtml)
            sb.append('</tr>')

    sb.append('</tbody></table>')

# alert detail table
sb.append('<h2 class="section-title">Open Critical &amp; Warning Alerts (%s shown, up to 3 per cluster)</h2>' % len(sortedAlertDetails))
sb.append('''<table class="dashboard-table alerts-table alert-detail-table">
<thead>
<tr>
  <th>Cluster</th>
  <th>Severity</th>
  <th>Category</th>
  <th>Alert</th>
  <th>Description</th>
  <th class="date-cell">First Seen</th>
  <th class="date-cell">Last Seen</th>
  <th>Occurrences</th>
</tr>
</thead>
<tbody>''')

if len(sortedAlertDetails) == 0:
    sb.append('<tr><td colspan="8"><span class="no-data">No open critical or warning alerts in the selected window.</span></td></tr>')
else:
    for a in sortedAlertDetails:
        alertDocument = a.get('alertDocument') or {}
        alertClusterName = htmlEncode(a.get('ResolvedClusterName'))
        category = htmlEncode(a.get('alertCategory'))
        alertName = htmlEncode(alertDocument.get('alertName'))
        if not alertName:
            alertName = htmlEncode(a.get('alertCode'))
        alertSummary = htmlEncode(alertDocument.get('alertSummary'))
        alertDescriptionHtml = htmlEncode(alertDocument.get('alertDescription')) if alertDocument.get('alertDescription') else '<span class="no-data">&ndash;</span>'
        firstSeen = formatTimestamp(a.get('firstTimestampUsecs'))
        lastSeen = formatTimestamp(a.get('latestTimestampUsecs'))
        occurrences = a.get('dedupCount') if a.get('dedupCount') else 1

        alertCell = '<span class="latest-alert-name">%s</span>' % alertName
        if alertSummary:
            alertCell = '%s<span class="desc">%s</span>' % (alertCell, alertSummary)

        zebraClass = 'zebra-a' if (a.get('ZebraGroup', 0) % 2) == 0 else 'zebra-b'

        sb.append('<tr class="%s">' % zebraClass)
        sb.append('<td class="cluster-name">%s</td>' % alertClusterName)
        sb.append('<td>%s</td>' % getSeverityBadge(a.get('severity')))
        sb.append('<td>%s</td>' % category)
        sb.append('<td class="alert-summary">%s</td>' % alertCell)
        sb.append('<td class="alert-summary">%s</td>' % alertDescriptionHtml)
        sb.append('<td class="date-cell">%s</td>' % firstSeen)
        sb.append('<td class="date-cell">%s</td>' % lastSeen)
        sb.append('<td>%s</td>' % occurrences)
        sb.append('</tr>')

sb.append('</tbody></table>')

sb.append('<footer>heliosDashboard.py &mdash; generated %s</footer>' % datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
sb.append('</div></body></html>')

with open(outfileName, 'w', encoding='utf-8') as f:
    f.write(''.join(sb))

print('\nDashboard saved to %s\n' % outfileName)

if show:
    webbrowser.open('file://' + os.path.abspath(outfileName))
