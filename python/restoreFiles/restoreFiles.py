#!/usr/bin/env python
"""restore files using python"""

# version 2020.07.18
# 2020.07.18 fixed newonly for python3, added runid parameter

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
import sys

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # username
parser.add_argument('-d', '--domain', type=str, default='local')      # domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')         # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)       # optional password
parser.add_argument('-s', '--sourceserver', type=str, required=True)  # name of source server
parser.add_argument('-t', '--targetserver', type=str, default=None)   # name of target server
parser.add_argument('-j', '--jobname', type=str, default=None)        # narrow search by job name
parser.add_argument('-n', '--filename', type=str, action='append')    # file name to restore
parser.add_argument('-l', '--filelist', type=str, default=None)       # text file list of files to restore
parser.add_argument('-p', '--restorepath', type=str, default=None)    # destination path
parser.add_argument('-r', '--runid', type=int, default=None)          # job run id to restore from
parser.add_argument('-f', '--filedate', type=str, default=None)       # date to restore from
parser.add_argument('-o', '--newonly', action='store_true')           # abort if PIT is not new
parser.add_argument('-w', '--wait', action='store_true')              # wait for completion and report result

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
sourceserver = args.sourceserver

if args.targetserver is None:
    targetserver = sourceserver
else:
    targetserver = args.targetserver

jobname = args.jobname
files = args.filename
filelist = args.filelist
restorepath = args.restorepath
filedate = args.filedate
runid = args.runid
newonly = args.newonly
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
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# find target server
physicalEntities = api('get', '/entitiesOfType?environmentTypes=kPhysical&physicalEntityTypes=kHost')
targetEntity = [e for e in physicalEntities if e['displayName'].lower() == targetserver.lower()]

if len(targetEntity) == 0:
    print("%s not found" % targetserver)
    exit(1)

# find backups for source server
searchResults = api('get', '/searchvms?entityTypes=kPhysical&vmName=%s' % sourceserver)
if searchResults:
    searchResults = [v for v in searchResults['vms'] if v['vmDocument']['objectName'].lower() == sourceserver.lower()]
    if jobname is not None:
        searchResults = [v for v in searchResults if v['vmDocument']['jobName'].lower() == jobname.lower()]

if len(searchResults) == 0:
    if jobname is not None:
        print("%s is not protected by %s" % (sourceserver, jobname))
    else:
        print("%s is not protected" % sourceserver)
    exit(1)

# find newest among multiple jobs
searchResult = sorted(searchResults, key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]

doc = searchResult['vmDocument']

if runid is not None:
    versions = [v for v in doc['versions'] if runid == v['instanceId']['jobInstanceId']]
    if versions:
        version = versions[0]
    else:
        print("Job run %s not found" % runid)
        exit(1)
elif filedate is not None:
    filedateusecs = dateToUsecs(filedate)
    versions = [v for v in doc['versions'] if filedateusecs <= v['snapshotTimestampUsecs']]
    if versions:
        version = versions[-1]
    else:
        print('No backups from the specified date')
        exit(1)
else:
    version = doc['versions'][0]

if newonly:
    # get last restore date from tracking file
    try:
        f = open('lastrestorepoint', 'r')
        lastrestorepoint = long(f.read())
    except Exception as e:
        lastrestorepoint = 0
    if version['instanceId']['jobStartTimeUsecs'] > lastrestorepoint:
        print('found newer version to restore')
    else:
        print('no new versions found')
        exit(1)

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
            if newonly:
                f = open('lastrestorepoint', 'w')
                f.write('%s' % version['instanceId']['jobStartTimeUsecs'])
                f.close()
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
        if newonly:
            f = open('lastrestorepoint', 'w')
            f.write('%s' % version['instanceId']['jobStartTimeUsecs'])
            f.close()
        exit(0)
else:
    exit(1)
