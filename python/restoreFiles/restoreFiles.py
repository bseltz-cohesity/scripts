#!/usr/bin/env python
"""restore files using python"""

# version 2024.02.14

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
parser.add_argument('-rs', '--registeredsource', type=str, default=None)   # name of registered source
parser.add_argument('-rt', '--registeredtarget', type=str, default=None)   # name of registered target
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
parser.add_argument('-z', '--sleeptimeseconds', type=str, default=30)
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
sleeptimeseconds = args.sleeptimeseconds
sourceservers = args.sourceserver

if sourceservers is None or len(sourceservers) == 0:
    print('--sourceserver is required')
    exit()

if args.targetserver is None:
    targetserver = sourceservers[0]
else:
    targetserver = args.targetserver

registeredsource = args.registeredsource
registeredtarget = args.registeredtarget
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
physicalEntities = api('get', '/entitiesOfType?environmentTypes=kFlashblade&environmentTypes=kGenericNas&environmentTypes=kGPFS&environmentTypes=kIsilon&environmentTypes=kNetapp&environmentTypes=kPhysical&flashbladeEntityTypes=kFileSystem&genericNasEntityTypes=kHost&gpfsEntityTypes=kFileset&isilonEntityTypes=kMountPoint&netappEntityTypes=kVolume&physicalEntityTypes=kHost&physicalEntityTypes=kWindowsCluster')
targetEntity = [e for e in physicalEntities if e['displayName'].lower() == targetserver.lower()]

if registeredtarget is not None:
    foundTarget = False
    targetSources = api('get', 'protectionSources/rootNodes?allUnderHierarchy=false&environments=kNetapp&environments=kIsilon&environments=kGenericNas&environments=kFlashBlade&environments=kGPFS&environments=kElastifile')
    if targetSources is not None and len(targetSources) > 0:
        targetSource = [s for s in targetSources if s['protectionSource']['name'].lower() == registeredtarget.lower()]
        if targetSource is not None and len(targetSource) > 0:
            targetEntity = [e for e in targetEntity if e['parentId'] == targetSource[0]['protectionSource']['id']]
            if targetEntity is not None and len(targetEntity) > 0:
                foundTarget = True
    if foundTarget is False:
        print('registered target %s not found' % registeredtarget)
        exit(1)

if len(targetEntity) == 0:
    print("%s not found" % targetserver)
    exit(1)

# find backups for source server
searchResults = api('get', '/searchvms?entityTypes==kFlashblade&environmentTypes=kGenericNas&environmentTypes=kGPFS&environmentTypes=kIsilon&environmentTypes=kNetapp&environmentTypes=kPhysical&flashbladeEntityTypes=kFileSystem&genericNasEntityTypes=kHost&gpfsEntityTypes=kFileset&isilonEntityTypes=kMountPoint&netappEntityTypes=kVolume&physicalEntityTypes=kHost&physicalEntityTypes=kWindowsCluster')
if searchResults:
    searchResults = [v for v in searchResults['vms'] if v['vmDocument']['objectName'].lower() in [s.lower() for s in sourceservers]]
    if jobname is not None:
        altJobName = 'old name: %s' % jobname.lower()
        altJobName2 = '%s (old name' % jobname.lower()
        searchResults = [vm for vm in searchResults if vm['vmDocument']['jobName'].lower() == jobname.lower() or altJobName in vm['vmDocument']['jobName'].lower() or altJobName2 in vm['vmDocument']['jobName'].lower()]
    if registeredsource is not None:
        searchResults = [vm for vm in searchResults if vm['registeredSource']['displayName'].lower() == registeredsource.lower()]

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
    nonwildcards = [f for f in thesefiles if f.endswith('/*') is False]
    wildcards = [f for f in thesefiles if f.endswith('/*') is True]
    if wildcards is not None and len(wildcards) > 0:
        for wildcard in wildcards:
            attemptNum = 0
            if 'attemptNum' in version['instanceId']:
                attemptNum = version['instanceId']['attemptNum']
            instance = ("attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&jobUidObjectId=%s" %
                        (attemptNum,
                            doc['objectId']['jobUid']['clusterId'],
                            doc['objectId']['jobUid']['clusterIncarnationId'],
                            doc['objectId']['entity']['id'],
                            doc['objectId']['jobId'],
                            version['instanceId']['jobInstanceId'],
                            version['instanceId']['jobStartTimeUsecs'],
                            doc['objectId']['jobUid']['objectId']))
            thisFolder = wildcard[:-2]
            cookie = None
            while True:
                if cookie is not None:
                    dirList = api('get', '/vm/directoryList?%s&useLibrarian=false&statFileEntries=false&dirPath=%s&cookie=%s' % (instance, thisFolder, cookie), quiet=True)
                else:
                    dirList = api('get', '/vm/directoryList?%s&useLibrarian=false&statFileEntries=false&dirPath=%s' % (instance, thisFolder), quiet=True)
                if dirList and 'entries' in dirList:
                    for entry in sorted(dirList['entries'], key=lambda e: e['name']):
                        nonwildcards.append(entry['fullPath'])
                if dirList and 'cookie' in dirList:
                    cookie = dirList['cookie']
                else:
                    break
    thesefiles = nonwildcards
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
            while True:
                try:
                    restoreTask = api('get', '/restoretasks/%s' % taskId)
                    if restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] in finishedStates:
                        break
                except Exception:
                    pass
                sleep(sleeptimeseconds)
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


