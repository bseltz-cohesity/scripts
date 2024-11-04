#!/usr/bin/env python
"""Mount an Oracle DB as a View Using python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-ss', '--sourceserver', type=str, required=True)  # name of source oracle server
parser.add_argument('-sd', '--sourcedb', type=str, required=True)  # name of source oracle DB
parser.add_argument('-ts', '--targetserver', type=str, default=None)  # name of target oracle server
parser.add_argument('-n', '--viewname', type=str, default=None)  # name of target oracle server
parser.add_argument('-cc', '--channelcount', type=int, default=None)  # specifies the number of channels to be created
parser.add_argument('-lt', '--logtime', type=str, default=None)  # pit to recover to
parser.add_argument('-l', '--latest', action='store_true')  # recover to latest available pit
parser.add_argument('-w', '--wait', action='store_true')  # wait for completion

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
sourceserver = args.sourceserver
sourcedb = args.sourcedb

if args.targetserver is None:
    targetserver = sourceserver
else:
    targetserver = args.targetserver

if args.viewname is None:
    viewname = sourcedb
else:
    viewname = args.viewname

channelcount = args.channelcount
logtime = args.logtime
latest = args.latest
wait = args.wait

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

### if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# find target host
targetEntity = None
entities = api('get', '/appEntities?appEnvType=19')
for entity in entities:
    if entity['appEntity']['entity']['displayName'].lower() == targetserver.lower():
        targetEntity = entity
if targetEntity is None:
    print("target server not found")
    exit()

# search for UDA backups to recover
search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverApps&searchString=%s&environments=kOracle' % sourcedb, v=2)
objects = None
if search is not None and 'objects' in search:
    objects = [o for o in search['objects'] if 'oracleParams' in o and o['oracleParams']['hostInfo']['name'].lower() == sourceserver.lower()]

if objects is None or len(objects) == 0:
    print('No backups found for Oracle DB %s' % sourcedb)
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
        snapshots = sorted(snapshots, key=lambda o: o['snapshotTimestampUsecs'], reverse=True)
        if snapshots is not None and len(snapshots) > 0:
            if snapshots[0]['snapshotTimestampUsecs'] > latestSnapshotTimeStamp:
                latestSnapshot = snapshots[0]
                latestSnapshotTimeStamp = snapshots[0]['snapshotTimestampUsecs']
                latestSnapshotObject = object
        else:
            if logtime is not None:
                print('No snapshots found for %s from before %s' % (sourcedb, logtime))
            else:
                print('No snapshots found for %s' % sourcedb)
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
        "environment": "kOracle",
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
                logRange['timeRanges'] = sorted(logRange['timeRanges'], key=lambda o: o['endTimeUsecs'], reverse=True)
                if logRange['timeRanges'][0]['endTimeUsecs'] > latestLogPIT:
                    latestLogPIT = logRange['timeRanges'][0]['endTimeUsecs']
                if latest:
                    pit = logRange['timeRanges'][0]['endTimeUsecs']
                    break
                else:
                    if logRange['timeRanges'][0]['endTimeUsecs'] > desiredPIT and logRange['timeRanges'][0]['startTimeUsecs'] <= desiredPIT:
                        pit = desiredPIT
                        break
    if pit is None:
        pit = latestLogPIT
        print('Warning: best available point in time is %s' % usecsToDate(pit))

taskName = "Mount-Oracle-%s-%s" % (sourcedb, viewname)

restoreParams = {
    "name": taskName,
    "snapshotEnvironment": "kOracle",
    "oracleParams": {
        "objects": [
            {
                "snapshotId": latestSnapshot['id']
            }
        ],
        "recoveryAction": "RecoverApps",
        "recoverAppParams": {
            "targetEnvironment": "kOracle",
            "oracleTargetParams": {
                "recoverToNewSource": True,
                "newSourceConfig": {
                    "host": {
                        "id": targetEntity['appEntity']['entity']['id']
                    },
                    "recoveryTarget": "RecoverView",
                    "recoverViewParams": {
                        "viewMountPath": viewname
                    }
                }
            }
        }
    }
}

if channelcount:
    dbChannels = [
        {
            "databaseUniqueName": sourcedb,
            "databaseUuid": objects[0]['uuid'],
            "databaseNodeList": [
                {
                    "hostAddress": targetEntity['appEntity']['entity']['physicalEntity']['name'],
                    "hostId": "%s" % targetEntity['appEntity']['entity']['physicalEntity']['agentStatusVec'][0]['id'],
                    "fqdn": targetEntity['appEntity']['entity']['physicalEntity']['hostname'],
                    "channelCount": channelcount
                }
            ]
        }
    ]
    restoreParams['oracleParams']['recoverAppParams']['oracleTargetParams']['newSourceConfig']['recoverViewParams']['dbChannels'] = dbChannels

# specify point in time
if pit is not None:
    restoreParams['oracleParams']['recoverAppParams']['oracleTargetParams']['newSourceConfig']['recoverViewParams']['restoreTimeUsecs'] = pit
    restoreParams['oracleParams']['objects'][0]['pointInTimeUsecs'] = pit
    recoverTime = usecsToDate(pit)
else:
    recoverTime = usecsToDate(latestSnapshotTimeStamp)

# perform restore
response = api('post', 'data-protect/recoveries', restoreParams, v=2)

if 'errorCode' in response:
    exit(1)

print("Mounting DB %s to %s as view %s..." % (sourcedb, targetserver, viewname))

taskId = response['id']
if taskId is None:
    print('Failed to get restore task ID')
    exit(1)

if wait is True:
    taskId = response['id'].split(':')[2]
    status = api('get', '/restoretasks/%s' % taskId)
    finishedStates = ['kSuccess', 'kFailed', 'kCanceled', 'kFailure']
    while(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates):
        sleep(5)
        status = api('get', '/restoretasks/%s' % taskId)
    if(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess'):
        print('Restore Completed Successfully')
        exit(0)
    else:
        print('Restore Ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
exit(0)
