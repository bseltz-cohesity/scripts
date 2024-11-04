#!/usr/bin/env python

from datetime import datetime
from time import sleep
from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-s', '--sourceserver', type=str, required=True)
parser.add_argument('-t', '--targetserver', type=str, default=None)
parser.add_argument('-n', '--objectname', action='append', type=str)
parser.add_argument('-p', '--prefix', type=str, default=None)
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-lt', '--logtime', type=str, default=None)
parser.add_argument('-l', '--latest', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-cc', '--concurrency', type=int, default=1)
parser.add_argument('-m', '--mounts', type=int, default=1)
parser.add_argument('-a', '--recoveryargs', action='append', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
sourceserver = args.sourceserver
targetserver = args.targetserver
objectnames = args.objectname
prefix = args.prefix
overwrite = args.overwrite
logtime = args.logtime
latest = args.latest
wait = args.wait
concurrency = args.concurrency
mounts = args.mounts
recoveryargs = args.recoveryargs

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if objectnames is None:
    objectnames = []

if recoveryargs is None:
    recoveryargs = []

if targetserver is None:
    targetserver = sourceserver

# verify overwrite
if targetserver == sourceserver and (len(objectnames) == 0 and prefix is None):
    if overwrite is not True:
        print('-overWrite required if restoring to original location')
        exit()

# search for target server
targetEntity = [t for t in api('get', 'protectionSources/rootNodes?environments=kUDA') if t['protectionSource']['name'].lower() == targetserver.lower()]

if targetEntity is None or len(targetEntity) == 0:
    print('Target server %s not found' % targetserver)
    exit()
else:
    targetEntity = targetEntity[0]

# search for UDA backups to recover
search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverObjects&searchString=%s&environments=kUDA' % sourceserver, v=2)
objects = None
if search is not None and 'objects' in search:
    objects = [o for o in search['objects'] if o['sourceInfo']['name'].lower() == sourceserver.lower()]

if objects is None or len(objects) == 0:
    print('No backups found for UDA entity %s' % sourceserver)
    exit()

# find best snapshot
latestSnapshot = None
latestSnapshotTimeStamp = 0
latestSnapshotObject = None
pit = None
if logtime is not None:
    desiredPIT = dateToUsecs(logtime)
else:
    now = datetime.now()
    desiredPIT = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

for object in objects:
    availableJobInfos = sorted(object['latestSnapshotsInfo'], key=lambda o: o['protectionRunStartTimeUsecs'], reverse=True)
    for jobInfo in availableJobInfos:
        snapshots = api('get', 'data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (object['id'], jobInfo['protectionGroupId']), v=2)
        snapshots = [s for s in snapshots['snapshots'] if s['snapshotTimestampUsecs'] <= desiredPIT]
        if snapshots is not None and len(snapshots) > 0:
            snapshots = sorted(snapshots, key=lambda snap: snap['snapshotTimestampUsecs'], reverse=True)
            if snapshots[0]['snapshotTimestampUsecs'] > latestSnapshotTimeStamp:
                latestSnapshot = snapshots[0]
                latestSnapshotTimeStamp = snapshots[0]['snapshotTimestampUsecs']
                latestSnapshotObject = object
        else:
            if logtime is not None:
                print('No snapshots found for UDA entity %s from before %s' % (sourceserver, logtime))
            else:
                print('No snapshots found for UDA entity %s' % sourceserver)
            exit()

# find log range for desired PIT
if logtime is not None or latest:
    latestLogPIT = 0
    logStart = latestSnapshotTimeStamp
    if logtime is not None:
        logEnd = desiredPIT + 60000000
    else:
        logEnd = desiredPIT
    (clusterId, clusterIncarnationId, protectionGroupId) = latestSnapshot['protectionGroupId'].split(':')
    logParams = {
        "jobUids": [
            {
                "clusterId": int(clusterId),
                "clusterIncarnationId": int(clusterIncarnationId),
                "id": int(protectionGroupId)
            }
        ],
        "environment": "kUDA",
        "protectionSourceId": latestSnapshotObject['id'],
        "startTimeUsecs": int(logStart),
        "endTimeUsecs": int(logEnd)
    }
    logRanges = api('post', 'restore/pointsForTimeRange', logParams)
    if logRanges is not None and len(logRanges) > 0:
        if not isinstance(logRanges, list):
            logRanges = [logRanges]
        for logRange in logRanges:
            if 'timeRanges' in logRange:
                if logRange['timeRanges'][0]['endTimeUsecs'] > latestLogPIT:
                    latestLogPIT = logRange['timeRanges'][0]['endTimeUsecs']
                if latest:
                    pit = logRange['timeRanges'][0]['endTimeUsecs']
                    break
                else:
                    if logRange['timeRanges'][0]['endTimeUsecs'] > desiredPIT and logRange.timeRanges[0]['startTimeUsecs'] <= desiredPIT:
                        pit = desiredPIT
                        break
    if pit is None:
        pit = latestLogPIT
        print('Warning: best available point in time is %s' % usecsToDate(pit))

# define restore parameters
restoreTaskName = "Recover-UDA-%s-%s" % (sourceserver, datetime.now().strftime("%Y-%m-%d_%H-%M-%S"))

restoreParams = {
    "name": restoreTaskName,
    "snapshotEnvironment": "kUDA",
    "udaParams": {
        "recoveryAction": "RecoverObjects",
        "recoverUdaParams": {
            "concurrency": concurrency,
            "mounts": mounts,
            "recoverTo": None,
            "snapshots": [
                {
                    "snapshotId": latestSnapshot['id'],
                    "objects": []
                }
            ],
            "recoveryArgs": ''
        }
    }
}

if len(objectnames) == 0:
    if prefix is not None:
        renameTo = "%s-%s" % (prefix, latestSnapshot['objectName'])
    else:
        renameTo = None
    objectnames.append(latestSnapshot['objectName'])

for o in objectnames:
    if prefix is not None:
        renameTo = "%s-%s" % (prefix, o)
    else:
        renameTo = None
    restoreParams['udaParams']['recoverUdaParams']['snapshots'][0]['objects'].append({"objectName": o,
                                                                                      "overwrite": True,
                                                                                      "renameTo": renameTo})

# specify target host ID
if targetserver != sourceserver:
    restoreParams['udaParams']['recoverUdaParams']['recoverTo'] = targetEntity['protectionSource']['id']

# specify point in time
if pit is not None:
    restoreParams['udaParams']['recoverUdaParams']['snapshots'][0]['pointInTimeUsecs'] = pit
    recoverTime = usecsToDate(pit)
else:
    recoverTime = usecsToDate(latestSnapshotTimeStamp)

# recoveryargs
if len(recoveryargs) > 0:
    for arg in recoveryargs:
        restoreParams['udaParams']['recoverUdaParams']['recoveryArgs'] += '--%s ' % arg
    restoreParams['udaParams']['recoverUdaParams']['recoveryArgs'] = restoreParams['udaParams']['recoverUdaParams']['recoveryArgs'][0:-1]

# perform restore
print('Restoring %s to %s (Point in time: %s)' % (sourceserver, targetserver, recoverTime))
response = api('post', 'data-protect/recoveries', restoreParams, v=2)

if 'errorCode' in response:
    exit(1)

if wait is True:
    taskId = response['id'].split(':')[2]
    status = api('get', '/restoretasks/%s' % taskId)
    finishedStates = ['kSuccess', 'kFailed', 'kCanceled', 'kFailure']
    while status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates:
        sleep(15)
        status = api('get', '/restoretasks/%s' % taskId)
    if status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess':
        print('Restore Completed Successfully')
        exit(0)
    else:
        print('Restore Ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
exit(0)
