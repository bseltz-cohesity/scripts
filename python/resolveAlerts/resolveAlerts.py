#!/usr/bin/env python
"""Resolve alerts using Python"""

### import pyhesity wrapper module
from pyhesity import *
import argparse
import codecs
import csv
import re

### command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-region', '--region', type=str, default=None)
parser.add_argument('-r', '--resolution', type=str, default=None)
parser.add_argument('-at', '--alerttype', type=str, default=None)
parser.add_argument('-ac', '--alertcode', type=str, default=None)
parser.add_argument('-ai', '--alertid', type=str, default=None)
parser.add_argument('-s', '--severity', type=str, default=None)
parser.add_argument('-sn', '--systemname', type=str, default=None)
parser.add_argument('-ms', '--matchstring', type=str, default=None)
parser.add_argument('-sd', '--startdate', type=str, default=None)
parser.add_argument('-ed', '--enddate', type=str, default=None)
parser.add_argument('-md', '--maxdays', type=int, default=0)
parser.add_argument('-sbd', '--sortbydescription', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
region = args.region
resolution = args.resolution
alerttype = args.alerttype
alertcode = args.alertcode
alertid = args.alertid
severity = args.severity
systemname = args.systemname
matchstring = args.matchstring
startdate = args.startdate
enddate = args.enddate
maxdays = args.maxdays
sortbydescription = args.sortbydescription

# authentication =========================================================
# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant, regionid=region)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm and a cluster name was given, select access cluster
# (without -clustername, alerts are retrieved from all Helios clusters)
if (mcm or vip.lower() in ['helios.cohesity.com', 'helios.gov-cohesity.com']) and clustername is not None:
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

usingHelios = False
accountId = None
if (mcm or vip.lower() in ['helios.cohesity.com', 'helios.gov-cohesity.com']) and clustername is None:
    usingHelios = True
    sessionUser = api('get', 'sessionUser')
    try:
        accountId = sessionUser['salesforceAccount']['accountId']
    except Exception:
        accountId = None


def asList(result):
    """normalize an api result to a list"""
    if isinstance(result, list):
        return result
    if isinstance(result, dict) and 'resolutions' in result and isinstance(result['resolutions'], list):
        return result['resolutions']
    return []


def toUsecs(datestring):
    """convert date string (YYYY-MM-DD or YYYY-MM-DD HH:MM:SS) to usecs"""
    if len(datestring.strip()) <= 10:
        datestring = datestring.strip() + ' 00:00:00'
    return dateToUsecs(datestring)


### build alert query
alertQuery = 'alerts?maxAlerts=1000&alertStateList=kOpen'
if alerttype is not None:
    alertQuery = '%s&alertTypeList=%s' % (alertQuery, alerttype)
if startdate is not None:
    alertQuery = '%s&startDateUsecs=%s' % (alertQuery, toUsecs(startdate))
if enddate is not None:
    alertQuery = '%s&endDateUsecs=%s' % (alertQuery, toUsecs(enddate))
if maxdays > 0:
    alertQuery = '%s&startDateUsecs=%s' % (alertQuery, timeAgo(maxdays, 'days'))

### get alerts
if usingHelios:
    clusterList = ['%s:%s' % (c['clusterId'], c['clusterIncarnationId']) for c in heliosClusters()]
    clusterIds = ','.join(clusterList)
    alerts = asList(api('get', '%s&clusterIdentifiers=%s' % (alertQuery, clusterIds), mcm=True))
    alerts = [a for a in alerts if a['alertState'] != 'kResolved']
    for alert in alerts:
        if 'clusterName' not in alert:
            alert['clusterName'] = alert.get('regionId')
else:
    alerts = asList(api('get', alertQuery))
    alerts = [a for a in alerts if a['alertState'] != 'kResolved']


### filter alerts
def filterAlerts(alerts, filterOnCluster=False):
    if systemname is not None:
        alerts = [a for a in alerts if a.get('clusterName') == systemname]
    if severity is not None:
        alerts = [a for a in alerts if a['severity'].lower() == severity.lower()]
    if usingHelios and clustername is not None and filterOnCluster is True:
        alerts = [a for a in alerts if a.get('clusterName') == clustername]
    if matchstring is not None:
        alerts = [a for a in alerts if re.search(matchstring, a['alertDocument']['alertDescription'], re.IGNORECASE)]
    if alertcode is not None:
        alerts = [a for a in alerts if str(a['alertCode']) == str(alertcode)]
    if alertid is not None:
        alerts = [a for a in alerts if str(a['id']) == str(alertid)]
    return alerts


### resolve alerts directly on a cluster (new or existing resolution)
def resolveAlerts(ids, resolutions):
    resolutions = sorted(resolutions, key=lambda r: r.get('createdTimeUsecs', 0))
    if len(ids) > 0:
        if len(resolutions) > 0:
            resolutionId = resolutions[-1]['resolutionDetails']['resolutionId']
            api('put', 'alertResolutions/%s' % resolutionId, {'alertIdList': ids})
        else:
            alertResolution = {
                'alertIdList': ids,
                'resolutionDetails': {
                    'resolutionDetails': resolution,
                    'resolutionSummary': resolution
                }
            }
            api('post', 'alertResolutions', alertResolution)


### resolve alerts via Helios (new or existing resolution)
def resolveHeliosAlerts(alerts, resolutions):
    resolutions = sorted(resolutions, key=lambda r: r.get('createdTimeUsecs', 0))
    if len(alerts) > 0:
        if len(resolutions) > 0:
            newResolution = {
                'accountId': accountId,
                'tenantId': None,
                'resolutionId': '%s' % resolutions[-1]['resolutionId'],
                'description': '%s' % resolutions[-1].get('description', ''),
                'resolutionName': '%s' % resolutions[-1].get('resolutionName', ''),
                'resolvedAlerts': []
            }
        else:
            newResolution = {
                'accountId': accountId,
                'tenantId': None,
                'description': resolution,
                'resolutionName': resolution,
                'resolvedAlerts': []
            }
        for alert in alerts:
            newResolution['resolvedAlerts'].append({
                'alertId': '%s' % str(alert['id']).split(':')[0],
                'alertName': '%s' % alert['alertDocument'].get('alertName', ''),
                'clusterId': alert.get('clusterId'),
                'firstTimestampUsecs': alert.get('firstTimestampUsecs')
            })
        api('post', 'alert-service/alerts/resolutions', newResolution, mcmv2=True)


alerts = filterAlerts(alerts, True)

if len(alerts) == 0:
    print('No alerts found')
    exit()

### display alerts
if sortbydescription:
    alerts = sorted(alerts, key=lambda a: a['alertDocument']['alertDescription'])
else:
    alerts = sorted(alerts, key=lambda a: a['latestTimestampUsecs'])

for alert in alerts:
    if usingHelios:
        print('%s\t%s\t%s\t%s\t%s\t%s' % (alert['id'], alert.get('clusterName'), usecsToDate(alert['latestTimestampUsecs']), alert['alertType'], alert['severity'], alert['alertDocument']['alertDescription']))
    else:
        print('%s\t%s\t%s\t%s\t%s' % (alert['id'], usecsToDate(alert['latestTimestampUsecs']), alert['alertType'], alert['severity'], alert['alertDocument']['alertDescription']))
print('\n%s alerts' % len(alerts))

### write alerts.csv (latest first)
if usingHelios:
    fieldnames = ['Cluster', 'Latest Occurence', 'Alert Type', 'Severity', 'Description', 'Id']
else:
    fieldnames = ['Latest Occurence', 'Alert Type', 'Severity', 'Description', 'Id']
with codecs.open('alerts.csv', 'w', 'utf-8') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames, lineterminator='\n')
    writer.writeheader()
    for alert in sorted(alerts, key=lambda a: a['latestTimestampUsecs'], reverse=True):
        row = {
            'Latest Occurence': usecsToDate(alert['latestTimestampUsecs']),
            'Alert Type': alert['alertType'],
            'Severity': alert['severity'],
            'Description': alert['alertDocument']['alertDescription'],
            'Id': alert['id']
        }
        if usingHelios:
            row['Cluster'] = alert.get('clusterName')
        writer.writerow(row)

