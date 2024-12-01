#!/usr/bin/env python
"""Recover Oracle Archive Logs Using python"""

# version: 2024-12-01

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
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-ss', '--sourceserver', type=str, required=True)
parser.add_argument('-sd', '--sourcedb', type=str, required=True)
parser.add_argument('-ts', '--targetserver', type=str, default=None)
parser.add_argument('-td', '--targetdb', type=str, default=None)
parser.add_argument('-oh', '--oraclehome', type=str, default=None)
parser.add_argument('-ob', '--oraclebase', type=str, default=None)
parser.add_argument('-ch', '--channels', type=int, default=1)
parser.add_argument('-cn', '--channelnode', type=str, default=None)
parser.add_argument('-rt', '--rangetype', type=str, choices=['lsn', 'scn', 'time'], default='lsn')
parser.add_argument('-st', '--starttime', type=str, default=None)
parser.add_argument('-et', '--endtime', type=str, default=None)
parser.add_argument('-sr', '--startofrange', type=int, default=None)
parser.add_argument('-er', '--endofrange', type=int, default=None)
parser.add_argument('-ii', '--incarnationid', type=int, default=None)
parser.add_argument('-ri', '--resetlogid', type=int, default=None)
parser.add_argument('-ti', '--threadid', type=int, default=None)
parser.add_argument('-p', '--path', type=str, required=True)
parser.add_argument('-s', '--showranges', action='store_true')
parser.add_argument('-dbg', '--dbg', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-pr', '--progress', action='store_true')

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
sourceserver = args.sourceserver
sourcedb = args.sourcedb
oraclehome = args.oraclehome
oraclebase = args.oraclebase
channels = args.channels
channelnode = args.channelnode
path = args.path
rangetype = args.rangetype
showranges = args.showranges
starttime = args.starttime
endtime = args.endtime
startofrange = args.startofrange
endofrange = args.endofrange
incarnationid = args.incarnationid
resetlogid = args.resetlogid
threadid = args.threadid
progress = args.progress
wait = args.wait
dbg = args.dbg
sameserver = False
if args.targetserver is None:
    targetserver = sourceserver
    sameserver = True
else:
    targetserver = args.targetserver
    if targetserver.lower() == sourceserver.lower():
        sameserver = True
    else:
        if oraclebase is None or oraclehome is None:
            print('oraclebase and oracle home are required when recovering to an alternate server')
            exit(1)
if args.targetdb is None:
    targetdb = sourcedb

rangetypeinfos = {
    'lsn': 'SequenceRangeInfo',
    'scn': 'ScnRangeInfo',
    'time': 'TimeRangeInfo'
}
rangetypeinfo = rangetypeinfos[rangetype]
rangetypes = {
    'lsn': 'Sequence',
    'scn': 'Scn',
    'time': 'Time'
}
rtype = rangetypes[rangetype]

sameDB = False

configurechannels = False
if channelnode is not None or channels > 1:
    configurechannels = True
    if channels > 1 and channelnode is None:
        channelnode = targetserver

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

now = datetime.now()
midnight = datetime.combine(now, datetime.min.time())
midnightusecs = dateToUsecs(midnight)
tonightusecs = midnightusecs + 86399000000

# search for database to recover
search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverObjects&searchString=%s&environments=kOracle' % sourceserver, v=2)
objects = None
if search is not None and 'objects' in search:
    objects = [o for o in search['objects'] if o['oracleParams']['hostInfo']['name'].lower() == sourceserver.lower()]

# narrow to the correct DB name
if objects is not None and len(objects) > 0:
    objects = [o for o in objects if o['name'].lower() == sourcedb.lower()]
if objects is None or len(objects) == 0:
    print('No backups found for oracle DB %s/%s' % (sourceserver, sourcedb))
    exit()

# find best snapshot
latestSnapshot = None
latestSnapshotTimeStamp = 0
latestSnapshotObject = None

for object in objects:
    availableJobInfos = sorted(object['latestSnapshotsInfo'], key=lambda o: o['protectionRunStartTimeUsecs'], reverse=True)
    for jobInfo in availableJobInfos:
        snapshots = api('get', 'data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (object['id'], jobInfo['protectionGroupId']), v=2)
        snapshots = [s for s in snapshots['snapshots']]
        if snapshots is not None and len(snapshots) > 0:
            localsnapshots = [s for s in snapshots if s['snapshotTargetType'] == 'Local']
            if localsnapshots is not None and len(localsnapshots) > 0:
                snapshots = localsnapshots
            if snapshots[-1]['snapshotTimestampUsecs'] > latestSnapshotTimeStamp:
                latestSnapshot = snapshots[-1]
                latestSnapshotTimeStamp = snapshots[-1]['snapshotTimestampUsecs']
                latestSnapshotObject = object

if latestSnapshotObject is None:
    print('No snapshots found for oracle entity %s' % sourceserver)
    exit(1)

ranges = api('get','data-protect/objects/%s/pit-ranges?toTimeUsecs=%s&protectionGroupIds=%s&fromTimeUsecs=0' % (latestSnapshotObject['id'], tonightusecs, latestSnapshot['protectionGroupId']), v=2)

ranges = ranges['oracleRestoreRangeInfo'][rangetypeinfo]

if starttime is not None:
    starttimeusecs = dateToUsecs(starttime)
if endtime is not None:
    endtimeusecs = dateToUsecs(endtime)

# filter ranges
if rangetype == 'time':
    if starttime is not None:
        ranges = [r for r in ranges if r['startOfRange'] <= starttimeusecs and r['endOfRange'] > starttimeusecs]
    if endtime is not None:
        ranges = [r for r in ranges if r['endOfRange'] >= endtimeusecs]
else:
    if incarnationid is not None:
        ranges = [r for r in ranges if r['incarnationId'] == incarnationid]
    if resetlogid is not None:
        ranges = [r for r in ranges if r['resetLogId'] == resetlogid]
    if threadid is not None:
        ranges = [r for r in ranges if r['threadId'] == threadid]
    if startofrange is not None:
        ranges = [r for r in ranges if r['startOfRange'] <= startofrange and r['endOfRange'] > startofrange]
    if endofrange is not None:
        ranges = [r for r in ranges if r['endOfRange'] >= endofrange]

# display ranges
if showranges is True:
    for range in ranges:
        if rangetype == 'time':
             print("\nstartOfRange: %s" % usecsToDate(range['startOfRange']))
             print("endOfRange: %s" % usecsToDate(range['endOfRange']))
        else:
             print("\nstartOfRange: %s" % range['startOfRange'])
             print("endOfRange: %s" % range['endOfRange'])
             print("resetLogId: %s" % range['resetLogId'])
             print("incarnationId: %s" % range['incarnationId'])
             if rangetype == 'lsn':
                 print("threadId: %s" % range['threadId'])
    print('')
    exit()

# select range
if rangetype == 'time':
    range = ranges[-1]
    if starttime is not None:
        range['startOfRange'] = starttimeusecs
    if endtime is not None:
        range['endOfRange'] = endofrange
else:
    range = ranges[-1]
    if startofrange is not None:
        range['startOfRange'] = startofrange
    if endofrange is not None:
        range['endOfRange'] = endofrange

# find target server
targetEntity = [e for e in api('get', 'protectionSources/registrationInfo?environments=kOracle')['rootNodes'] if e['rootNode']['name'].lower() == targetserver.lower()]
if targetEntity is None or len(targetEntity) == 0:
    print('Target Server %s Not Found' % targetserver)
    exit(1)
targetSource = api('get', 'protectionSources?useCachedData=false&id=%s&allUnderHierarchy=false' % targetEntity[0]['rootNode']['id'])

taskName = "Recover-Oracle-Logs-%s-%s-%s" % (sourceserver, sourcedb, now.strftime("%Y-%m-%d_%H-%M-%S"))

recoveryParams = {
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
                "recoverToNewSource": False,
            }
        }
    }
}

