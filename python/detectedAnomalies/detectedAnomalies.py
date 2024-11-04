#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
import syslog
import json
import os
import codecs

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-m', '--minimumstrength', type=int, default=10)  # minimum anomaly strength to report
parser.add_argument('-y', '--days', type=int, default=7)  # minimum anomaly strength to report
parser.add_argument('-f', '--maxlogfilesize', type=int, default=10000)  # max size to truncate log
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
minimumStrength = args.minimumstrength
days = args.days
maxlogfilesize = args.maxlogfilesize

apiauth(vip=vip, username=username, domain=domain, password=password, helios=True)

# load cache of previously reported anomalies
SCRIPTDIR = os.path.dirname(os.path.realpath(__file__))
CACHEFILE = os.path.join(SCRIPTDIR, 'ANOMALYCACHE.txt')
if os.path.exists(CACHEFILE):
    f = open(CACHEFILE, 'r')
    idcache = [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()
else:
    idcache = []

# trim cache file
newidcache = []
minstamp = timeAgo(31, 'days')
for id in idcache:
    (obj, stamp) = id.split(':')
    if int(stamp) > minstamp:
        newidcache.append(id)
idcache = newidcache

# truncate log file
LOGFILE = os.path.join(SCRIPTDIR, 'anomalyLog.txt')
try:
    log = codecs.open(LOGFILE, 'r', 'utf-8')
    logfile = log.read()
    log.close()
    if len(logfile) > maxlogfilesize:
        lines = logfile.split('\n')
        linecount = int(len(lines) / 2)
        log = codecs.open(LOGFILE, 'w')
        log.writelines('\n'.join(lines[linecount:]))
        log.close()
except Exception:
    pass

log = codecs.open(LOGFILE, 'a', 'utf-8')

print('\nGetting Detected Anomalies...\n')
endUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
startUsecs = timeAgo(days, 'days')
alerts = api('get', 'alerts?alertCategoryList=kSecurity&alertStateList=kOpen&endDateUsecs=%s&maxAlerts=1000&startDateUsecs=%s&_includeTenantInfo=true' % (endUsecs, startUsecs), mcm=True)
alerts = [a for a in alerts if a['alertType'] == 16011]
for alert in alerts:
    timestampUsecs = alert['latestTimestampUsecs']
    clusterName = alert['clusterName']
    anomalyId = alert['id']
    jobId = [p['value'] for p in alert['propertyList'] if p['key'] == 'jobId'][0]
    jobName = [p['value'] for p in alert['propertyList'] if p['key'] == 'jobName'][0]
    objectName = [p['value'] for p in alert['propertyList'] if p['key'] == 'object'][0]
    sourceName = [p['value'] for p in alert['propertyList'] if p['key'] == 'source'][0]
    sourceType = [p['value'] for p in alert['propertyList'] if p['key'] == 'environment'][0][1:]
    sourceId = [p['value'] for p in alert['propertyList'] if p['key'] == 'entityId'][0]
    anomalyStrength = [p['value'] for p in alert['propertyList'] if p['key'] == 'anomalyStrength'][0]
    lastcleanTimeStampUsecs = [p['value'] for p in alert['propertyList'] if p['key'] == 'jobStartTimeUsecs'][0]
    lastCleanTimeStamp = usecsToDate(lastcleanTimeStampUsecs)
    timeStamp = usecsToDate(timestampUsecs)
    alertDict = {
        "clusterName": clusterName,
        "protectionGroup": jobName,
        "latestAnomalousSnapshotDate": timeStamp,
        "lastCleanSnapshotDate": lastCleanTimeStamp,
        "protectionSource": sourceName,
        "environment": sourceType,
        "sourceId": sourceId,
        "objectName": objectName,
        "anomalyStrength": anomalyStrength
    }
    if int(anomalyStrength) >= minimumStrength and anomalyId not in idcache:
        print('          Cluster: %s\n Protection Group: %s\n Suspected Backup: %s\n Last Good Backup: %s\nRegistered Source: %s (%s)\n      Object Name: %s (%s)\n Anomaly Strength: %s%%\n' % (clusterName, jobName, timeStamp, lastCleanTimeStamp, sourceName, sourceType, objectName, sourceType, anomalyStrength))
        log.write('\n          Cluster: %s\n Protection Group: %s\n Suspected Backup: %s\n Last Good Backup: %s\nRegistered Source: %s (%s)\n      Object Name: %s (%s)\n Anomaly Strength: %s%%\n' % (clusterName, jobName, timeStamp, lastCleanTimeStamp, sourceName, sourceType, objectName, sourceType, anomalyStrength))
        idcache.append(anomalyId)
        syslog.syslog(syslog.LOG_CRIT, json.dumps(alertDict))
    # changeLog = api('get', 'snapshots/changelog?jobId=%s&snapshot1TimeUsecs=%s&snapshot2TimeUsecs=%s&pageCount=50&pageNumber=0' % (jobId, lastcleanTimeStampUsecs, timestampUsecs), quiet=True)

# update cache file
f = open(CACHEFILE, 'w')
for id in idcache:
    f.write('%s\n' % id)
f.close()
log.close()
