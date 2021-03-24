#!/usr/bin/env python
"""restore NAS files using python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep
import sys

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # username
parser.add_argument('-d', '--domain', type=str, default='local')      # domain - defaults to local
parser.add_argument('-s', '--sourcevolume', type=str, required=True)
parser.add_argument('-n', '--sourcename', type=str, default=None)
parser.add_argument('-t', '--targetvolume', type=str, default=None)
parser.add_argument('-m', '--targetname', type=str, default=None)
parser.add_argument('-f', '--filename', type=str, action='append')    # file name to restore
parser.add_argument('-i', '--filelist', type=str, default=None)       # text file list of files to restore
parser.add_argument('-p', '--restorepath', type=str, default=None)    # destination path
parser.add_argument('-b', '--before', type=str, default=None)
parser.add_argument('-r', '--runid', type=int, default=None)
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-l', '--showversions', action='store_true')

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
runid = args.runid
files = args.filename
filelist = args.filelist
restorepath = args.restorepath
wait = args.wait

if sys.version_info > (3,):
    long = int

# gather volume list
if files is None:
    files = []
if filelist is not None:
    f = open(filelist, 'r')
    files += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
if len(files) == 0:
    print("No files selected for restore")
    exit(1)

files = [('/' + item).replace('\\', '/').replace(':', '').replace('//', '/') for item in files]
if restorepath is not None:
    restorepath = ('/' + restorepath).replace('\\', '/').replace(':', '').replace('//', '/')

# authenticate
apiauth(vip=vip, username=username, domain=domain)

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
    doc['versions'] = [v for v in doc['versions'] if runid == v['instanceId']['jobInstanceId']]
    if len(doc['versions']) == 0:
        print('Run ID %s not found' % runid)
        exit(1)

# select latest version
version = doc['versions'][0]

# find target

sources = []
targetId = None
targetEntity = None
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
            if 'children' in v:
                for c in v['children']:
                    if c['entity']['displayName'].lower() == targetvolume.lower():
                        targetEntity = c['entity']
                        targetId = c['entity']['id']
            if v['entity']['displayName'].lower() == targetvolume.lower():
                targetEntity = v['entity']
                targetId = v['entity']['id']
        if targetId is None:
            if targetname is not None:
                print('target volume %s not found on %s' % (targetvolume, targetname))
            else:
                print('target volume %s not found' % targetvolume)
            exit(1)
else:
    targetEntity = doc['objectId']['entity']
    targetId = doc['objectId']['entity']['id']
    if 'parentId' in targetEntity:
        targetParentSourceId = targetEntity['parentId']

restoreTaskName = "Recover-Files_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

restoreParams = {
    "filenames": files,
    "sourceObjectInfo": {
        "jobId": doc['objectId']['jobId'],
        "jobInstanceId": version['instanceId']['jobInstanceId'],
        "startTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
        "entity": doc['objectId']['entity'],
        "jobUid": doc['objectId']['jobUid']
    },
    "params": {
        "targetEntity": targetEntity,
        "targetEntityCredentials": {
            "username": "",
            "password": ""
        },
        "restoreFilesPreferences": {
            "restoreToOriginalPaths": True,
            "overrideOriginals": False,
            "preserveTimestamps": True,
            "preserveAcls": True,
            "preserveAttributes": True,
            "continueOnError": True
        }
    },
    "name": restoreTaskName
}

# restore from archival target if it's the only copy available
if version['replicaInfo']['replicaVec'][0]['target']['type'] == 3:
    restoreParams['sourceObjectInfo']['archivalTarget'] = version['replicaInfo']['replicaVec'][0]['target']['archivalTarget']

if overwrite:
    restoreParams['params']['restoreFilesPreferences']['overrideOriginals'] = True

if targetParentSourceId is not None:
    restoreParams['params']['targetEntityParentSource'] = {'id': targetParentSourceId}

# set alternate restore path
if restorepath:
    restoreParams['params']['restoreFilesPreferences']['restoreToOriginalPaths'] = False
    restoreParams['params']['restoreFilesPreferences']['alternateRestoreBaseDirectory'] = restorepath

# perform restore
print("Restoring Files...")
restoreTask = api('post', '/restoreFiles', restoreParams)

if restoreTask:
    taskId = restoreTask['restoreTask']['performRestoreTaskState']['base']['taskId']
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
