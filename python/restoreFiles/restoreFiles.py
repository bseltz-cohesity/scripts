#!/usr/bin/env python
"""restore files using python"""

# version 2023.09.07

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
from sys import exit
import sys
import argparse
try:
    from urllib.parse import quote_plus
except Exception:
    from urllib import quote_plus

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')  # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # username
parser.add_argument('-d', '--domain', type=str, default='local')      # domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')         # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)       # optional password
parser.add_argument('-c', '--clustername', type=str, default=None)   # name of helios cluster to connect to
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-s', '--sourceserver', type=str, action='append')  # name of source server
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
parser.add_argument('-k', '--taskname', type=str, default=None)       # recoverytask name
parser.add_argument('-x', '--noindex', action='store_true')           # force no index usage
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
clustername = args.clustername
mcm = args.mcm
noprompt = args.noprompt
mfacode = args.mfacode
sourceservers = args.sourceserver

if sourceservers is None or len(sourceservers) == 0:
    print('--sourceserver is required')
    exit()

if args.targetserver is None:
    targetserver = sourceservers[0]
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
taskname = args.taskname
noindex = args.noindex

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

files = [('/' + item).replace(':\\', '/').replace('\\', '/').replace('//', '/') for item in files]
if restorepath is not None:
    restorepath = ('/' + restorepath).replace(':\\', '/').replace('\\', '/').replace('//', '/')

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# find target server
physicalEntities = api('get', '/entitiesOfType?environmentTypes=kPhysical&physicalEntityTypes=kHost&physicalEntityTypes=kOracleAPCluster')
targetEntity = [e for e in physicalEntities if e['displayName'].lower() == targetserver.lower()]

if len(targetEntity) == 0:
    print("%s not found" % targetserver)
    exit(1)

# find backups for source server
searchResults = api('get', '/searchvms?entityTypes=kPhysical')
if searchResults:
    searchResults = [v for v in searchResults['vms'] if v['vmDocument']['objectName'].lower() in [s.lower() for s in sourceservers]]
    if jobname is not None:
        altJobName = 'old name: %s' % jobname.lower()
        altJobName2 = '%s (old name' % jobname.lower()
        searchResults = [vm for vm in searchResults if vm['vmDocument']['jobName'].lower() == jobname.lower() or altJobName in vm['vmDocument']['jobName'].lower() or altJobName2 in vm['vmDocument']['jobName'].lower()]

if len(searchResults) == 0:
    if jobname is not None:
        print("sourceservers are not protected by %s" % jobname)
    else:
        print("sourceservers are not protected")
    exit(1)

# find newest among multiple jobs
searchResult = sorted(searchResults, key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]

doc = searchResult['vmDocument']
# new
sourceEntity = doc['objectId']['entity']
volumeTypes = [1, 6]

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
        print('No versions available for sourceservers')
    else:
        if latest:
            independentRestores = False
        version = versions[0]

if newonly:
    # get last restore date from tracking file
    try:
        f = open('lastrestorepoint', 'r')
        lastrestorepoint = long(f.read())
    except Exception:
        lastrestorepoint = 0
    if version['instanceId']['jobStartTimeUsecs'] > lastrestorepoint:
        print('found newer version to restore')
    else:
        print('no new versions found')
        exit(1)


def restore(thesefiles, doc, version, targetEntity, singleFile):
    if taskname is not None:
        restoreTaskName = taskname
    else:
        restoreTaskName = "Recover-Files_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    if singleFile is True:
        fileparts = [p for p in thesefiles.split('/') if p is not None and p != '']
        shortfile = fileparts[-1]
        if taskname is None:
            restoreTaskName = "%s_%s" % (restoreTaskName, shortfile)
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

    # select local or cloud archive copy
    fromTarget = '(local)'
    if sorted(version['replicaInfo']['replicaVec'], key=lambda replica: replica['target']['type'])[0]['target']['type'] == 3:
        fromTarget = '(archive)'
        restoreParams['sourceObjectInfo']['archivalTarget'] = version['replicaInfo']['replicaVec'][0]['target']['archivalTarget']

    # perform restore
    if singleFile is True:
        print('Restoring %s from %s %s' % (file, usecsToDate(version['instanceId']['jobStartTimeUsecs']), fromTarget))
    else:
        print('Restoring Files from %s %s' % (usecsToDate(version['instanceId']['jobStartTimeUsecs']), fromTarget))
    restoreTask = api('post', '/restoreFiles', restoreParams)

    if restoreTask:
        taskId = restoreTask['restoreTask']['performRestoreTaskState']['base']['taskId']
        if wait:
            finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning']
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


