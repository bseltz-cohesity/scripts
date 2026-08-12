#!/usr/bin/env python
"""Recover a DB2 database from a Cohesity protected backup.

DB2 protection/recovery on this cluster is implemented via the Universal
Data Adapter (UDA) framework using DB2-specific scripts. Recovery job
behavior (redirected restore paths, rollforward, timeouts, etc.) is passed
to those scripts as named key/value pairs inside recoveryJobArguments.
"""

from datetime import datetime
from time import sleep
from pyhesity import *
import argparse
import base64
import json

parser = argparse.ArgumentParser()

# modern authentication arguments =========================================
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
# end modern authentication arguments =====================================

# object/snapshot selection
parser.add_argument('-s', '--sourceserver', type=str, required=True)
parser.add_argument('-ts', '--targetserver', type=str, default=None)
parser.add_argument('-n', '--objectname', action='append', type=str)
parser.add_argument('-p', '--prefix', type=str, default=None)
parser.add_argument('-tdb', '--targetdbname', type=str, default=None, help="Exact name for the restored database (e.g. restore SAMPLE as a new database named PROD). Overrides --prefix, and can only be used with a single -n/--objectname")
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-lt', '--logtime', type=str, default=None)
parser.add_argument('-l', '--latest', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')

# recovery options (top level recoverUdaParams fields)
parser.add_argument('-cc', '--concurrency', type=int, default=1)
parser.add_argument('-mnt', '--mounts', type=int, default=1)

# restore settings -> recoveryJobArguments (named DB2 script arguments)
parser.add_argument('-rd', '--redirected', action='store_true', help="Perform a Redirected Restore instead of a Regular Restore")
parser.add_argument('-rs', '--redirectionscript', type=str, default='', help="Redirection script path (redirected restore)")
parser.add_argument('-ndp', '--newdatapath', type=str, default='', help="New Data Path (redirected restore)")
parser.add_argument('-nlp', '--newlogpath', type=str, default='', help="New Log Path (redirected restore)")
parser.add_argument('-ldd', '--localdbdir', type=str, default='', help="Local Database Directory (redirected restore)")
parser.add_argument('-nrf', '--norollforward', action='store_true', help="Disable Rollforward Database (enabled by default)")

# advanced options -> recoveryJobArguments
parser.add_argument('-po', '--parallelobjects', type=str, default='', help="Number of objects to restore in parallel")
parser.add_argument('-rt', '--rpctimeout', type=str, default='', help="RPC timeout (seconds)")
parser.add_argument('-mio', '--maxiobytes', type=str, default='', help="Max IO Read Size From Cohesity (bytes)")
parser.add_argument('-ev', '--envvars', type=str, default='', help="Environment Variables")

# escape hatch for any additional/future job arguments not covered above
parser.add_argument('-a', '--recoveryargs', action='append', type=str, help="Additional recoveryJobArguments as KEY=VALUE")

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
targetserver = args.targetserver
objectnames = args.objectname
prefix = args.prefix
targetdbname = args.targetdbname
overwrite = args.overwrite
logtime = args.logtime
latest = args.latest
wait = args.wait
concurrency = args.concurrency
mounts = args.mounts

redirected = args.redirected
redirectionscript = args.redirectionscript
newdatapath = args.newdatapath
newlogpath = args.newlogpath
localdbdir = args.localdbdir
norollforward = args.norollforward
parallelobjects = args.parallelobjects
rpctimeout = args.rpctimeout
maxiobytes = args.maxiobytes
envvars = args.envvars
recoveryargs = args.recoveryargs

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

if objectnames is None:
    objectnames = []

if recoveryargs is None:
    recoveryargs = []

if targetserver is None:
    targetserver = sourceserver

# -tdb/--targetdbname renames a single restored object to an exact name; it doesn't make
# sense (and would collide) when restoring more than one object at a time
if targetdbname is not None and len(objectnames) > 1:
    print('-tdb, --targetdbname can only be used when restoring a single object (one -n, --objectname)')
    exit(1)

# verify overwrite
if targetserver == sourceserver and (len(objectnames) == 0 and prefix is None and targetdbname is None):
    if overwrite is not True:
        print('-overWrite required if restoring to original location')
        exit()

# search for target server (registered UDA source for the DB2 target host/instance)
targetEntity = [t for t in api('get', 'protectionSources/rootNodes?environments=kUDA') if t['protectionSource']['name'].lower() == targetserver.lower()]

if targetEntity is None or len(targetEntity) == 0:
    print('Target server %s not found' % targetserver)
    exit()
else:
    targetEntity = targetEntity[0]

# search for DB2 backups to recover
search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverObjects&searchString=%s&environments=kUDA' % sourceserver, v=2)
objects = None
if search is not None and 'objects' in search:
    objects = [o for o in search['objects'] if o['sourceInfo']['name'].lower() == sourceserver.lower()]

if objects is None or len(objects) == 0:
    print('No backups found for DB2 entity %s' % sourceserver)
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
                print('No snapshots found for DB2 entity %s from before %s' % (sourceserver, logtime))
            else:
                print('No snapshots found for DB2 entity %s' % sourceserver)
            exit()

# find log range for desired PIT
if logtime is not None or latest:
    latestLogPIT = 0
    # start of the day (12 AM) on which the latest snapshot was taken
    snapshotMidnight = usecsToDateTime(latestSnapshotTimeStamp).replace(hour=0, minute=0, second=0, microsecond=0)
    logStart = dateToUsecs(snapshotMidnight)
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
    latestFullSnapshotTime = 0
    bestFullSnapshot = None
    if logRanges is not None and len(logRanges) > 0:
        if not isinstance(logRanges, list):
            logRanges = [logRanges]
        for logRange in logRanges:
            # a newer full snapshot supersedes the log chain that came before it
            if 'fullSnapshotInfo' in logRange:
                for fullSnapshot in logRange['fullSnapshotInfo']:
                    fullSnapshotTime = fullSnapshot['restoreInfo']['startTimeUsecs']
                    if fullSnapshotTime <= desiredPIT and fullSnapshotTime > latestFullSnapshotTime:
                        latestFullSnapshotTime = fullSnapshotTime
                        bestFullSnapshot = fullSnapshot
            if 'timeRanges' in logRange:
                # only consider a log range if it actually extends forward from the
                # snapshot we've selected as the recovery base -- a range that ends at or
                # before that snapshot's own timestamp belongs to a stale/superseded chain
                if logRange['timeRanges'][0]['endTimeUsecs'] > latestSnapshotTimeStamp:
                    if logRange['timeRanges'][0]['endTimeUsecs'] > latestLogPIT:
                        latestLogPIT = logRange['timeRanges'][0]['endTimeUsecs']
                    if latest:
                        pit = logRange['timeRanges'][0]['endTimeUsecs']
                        break
                    else:
                        if logRange['timeRanges'][0]['endTimeUsecs'] > desiredPIT and logRange['timeRanges'][0]['startTimeUsecs'] <= desiredPIT:
                            pit = desiredPIT
                            break

    # if a full snapshot exists that is newer than both the snapshot already selected and
    # the best point in time reachable via logs, recover from that full snapshot directly
    # instead of rolling forward via (now stale) logs. Build its snapshotId directly from
    # the jobUid/jobRunId/startTimeUsecs returned here rather than looking it up via the
    # snapshots list endpoint, since a brand new full snapshot may not be indexed there yet.
    usedNewerFullSnapshot = False
    if bestFullSnapshot is not None and latestFullSnapshotTime > latestSnapshotTimeStamp and latestFullSnapshotTime > max(pit or 0, latestLogPIT):
        jobUid = bestFullSnapshot['restoreInfo']['jobUid']
        snapshotIdFields = {
            "a_clusterId": jobUid['clusterId'],
            "b_clusterIncarnationId": jobUid['clusterIncarnationId'],
            "c_jobId": jobUid['id'],
            "e_jobInstanceId": bestFullSnapshot['restoreInfo']['jobRunId'],
            "f_runStartTimeUsecs": latestFullSnapshotTime,
            "g_objectId": latestSnapshotObject['id']
        }
        newSnapshotId = base64.b64encode(json.dumps(snapshotIdFields, separators=(',', ':')).encode('utf-8')).decode('utf-8')
        latestSnapshot = dict(latestSnapshot)
        latestSnapshot['id'] = newSnapshotId
        latestSnapshotTimeStamp = latestFullSnapshotTime
        pit = None
        usedNewerFullSnapshot = True
        print('A more recent full snapshot is available; recovering from snapshot taken at %s' % usecsToDate(latestSnapshotTimeStamp))

    if pit is None and not usedNewerFullSnapshot:
        if latestLogPIT > 0:
            # a log range was found, but not one that fully covers the desired time
            pit = latestLogPIT
            print('Warning: best available point in time is %s' % usecsToDate(pit))
        elif logtime is not None:
            # user asked for a specific point in time, but no log backups exist to support it
            print('No log backups found to support point-in-time recovery at %s' % logtime)
            exit(1)
        else:
            # -latest was requested but there are no log backups beyond the snapshot itself;
            # recover from the snapshot as-is instead of sending an invalid pointInTimeUsecs of 0
            print('No log backups found beyond the selected snapshot; recovering from snapshot taken at %s' % usecsToDate(latestSnapshotTimeStamp))

# define restore parameters
restoreTaskName = "Recover-DB2-%s-%s" % (sourceserver, datetime.now().strftime("%Y-%m-%d_%H-%M-%S"))

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
            "recoveryArgs": None
        }
    }
}