def listdir(searchPath, dirPath, instance, volumeInfoCookie=None, volumeName=None, cookie=None, useLibrarian=False):
    global foundFile
    thisDirPath = quote_plus(dirPath).replace('%2F%2F', '%2F')
    if cookie is not None:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=false&dirPath=%s&volumeInfoCookie=%s&volumeName=%s&cookie=%s' % (instance, useLibrarian, thisDirPath, volumeInfoCookie, volumeName, cookie), quiet=True)
        else:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=false&dirPath=%s&cookie=%s' % (instance, useLibrarian, thisDirPath, cookie), quiet=True)
    else:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=false&dirPath=%s&volumeInfoCookie=%s&volumeName=%s' % (instance, useLibrarian, thisDirPath, volumeInfoCookie, volumeName), quiet=True)
        else:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=false&dirPath=%s' % (instance, useLibrarian, thisDirPath), quiet=True)
    if dirList and 'entries' in dirList:
        for entry in sorted(dirList['entries'], key=lambda e: e['name']):
            if entry['fullPath'].lower() == searchPath.lower():
                foundFile = entry['fullPath']
                break
            if entry['type'] == 'kDirectory' and entry['fullPath'].lower() in searchPath.lower():
                listdir(searchPath, '%s/%s' % (dirPath, entry['name']), instance, volumeInfoCookie, volumeName, useLibrarian=useLibrarian)
    if dirList and 'cookie' in dirList:
        listdir(searchPath, '%s' % dirPath, instance, volumeInfoCookie, volumeName, dirList['cookie'], useLibrarian=useLibrarian)


if independentRestores is False:
    restore(files, doc, version, targetEntity, False)
else:
    unindexedSnapshots = [s for s in versions if 'numEntriesIndexed' not in s or s['numEntriesIndexed'] == 0 or 'indexingStatus' not in s or s['indexingStatus'] != 2]
    if noindex or (unindexedSnapshots is not None and len(unindexedSnapshots) > 0):
        print('Crawling for files...')
    for file in files:
        origFile = file
        restoreChildren = False
        if file.endswith('/*'):
            restoreChildren = True
            file = file[:-2]
        encodedFile = quote_plus(file)
        fileRestored = False
        if noindex or (unindexedSnapshots is not None and len(unindexedSnapshots) > 0):
            foundFile = None
            for version in versions:

                useLibrarian = False
                if sorted(version['replicaInfo']['replicaVec'], key=lambda replica: replica['target']['type'])[0]['target']['type'] == 3:
                    useLibrarian = True

                if foundFile is None:
                    attemptNum = 0
                    if 'attemptNum' in version['instanceId']:
                        attemptNum = version['instanceId']['attemptNum']
                    instance = ("attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&jobUidObjectId=%s" %
                                (attemptNum,
                                    doc['objectId']['jobUid']['clusterId'],
                                    doc['objectId']['jobUid']['clusterIncarnationId'],
                                    doc['objectId']['entity']['id'],
                                    doc['objectId']['jobId'],
                                    version['instanceId']['jobInstanceId'],
                                    version['instanceId']['jobStartTimeUsecs'],
                                    doc['objectId']['jobUid']['objectId']))
                    # perform quick case sensitive exact match
                    thisFile = api('get', '/vm/directoryList?%s&statFileEntries=false&useLibrarian=%s&dirPath=%s' % (instance, useLibrarian, encodedFile), quiet=True)
                    if thisFile is not None and thisFile != "error":
                        foundFile = file
                    if foundFile is None:
                        # perform recursive directory walk (deep search)
                        backupType = doc['backupType']
                        if backupType in volumeTypes:
                            volumeList = api('get', '/vm/volumeInfo?%s&statFileEntries=false' % instance, quiet=True)
                            if 'volumeInfos' in volumeList:
                                volumeInfoCookie = volumeList['volumeInfoCookie']
                                for volume in sorted(volumeList['volumeInfos'], key=lambda v: v['name']):
                                    volumeName = quote_plus(volume['name'])
                                    listdir(file, '/', instance, volumeInfoCookie, volumeName, useLibrarian=useLibrarian)
                        else:
                            listdir(file, '/', instance, useLibrarian=useLibrarian)
                if foundFile is not None:
                    if restoreChildren is True:
                        foundFile = foundFile + '/*'
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
                            if restoreChildren is True:
                                file = file + '/*'
                            restore(file, doc, version, targetEntity, True)