if sameserver is True:
    recoveryParams["oracleParams"]["recoverAppParams"]["oracleTargetParams"]["originalSourceConfig"] = {
        "dbChannels": None,
        "granularRestoreInfo": None,
        "oracleArchiveLogInfo": {
            "archiveLogRestoreDest": path,
            "rangeType": rtype,
            "rangeInfoVec": [
                range
            ]
        },
        "rollForwardLogPathVec": None,
        "rollForwardTimeMsecs": None,
        "attemptCompleteRecovery": False
    }
else:
    recoveryParams["oracleParams"]["recoverAppParams"]["oracleTargetParams"]["newSourceConfig"] = {
        "host": {
            "id": targetSource[0]['protectionSource']['id']
        },
        "recoveryTarget": "RecoverDatabase",
        "recoverDatabaseParams": {
            "bctFilePath": None,
            "databaseName": targetdb,
            "enableArchiveLogMode": True,
            "numTempfiles": None,
            "oracleBaseFolder": oraclebase,
            "oracleHomeFolder": oraclehome,
            "pfileParameterMap": None,
            "redoLogConfig": {
                "groupMembers": []
            },
            "newPdbName": None,
            "nofilenameCheck": False,
            "newNameClause": None,
            "oracleSid": targetdb,
            "systemIdentifier": None,
            "dbChannels": None,
            "granularRestoreInfo": None,
            "oracleArchiveLogInfo": {
                "archiveLogRestoreDest": path,
                "rangeType": rtype,
                "rangeInfoVec": [
                    range
                ]
            },
            "oracleUpdateRestoreOptions": None,
            "isMultiStageRestore": False,
            "rollForwardLogPathVec": None,
            "disasterRecoveryOptions": None,
            "restoreToRac": False
        }
    }
    recoveryParams["oracleParams"]["recoverAppParams"]["oracleTargetParams"]["recoverToNewSource"] = True