if len(objectnames) == 0:
    objectnames.append(latestSnapshot['objectName'])

anyRename = False
for o in objectnames:
    if targetdbname is not None:
        renameTo = targetdbname
    elif prefix is not None:
        renameTo = "%s-%s" % (prefix, o)
    else:
        renameTo = None
    if renameTo is not None:
        anyRename = True
    restoreParams['udaParams']['recoverUdaParams']['snapshots'][0]['objects'].append({"objectName": o,
                                                                                       "objectId": None,
                                                                                       "overwrite": overwrite,
                                                                                       "renameTo": renameTo})

# specify target host ID: required for a "New Location" restore (different target host), and
# also required when restoring into a renamed/new object even on the same host
if targetserver != sourceserver or anyRename:
    restoreParams['udaParams']['recoverUdaParams']['recoverTo'] = targetEntity['protectionSource']['id']

# specify point in time
if pit is not None:
    restoreParams['udaParams']['recoverUdaParams']['snapshots'][0]['pointInTimeUsecs'] = pit
    recoverTime = usecsToDate(pit)
else:
    recoverTime = usecsToDate(latestSnapshotTimeStamp)

# recoveryJobArguments -> named DB2 script arguments (Restore Settings/Advanced Options in UI)
recoveryJobArguments = [
    {"key": "restore_type", "value": "redirected" if redirected else "regular"},
    {"key": "redirection_script_path", "value": redirectionscript},
    {"key": "new_data_path", "value": newdatapath},
    {"key": "new_log_path", "value": newlogpath},
    {"key": "local_db_dir", "value": localdbdir},
    {"key": "rollforward_database", "value": "false" if norollforward else "true"},
    {"key": "parallel_objects", "value": parallelobjects},
    {"key": "rpc_timeout", "value": rpctimeout},
    {"key": "max_io_bytes", "value": maxiobytes},
    {"key": "environment_variables", "value": envvars}
]

# append any additional custom job arguments (-a KEY=VALUE)
for arg in recoveryargs:
    if '=' in arg:
        (argKey, argValue) = arg.split('=', 1)
    else:
        argKey = arg
        argValue = ''
    recoveryJobArguments.append({"key": argKey, "value": argValue})

restoreParams['udaParams']['recoverUdaParams']['recoveryJobArguments'] = recoveryJobArguments

# perform restore
print('Restoring %s to %s (Point in time: %s)' % (sourceserver, targetserver, recoverTime))
response = api('post', 'data-protect/recoveries', restoreParams, v=2)

if response is None or 'errorCode' in response:
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