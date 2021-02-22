#!/usr/bin/env python
"""Recover NAS Volume"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--sourcevolume', type=str, required=True)
parser.add_argument('-n', '--sourcename', type=str, default=None)
parser.add_argument('-t', '--targetvolume', type=str, default=None)
parser.add_argument('-m', '--targetname', type=str, default=None)
parser.add_argument('-b', '--before', type=str, default=None)
parser.add_argument('-r', '--runid', type=int, default=None)
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-l', '--showversions', action='store_true')
parser.add_argument('-a', '--asview', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
sourcevolume = args.sourcevolume
sourcename = args.sourcename
targetvolume = args.targetvolume
targetname = args.targetname
wait = args.wait
overwrite = args.overwrite
showversions = args.showversions
before = args.before
asview = args.asview
runid = args.runid

# authenticate
apiauth(vip, username, domain)

# find source volume
results = api('get', '/searchvms?entityTypes=kNetapp&entityTypes=kGenericNas&entityTypes=kIsilon&entityTypes=kFlashBlade&entityTypes=kPure&vmName=%s' % sourcevolume)

volume = []
if results:
    volume = [v for v in results['vms'] if v['vmDocument']['objectName'].lower() == sourcevolume.lower()]
    if sourcename is not None:
        volume = [v for v in volume if v['vmDocument']['registeredSource']['displayName'].lower() == sourcename.lower()]

if len(volume) == 0:
    if sourcename is not None:
        print('source volume %s not found on %s' % (sourcevolume, sourcename))
    else:
        print('source volume %s not found' % sourcevolume)
    exit(1)

if len(volume) > 1:
    print('there is more than one volume named %s' % sourcevolume)
    exit(1)

doc = volume[0]['vmDocument']

# select latest version before date
if before is not None:
    endusecs = dateToUsecs(before)
    doc['versions'] = [v for v in doc['versions'] if endusecs >= v['snapshotTimestampUsecs']]
    if len(doc['versions']) == 0:
        print('no backups before %s' % before)
        exit(1)

# show available versions
if showversions:
    print('%10s  %s' % ('runId', 'runDate'))
    print('%10s  %s' % ('-----', '-------'))
    for version in doc['versions']:
        print('%10d  %s' % (version['instanceId']['jobInstanceId'], usecsToDate(version['instanceId']['jobStartTimeUsecs'])))
    exit(0)

# select specified run ID
if runid is not None:
    versions = [v for v in doc['versions'] if runid == v['instanceId']['jobInstanceId']]
    if len(versions) == 0:
        print('Run ID %s not found' % runid)
        exit(1)

# select latest version
version = doc['versions'][0]

dateString = datetime.now().strftime("%Y-%m-%d_%H-%M")
print('restoring files...')

if asview:
    # recover as view
    if targetvolume is None:
        targetvolume = sourcevolume
    restoreParams = {
        "name": "Recover-NAS_%s" % dateString,
        "objects": [
            {
                "jobId": doc['objectId']['jobId'],
                "jobUid": {
                    "clusterId": doc['objectId']['jobUid']['clusterId'],
                    "clusterIncarnationId": doc['objectId']['jobUid']['clusterIncarnationId'],
                    "id": doc['objectId']['jobUid']['objectId']
                },
                "jobRunId": version['instanceId']['jobInstanceId'],
                "startedTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
                "protectionSourceId": doc['objectId']['entity']['id']
            }
        ],
        "type": "kMountFileVolume",
        "viewName": targetvolume,
        "restoreViewParameters": {
            "qos": {
                "principalName": "TestAndDev High"
            }
        }
    }
    result = api('post', 'restore/recover', restoreParams)
else:
    # restore to NAS volume
    sources = []
    targetId = None
    targetParentSourceId = None
    if targetvolume:
        # find target volume
        sources = api('get', '/backupsources?allUnderHierarchy=true&envTypes=9&envTypes=11&envTypes=14&envTypes=21&excludeTypes=5')
        if len(sources) > 0:
            if targetname is not None:
                sources = [s for s in sources['entityHierarchy']['children'] if s['entity']['displayName'].lower() == targetname.lower()]
            else:
                sources = [s for s in sources['entityHierarchy']['children'] if s['entity']['displayName'] == 'NAS Mount Points']
            if len(sources) == 0:
                if targetname is not None:
                    print('target %s not found' % targetname)
                else:
                    print('target volume %s not found' % targetvolume)
                exit(1)
            if targetname is not None:
                targetParentSourceId = sources[0]['entity']['id']
            for v in sources[0]['children']:
                if v['entity']['displayName'].lower() == targetvolume.lower():
                    targetId = v['entity']['id']
            if targetId is None:
                if targetname is not None:
                    print('target volume %s not found on %s' % (targetvolume, targetname))
                else:
                    print('target volume %s not found' % targetvolume)
                exit(1)
    else:
        targetId = doc['objectId']['entity']['id']

    restoreParams = {
        "name": "Recover-NAS_%s" % dateString,
        "sourceObjectInfo": {
            "jobId": doc['objectId']['jobId'],
            "jobUid": {
                "clusterId": doc['objectId']['jobUid']['clusterId'],
                "clusterIncarnationId": doc['objectId']['jobUid']['clusterIncarnationId'],
                "id": doc['objectId']['jobUid']['objectId']
            },
            "jobRunId": version['instanceId']['jobInstanceId'],
            "startedTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
            "protectionSourceId": doc['objectId']['entity']['id']
        },
        "targetSourceId": targetId,
        "isFileBasedVolumeRestore": True,
        "filenames": [
            "/"
        ],
        "overwrite": False,
        "preserveAttributes": True,
        "continueOnError": True
    }

    if targetParentSourceId is not None:
        restoreParams['targetParentSourceId'] = targetParentSourceId

    if overwrite:
        restoreParams['overwrite'] = True
    result = api('post', 'restore/files', restoreParams)

if result:
    taskId = result['id']
    if wait:
        # wait for completion
        finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
        status = 'submitted'
        while status not in finishedStates:
            sleep(5)
            restoreTask = api('get', '/restoretasks/%s' % taskId)
            status = restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus']
        if status == 'kSuccess':
            print("Restore finished with status Success")
        else:
            if 'error' in restoreTask[0]['restoreTask']['performRestoreTaskState']['base']:
                errorMsg = restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['error']['errorMsg']
            else:
                errorMsg = ''
            print("Restore finished with status %s" % restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'][1:])
            print(errorMsg)