# configure channels
channelConfig = None
if configurechannels is True:
    if channelnode is not None and 'networkingInfo' in targetSource[0]['protectionSource']['physicalProtectionSource']:
        channelNodes = [n for n in targetSource[0]['protectionSource']['physicalProtectionSource']['networkingInfo']['resourceVec'] if n['type'] == 'kServer']
        channelNodes = [n for n in channelNodes if channelnode.lower() in [e['fqdn'].lower() for e in n['endpoints']]]
        if channelNodes is None or len(channelNodes) == 0:
            print('%s not found' % channelnode)
            exit(1)
        endPoint = [e for e in channelNodes[0]['endpoints'] if 'ipv4Addr' in e and e['ipv4Addr'] is not None][0]
        agent = [a for a in targetSource[0]['protectionSource']['physicalProtectionSource']['agents'] if a['name'] == endPoint['fqdn']][0]
        channelConfig = {
            "databaseUniqueName": latestSnapshotObject['name'],
            "databaseUuid": latestSnapshotObject['uuid'],
            "databaseNodeList": [
                {
                    "hostAddress": endPoint['ipv4Addr'],
                    "hostId": str(agent['id']),
                    "fqdn": endPoint['fqdn'],
                    "channelCount": channels,
                    "port": None
                }
            ],
            "enableDgPrimaryBackup": True,
            "rmanBackupType": "kImageCopy",
            "credentials": None
        }
    else:
        if channels > 1:
            agent = [a for a in targetSource[0]['protectionSource']['physicalProtectionSource']['agents'] if a['name'] == targetSource[0]['protectionSource']['name']][0]
            channelConfig = {
                "databaseUniqueName": latestSnapshotObject['name'],
                "databaseUuid": latestSnapshotObject['uuid'],
                "databaseNodeList": [
                    {
                        "hostAddress": targetSource[0]['protectionSource']['name'],
                        "hostId": str(agent['id']),
                        "fqdn": targetSource[0]['protectionSource']['physicalProtectionSource']['hostName'],
                        "channelCount": channels,
                        "port": None
                    }
                ],
                "enableDgPrimaryBackup": True,
                "rmanBackupType": "kImageCopy",
                "credentials": None
            }
    if channelConfig is not None:
        if sameserver is True:
            recoveryParams["oracleParams"]["recoverAppParams"]["oracleTargetParams"]["originalSourceConfig"]["dbChannels"] = channelConfig
        else:
            recoveryParams["oracleParams"]["recoverAppParams"]["oracleTargetParams"]["newSourceConfig"]["recoverDatabaseParams"]["dbChannels"] = channelConfig

if dbg:
    display(recoveryParams)
    exit()

print('Performing recovery...')
response = api('post', 'data-protect/recoveries', recoveryParams, v=2)
if 'errorCode' in response or 'id' not in response:
    display(response)
    exit(1)

if wait is True or progress is True:
    lastProgress = -1
    taskId = response['id'].split(':')[2]
    status = api('get', '/restoretasks/%s' % taskId)
    finishedStates = ['kSuccess', 'kFailed', 'kCanceled', 'kFailure']
    while status is None or len(status) == 0 or 'restoreTask' not in status[0] or status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates:
        sleep(15)
        status = api('get', '/restoretasks/%s' % taskId)
        if progress is True:
            progressMonitor = api('get', '/progressMonitors?taskPathVec=restore_sql_%s&includeFinishedTasks=true&excludeSubTasks=false' % taskId)
            try:
                percentComplete = progressMonitor['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                percentComplete = int(round(percentComplete, 0))
                if percentComplete > lastProgress:
                    print('%s percent complete' % percentComplete)
                    lastProgress = percentComplete
            except Exception:
                pass
    if status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess':
        print('Recovery Completed Successfully')
        exit(0)
    else:
        print('Recovery Ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
exit(0)
