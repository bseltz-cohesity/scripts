#!/usr/bin/env python

from datetime import datetime
from time import sleep
from pyhesity import *
import argparse

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
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-n', '--sourceclustername', type=str, required=True)
parser.add_argument('-to', '--targetobject', type=str, default=None)
parser.add_argument('-lt', '--logtime', type=str, default=None)
parser.add_argument('-l', '--latest', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-ss', '--sleeptimeseconds', type=int, default=30)
parser.add_argument('-sd', '--stagingdirectory', type=str, default='/tmp')

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
sourcename = args.sourcename
sourceclustername = args.sourceclustername
targetobject = args.targetobject
logtime = args.logtime
latest = args.latest
wait = args.wait
sleeptimeseconds = args.sleeptimeseconds
stagingdirectory = args.stagingdirectory

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

# search for object to restore
search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverMongodbClusters&searchString=%s&environments=kMongoDBPhysical' % sourceclustername, v=2)
if search is None or 'objects' not in search or search['objects'] is None or len(search['objects']) == 0:
    print('source cluster %s not found' % sourceclustername)
    exit(1)
objects = [o for o in search['objects'] if o['name'].lower() == sourceclustername.lower() and o['sourceInfo']['name'].lower() == sourcename.lower()]
if objects is None or len(objects) == 0:
    print('source cluster %s not found' % sourceclustername)
    exit(1)
object = objects[0]

# search for target to restore to
if targetobject is not None:
    targetparts = targetobject.split('/')
    if len(targetparts) != 4:
        print('targetobject should be in the format "sourcename/orgname/projectname/clustername"')
        exit(1)
    (targetsourcename, targetorgname, targetprojname, targetclusname) = targetobject.split('/')
    sources = api('get','protectionSources/registrationInfo?environments=kMongoDBPhysical')
    if sources is not None and 'rootNodes' in sources and sources['rootNodes'] is not None:
        source = [r for r in sources['rootNodes'] if r['rootNode']['name'].lower() == targetsourcename.lower()]
        if source is None or len(source) == 0:
            print('source %s not found' % targetsourcename)
            exit(1)
    targetsource = api('get','protectionSources?id=%s' % source[0]['rootNode']['id'])
    targetorg = [o for o in targetsource[0]['nodes'] if o['protectionSource']['name'].lower() == targetorgname.lower()]
    if targetorg is None or len(targetorg) == 0:
        print('Organization %s not found in %s' % (targetorgname, targetsourcename))
        exit(1)
    targetproj = [p for p in targetorg[0]['nodes'] if p['protectionSource']['name'].lower() == targetprojname.lower()]
    if targetproj is None or len(targetproj) == 0:
        print('project %s not found in %s/%s' % (targetprojname, targetsourcename, targetorgname))
        exit(1)
    targetclus = [c for c in targetproj[0]['nodes'] if c['protectionSource']['name'].lower() == targetclusname.lower()]
    if targetclus is None or len(targetclus) == 0:
        print('cluster %s not found in %s/%s/%s' % (targetclusname, targetsourcename, targetorgname, targetprojname))
        exit(1)

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
            print('No snapshots found for %s from before %s' % (sourceclustername, logtime))
        else:
            print('No snapshots found for %s' % sourceclustername)
        exit(1)

# find log range for desired PIT
if logtime is not None or latest:
    latestLogPIT = 0
    logStart = latestSnapshotTimeStamp
    if logtime is not None:
        logEnd = desiredPIT + 86400000000
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
        "environment": "kMongoDBPhysical",
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
                    if logRange['timeRanges'][0]['endTimeUsecs'] > desiredPIT and logRange['timeRanges'][0]['startTimeUsecs'] <= desiredPIT:
                        pit = desiredPIT
                        break
    if pit is None:
        pit = latestLogPIT
        print('Best available point in time is %s' % usecsToDate(pit))

# define restore parameters
restoreTaskName = "Recover_Ops_Manager_%s-%s" % (sourceclustername, datetime.now().strftime("%Y-%m-%d_%H-%M-%S"))

restoreParams ={
    "name": restoreTaskName,
    "snapshotEnvironment": "kMongoDBPhysical",
    "mongodbOpsParams": {
        "recoveryAction": "RecoverMongodbClusters",
        "recoverToNewSource": False,
        "newSourceConfig": None,
        "objects": [
            {
                "snapshotId": latestSnapshot['id'],
                "pointInTimeUsecs": None
            }
        ],
        "stagingDirectory": None
    }
}

# specify target host ID
if targetobject is not None:
    restoreParams['mongodbOpsParams']['recoverToNewSource'] = True
    restoreParams['mongodbOpsParams']['newSourceConfig'] = {
        "sourceId": source[0]['rootNode']['id'],
        "orgId": targetorg[0]['protectionSource']['mongoDBPhysicalProtectionSource']['orgInfo']['organizationId'],
        "projectId": targetproj[0]['protectionSource']['mongoDBPhysicalProtectionSource']['projectInfo']['projectId'],
        "clusterId": targetclus[0]['protectionSource']['mongoDBPhysicalProtectionSource']['clusterInfo']['clusterId']
    }

# specify point in time
if pit is not None:
    restoreParams['mongodbOpsParams']['objects'][0]['pointInTimeUsecs'] = pit
    restoreParams['mongodbOpsParams']['stagingDirectory'] = stagingdirectory
    recoverTime = usecsToDate(pit)
else:
    recoverTime = usecsToDate(latestSnapshotTimeStamp)

# perform restore
print('Restoring %s (Point in time: %s)' % (sourceclustername, recoverTime))
response = api('post', 'data-protect/recoveries', restoreParams, v=2)

if 'errorCode' in response:
    exit(1)

if wait is True:
    taskId = response['id'].split(':')[2]
    status = api('get', '/restoretasks/%s' % taskId)
    finishedStates = ['kSuccess', 'kFailed', 'kCanceled', 'kFailure']
    while status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates:
        sleep(sleeptimeseconds)
        status = api('get', '/restoretasks/%s' % taskId)
    if status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess':
        print('Restore Completed Successfully')
        exit(0)
    else:
        print('Restore Ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
exit(0)
