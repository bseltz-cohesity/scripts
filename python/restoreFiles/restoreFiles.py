#!/usr/bin/env python
"""restore files using python"""

# usage: ./restoreFiles.py -v mycluster \
#                          -u myusername \
#                          -d mydomain .net \
#                          -s server1.mydomain.net \
#                          -t server2.mydomain.net \
#                          -n /home/myusername/file1 \
#                          -n /home/myusername/file2 \
#                          -p /tmp/restoretest/ \
#                          -f '2020-04-18 18:00:00' \
#                          -w

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-s', '--sourceserver', type=str, required=True)   # name of source server
parser.add_argument('-t', '--targetserver', type=str, default=None)    # name of target server
parser.add_argument('-n', '--filename', type=str, action='append')
parser.add_argument('-l', '--filelist', type=str, default=None)
parser.add_argument('-p', '--restorepath', type=str, default=None)  # destination path
parser.add_argument('-f', '--filedate', type=str, default=None)
parser.add_argument('-w', '--wait', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
sourceserver = args.sourceserver

if args.targetserver is None:
    targetserver = sourceserver
else:
    targetserver = args.targetserver

files = args.filename
filelist = args.filelist
restorepath = args.restorepath
filedate = args.filedate
wait = args.wait

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
apiauth(vip, username, domain)

# find source and target servers
physicalEntities = api('get', '/entitiesOfType?environmentTypes=kPhysical&physicalEntityTypes=kHost')
sourceEntity = [e for e in physicalEntities if e['displayName'].lower() == sourceserver.lower()]
targetEntity = [e for e in physicalEntities if e['displayName'].lower() == targetserver.lower()]

if len(sourceEntity) == 0:
    print("%s not found" % sourceserver)
    exit(1)

if len(targetEntity) == 0:
    print("%s not found" % targetserver)
    exit(1)

# find backups for source server
searchResults = api('get', '/searchvms?entityTypes=kPhysical&vmName=%s' % sourceserver)
if searchResults:
    searchResults = [v for v in searchResults['vms'] if v['vmDocument']['objectName'].lower() == sourceserver.lower()]

if len(searchResults) == 0:
    print("%s is not protected" % sourceserver)
    exit(1)

# find newest among multiple jobs
searchResult = sorted(searchResults, key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]

doc = searchResult['vmDocument']

if filedate is not None:
    filedateusecs = dateToUsecs(filedate)
    versions = [v for v in doc['versions'] if filedateusecs <= v['snapshotTimestampUsecs']]
    if versions:
        version = versions[-1]
    else:
        print('No backups from the specified date')
        exit(1)
else:
    version = doc['versions'][0]

restoreTaskName = "Recover-Files_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

restoreParams = {
    "filenames": files,
    "sourceObjectInfo": {
        "jobId": doc['objectId']['jobId'],
        "jobInstanceId": version['instanceId']['jobInstanceId'],
        "startTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
        "entity": sourceEntity[0],
        "jobUid": doc['objectId']['jobUid']
    },
    "params": {
        "targetEntity": targetEntity[0],
        "targetEntityCredentials": {
            "username": "",
            "password": ""
        },
        "restoreFilesPreferences": {
            "restoreToOriginalPaths": True,
            "overrideOriginals": True,
            "preserveTimestamps": True,
            "preserveAcls": True,
            "preserveAttributes": True,
            "continueOnError": True
        }
    },
    "name": restoreTaskName
}

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
        finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
        restoreTask = api('get', '/restoretasks/%s' % taskId)
        while restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates:
            sleep(3)
            restoreTask = api('get', '/restoretasks/%s' % taskId)
        if restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess':
            print("Restore finished with status %s" % restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
            exit(0)
        else:
            if 'error' in restoreTask[0]['restoreTask']['performRestoreTaskState']['base']:
                errorMsg = restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['error']['errorMsg']
            else:
                errorMsg = ''
            print("Restore finished with status %s" % restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
            print(errorMsg)
            exit(1)
    else:
        exit(0)
else:
    exit(1)