def listdir(searchPath, dirPath, instance, volumeInfoCookie=None, volumeName=None, cookie=None):
    global foundFile
    thisDirPath = quote_plus(dirPath).replace('%2F%2F', '%2F')
    if cookie is not None:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=false&statFileEntries=false&dirPath=%s&volumeInfoCookie=%s&volumeName=%s&cookie=%s' % (instance, thisDirPath, volumeInfoCookie, volumeName, cookie))
        else:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=false&statFileEntries=false&dirPath=%s&cookie=%s' % (instance, thisDirPath, cookie))
    else:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=false&statFileEntries=false&dirPath=%s&volumeInfoCookie=%s&volumeName=%s' % (instance, thisDirPath, volumeInfoCookie, volumeName))
        else:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=false&statFileEntries=false&dirPath=%s' % (instance, thisDirPath))
    if dirList and 'entries' in dirList:
        for entry in sorted(dirList['entries'], key=lambda e: e['name']):
            if entry['fullPath'].lower() == searchPath.lower():
                foundFile = entry['fullPath']
                break
            if entry['type'] == 'kDirectory' and entry['fullPath'].lower() in searchPath.lower():
                listdir(searchPath, '%s/%s' % (dirPath, entry['name']), instance, volumeInfoCookie, volumeName)
    if dirList and 'cookie' in dirList:
        listdir(searchPath, '%s' % dirPath, instance, volumeInfoCookie, volumeName, dirList['cookie'])


if independentRestores is False:
    restore(files, doc, version, targetEntity, False)
else:
    unindexedSnapshots = [s for s in doc['versions'] if 'numEntriesIndexed' not in s or s['numEntriesIndexed'] == 0 or 'indexingStatus' not in s or s['indexingStatus'] != 2]
    if noindex or (unindexedSnapshots is not None and len(unindexedSnapshots) > 0):
        print('Crawling for files...')
    for file in files:
        encodedFile = quote_plus(file)
        fileRestored = False
        if noindex or (unindexedSnapshots is not None and len(unindexedSnapshots) > 0):
            foundFile = None
            for version in doc['versions']:
                if foundFile is None:
                    instance = ("attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&jobUidObjectId=%s" %
                                (version['instanceId']['attemptNum'],
                                    doc['objectId']['jobUid']['clusterId'],
                                    doc['objectId']['jobUid']['clusterIncarnationId'],
                                    doc['objectId']['entity']['id'],
                                    doc['objectId']['jobId'],
                                    version['instanceId']['jobInstanceId'],
                                    version['instanceId']['jobStartTimeUsecs'],
                                    doc['objectId']['jobUid']['objectId']))
                    # perform quick case sensitive exact match
                    thisFile = api('get', '/vm/directoryList?%s&statFileEntries=false&dirPath=%s' % (instance, encodedFile), quiet=True)
                    if thisFile is not None and thisFile != "error":
                        foundFile = file
                    if foundFile is None:
                        # perform recursive directory walk (deep search)
                        backupType = doc['backupType']
                        if backupType in volumeTypes:
                            volumeList = api('get', '/vm/volumeInfo?%s&statFileEntries=false' % instance)
                            if 'volumeInfos' in volumeList:
                                volumeInfoCookie = volumeList['volumeInfoCookie']
                                for volume in sorted(volumeList['volumeInfos'], key=lambda v: v['name']):
                                    volumeName = quote_plus(volume['name'])
                                    listdir(file, '/', instance, volumeInfoCookie, volumeName)
                        else:
                            listdir(file, '/', instance)
                if foundFile is not None:
                    restore(foundFile, doc, version, targetEntity, True)
                    fileRestored = True
                    break
            if foundFile is None:
                print('%s not found on sourceservers (or not available in the specified versions)' % file)
        else:
            fileSearch = api('get', '/searchfiles?filename=%s' % encodedFile)
            if 'files' not in fileSearch:
                print("file %s not found" % file)
            else:
                fileSearch['files'] = [n for n in fileSearch['files'] if n['fileDocument']['objectId']['entity']['displayName'].lower() in [s.lower() for s in sourceservers] and n['fileDocument']['filename'].lower() == file.lower()]
                if len(fileSearch['files']) == 0:
                    print("file %s not found on sourceservers" % file)
                else:
                    if jobname is not None:
                        fileSearch['files'] = [n for n in fileSearch['files'] if doc['objectId']['jobId'] == n['fileDocument']['objectId']['jobId']]
                    if len(fileSearch['files']) == 0:
                        print("file %s not found on sourceservers protected by %s" % (file, jobname))
                    else:
                        filedoc = fileSearch['files'][0]['fileDocument']
                        encodedFile = quote_plus(filedoc['filename'])
                        versions = api('get', '/file/versions?clusterId=%s&clusterIncarnationId=%s&entityId=%s&filename=%s&fromObjectSnapshotsOnly=false&jobId=%s' % (doc['objectId']['jobUid']['clusterId'], doc['objectId']['jobUid']['clusterIncarnationId'], doc['objectId']['entity']['id'], encodedFile, doc['objectId']['jobUid']['objectId']))
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
