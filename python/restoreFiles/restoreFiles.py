#!/usr/bin/env python
"""restore files using python"""

# version 2020.07.21

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
from urllib import quote_plus
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
parser.add_argument('-f', '--filelist', type=str, default=None)       # text file list of files to restore
parser.add_argument('-p', '--restorepath', type=str, default=None)    # destination path
parser.add_argument('-r', '--runid', type=int, default=None)          # job run id to restore from
parser.add_argument('-b', '--start', type=str, default=None)          # show snapshots after date
parser.add_argument('-e', '--end', type=str, default=None)            # show snapshots before date
parser.add_argument('-o', '--newonly', action='store_true')           # abort if PIT is not new
parser.add_argument('-l', '--latest', action='store_true')            # only use latest version
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
runid = args.runid
start = args.start
end = args.end
latest = args.latest
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

independentRestores = True
if runid is not None:
    independentRestores = False
    versions = [v for v in doc['versions'] if runid == v['instanceId']['jobInstanceId']]
    if versions:
        version = versions[0]
    else:
        print("Job run %s not found" % runid)
        exit(1)
else:
    versions = doc['versions']
    if start is not None:
        startusecs = dateToUsecs(start)
        versions = [v for v in doc['versions'] if startusecs <= v['snapshotTimestampUsecs']]
    if end is not None:
        endusecs = dateToUsecs(end)
        versions = [v for v in doc['versions'] if endusecs >= v['snapshotTimestampUsecs']]
    if len(versions) == 0:
        print('No versions available for %s' % sourceserver)
    else:
        if latest:
            independentRestores = False
        version = versions[0]

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


def restore(thesefiles, doc, version, targetEntity, singleFile):
    restoreTaskName = "Recover-Files_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    if singleFile is True:
        shortfile = thesefiles.split('/')[-1]
        restoreTaskName = "Recover-Files_%s_%s" % (datetime.now().strftime("%Y-%m-%d_%H-%M-%S"), shortfile)
        thesefiles = [thesefiles]

    restoreParams = {
        "filenames": thesefiles,
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
    if singleFile is True:
        print('Restoring %s' % file)
    else:
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
                if singleFile is False:
                    exit(0)
            else:
                if 'error' in restoreTask[0]['restoreTask']['performRestoreTaskState']['base']:
                    errorMsg = restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['error']['errorMsg']
                else:
                    errorMsg = ''
                print("Restore finished with status %s" % restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
                print(errorMsg)
                if singleFile is False:
                    exit(1)
        else:
            if newonly:
                f = open('lastrestorepoint', 'w')
                f.write('%s' % version['instanceId']['jobStartTimeUsecs'])
                f.close()
            if singleFile is False:
                exit(0)
    else:
        if singleFile is False:
            exit(1)


if independentRestores is False:
    restore(files, doc, version, targetEntity, False)
else:
    for file in files:
        encodedFile = quote_plus(file)
        fileSearch = api('get', '/searchfiles?filename=%s' % encodedFile)
        if 'files' not in fileSearch:
            print("file %s not found" % file)
        else:
            fileSearch['files'] = [n for n in fileSearch['files'] if n['fileDocument']['objectId']['entity']['displayName'].lower() == sourceserver and n['fileDocument']['filename'].lower() == file.lower()]
            if len(fileSearch['files']) == 0:
                print("file %s not found on server %s" % (file, sourceserver))
            else:
                if jobname is not None:
                    fileSearch['files'] = [n for n in fileSearch['files'] if doc['objectId']['jobId'] == n['fileDocument']['objectId']['jobId']]
                if len(fileSearch['files']) == 0:
                    print("file %s not found on server %s protected by %s" % (file, sourceserver, jobname))
                else:
                    doc = fileSearch['files'][0]['fileDocument']
                    versions = api('get', '/file/versions?clusterId=%s&clusterIncarnationId=%s&entityId=%s&filename=%s&fromObjectSnapshotsOnly=false&jobId=%s' % (doc['objectId']['jobUid']['clusterId'], doc['objectId']['jobUid']['clusterIncarnationId'], doc['objectId']['entity']['id'], encodedFile, doc['objectId']['jobId']))
                    if start is not None:
                        startusecs = dateToUsecs(start)
                        versions['versions'] = [v for v in versions['versions'] if startusecs <= v['instanceId']['jobStartTimeUsecs']]
                    if end is not None:
                        endusecs = dateToUsecs(end)
                        versions['versions'] = [v for v in versions['versions'] if endusecs >= v['instanceId']['jobStartTimeUsecs']]
                    if 'versions' not in versions or versions['versions'] == 0:
                        print('no versions available for %s' % file)
                    else:
                        version = versions['versions'][0]
                        restore(file, doc, version, targetEntity, True)