### resolve alerts
if resolution is not None:
    print('Resolving alerts...')
    if usingHelios:
        resolutions = [r for r in asList(api('get', 'alert-service/alerts/resolutions', mcmv2=True)) if r.get('resolutionName').lower() == resolution.lower()]
        resolveHeliosAlerts(alerts, resolutions)
        alertClusters = sorted(set([a['clusterName'] for a in alerts if a.get('clusterName') is not None]))
        for thisClusterName in alertClusters:
            heliosCluster(thisClusterName)
            if LAST_API_ERROR() != 'OK':
                continue
            resolutions = [r for r in asList(api('get', 'alertResolutions')) if r.get('resolutionDetails', {}).get('resolutionSummary').lower() == resolution.lower()]
            theseClusterAlerts = [a for a in asList(api('get', alertQuery)) if a['alertState'] != 'kResolved']
            theseClusterAlerts = filterAlerts(theseClusterAlerts)
            resolveAlerts([a['id'] for a in theseClusterAlerts], resolutions)
        heliosCluster('-')
    else:
        resolutions = [r for r in asList(api('get', 'alertResolutions')) if r.get('resolutionDetails', {}).get('resolutionSummary').lower() == resolution.lower()]
        resolveAlerts([a['id'] for a in alerts], resolutions)
