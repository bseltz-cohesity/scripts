#!/usr/bin/env python
"""backed up files list for python"""

# version 2025.01.23

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from sys import exit
import codecs
import argparse

try:
    from urllib.parse import quote_plus
except Exception:
    from urllib import quote_plus

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-s', '--sourceserver', type=str, required=True)  # name of source server
parser.add_argument('-j', '--jobname', type=str, required=True)       # narrow search by job name
parser.add_argument('-l', '--showversions', action='store_true')      # show available snapshots
parser.add_argument('-k', '--listfiles', action='store_true')         # show fils in snapshots
parser.add_argument('-t', '--start', type=str, default=None)          # show snapshots after date
parser.add_argument('-e', '--end', type=str, default=None)            # show snapshots before date
parser.add_argument('-r', '--runid', type=int, default=None)          # choose specific job run id
parser.add_argument('-f', '--filedate', type=str, default=None)       # show snapshots after date
parser.add_argument('-p', '--startpath', type=str, default='/')       # show files under this path
parser.add_argument('-n', '--noindex', action='store_true')           # do not use librarian
parser.add_argument('-x', '--forceindex', action='store_true')           # do not use librarian
parser.add_argument('-nt', '--newerthan', type=int, default=0)        # show files newer than X days
parser.add_argument('-ext', '--extension', type=str, default=None)
parser.add_argument('-f2', '--format2', action='store_true')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
sourceserver = args.sourceserver
jobname = args.jobname
showversions = args.showversions
start = args.start
end = args.end
runid = args.runid
filedate = args.filedate
listfiles = args.listfiles
startpath = args.startpath
noindex = args.noindex
showstats = True  # args.showstats
newerthan = args.newerthan
forceIndex = args.forceindex
extension = args.extension
format2 = args.format2

responseJSON = {'error':'', 'files': [], 'fileCount': 0, 'totalBytes': 0}
if format2 is True:
    responseJSON = {'status': 'success', 'file_list': [], 'source_server': sourceserver}

if showversions is True:
    responseJSON = {'error':'', 'versions': []}

def listdir(dirPath, instance, sourceserver, thisrunid, volumeInfoCookie=None, volumeName=None, cookie=None):
    global responseJSON
    thisDirPath = quote_plus(dirPath).replace('%2F%2F', '%2F')
    if cookie is not None:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s%s&statFileEntries=%s&dirPath=%s&volumeInfoCookie=%s&volumeName=%s&cookie=%s' % (instance, useLibrarian, statfile, thisDirPath, volumeInfoCookie, volumeName, cookie))
        else:
            dirList = api('get', '/vm/directoryList?%s%s&statFileEntries=%s&dirPath=%s&cookie=%s' % (instance, useLibrarian, statfile, thisDirPath, cookie))
    else:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s%s&statFileEntries=%s&dirPath=%s&volumeInfoCookie=%s&volumeName=%s' % (instance, useLibrarian, statfile, thisDirPath, volumeInfoCookie, volumeName))
        else:
            dirList = api('get', '/vm/directoryList?%s%s&statFileEntries=%s&dirPath=%s' % (instance, useLibrarian, statfile, thisDirPath))
    if dirList and 'entries' in dirList:
        for entry in sorted(dirList['entries'], key=lambda e: e['name']):
            try:
                if entry['type'] == 'kDirectory':
                    listdir('%s/%s' % (dirPath, entry['name']), instance, sourceserver, thisrunid, volumeInfoCookie, volumeName)
                else:
                    if extension is None or entry['fullPath'].lower().endswith(extension):
                        if statfile is True:
                            filesize = entry['fstatInfo']['size']
                            mtime = usecsToDate(entry['fstatInfo']['mtimeUsecs'])
                            mtimeusecs = entry['fstatInfo']['mtimeUsecs']
                            if newerthan == 0 or mtimeusecs > timeAgo(newerthan, 'days'):
                                if format2 is True:
                                    responseJSON['file_list'].append(entry['fullPath'])
                                else:                         
                                    responseJSON['fileCount'] += 1
                                    responseJSON['totalBytes'] += filesize
                                    responseJSON['files'].append({
                                        'sourceServer': sourceserver,
                                        'fullPath': entry['fullPath'],
                                        'mtime': mtime,
                                        'bytes': filesize,
                                        'runId': thisrunid
                                })
            except Exception:
                pass
    if dirList and 'cookie' in dirList:
        listdir('%s' % dirPath, instance, sourceserver, thisrunid, volumeInfoCookie, volumeName, dirList['cookie'])

def showFiles(doc, version):
    global useLibrarian

    if 'numEntriesIndexed' not in version or version['numEntriesIndexed'] == 0:
        useLibrarian = ''  # False
    else:
        if 'indexingStatus' not in version or version['indexingStatus'] != 2:
            useLibrarian = ''  # False
        else:
            useLibrarian = '&useLibrarian=true'
    if forceIndex and 'indexingStatus' in version and version['indexingStatus'] == 2:
        useLibrarian = '&useLibrarian=true'
    if noindex:
        useLibrarian = ''  # False
    if 'attemptNum' in version['instanceId']:
        attemptNum = version['instanceId']['attemptNum']
    else:
        attemptNum = 0
    thisrunid = version['instanceId']['jobInstanceId']
    instance = ("attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&jobUidObjectId=%s" %
                (attemptNum,
                    doc['objectId']['jobUid']['clusterId'],
                    doc['objectId']['jobUid']['clusterIncarnationId'],
                    doc['objectId']['entity']['id'],
                    doc['objectId']['jobId'],
                    version['instanceId']['jobInstanceId'],
                    version['instanceId']['jobStartTimeUsecs'],
                    doc['objectId']['jobUid']['objectId']))

    volumeTypes = [1, 6]
    backupType = doc['backupType']
    if backupType in volumeTypes:
        volumeList = api('get', '/vm/volumeInfo?%s&statFileEntries=%s' % (instance, statfile))
        if 'volumeInfos' in volumeList:
            volumeInfoCookie = volumeList['volumeInfoCookie']
            for volume in sorted(volumeList['volumeInfos'], key=lambda v: v['name']):
                volumeName = quote_plus(volume['name'])
                listdir(startpath, instance, sourceserver, thisrunid, volumeInfoCookie, volumeName)
    else:
        listdir(startpath, instance, sourceserver, thisrunid)

if showstats is True or newerthan > 0:
    statfile = True
else:
    statfile = False

useLibrarian = '&useLibrarian=true'  # True

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, quiet=True)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        responseJSON['error'] = ('-clustername is required when connecting to Helios or MCM')
        if format2 is True:
            responseJSON['status'] = 'failed'
        display(responseJSON)
        exit(1)

# exit if not authenticated
if apiconnected() is False:
    responseJSON['error'] = ('authentication failed')
    if format2 is True:
        responseJSON['status'] = 'failed'
    display(responseJSON)
    exit(1)

search = api('get', '/searchvms?entityTypes=kView&entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAWSSnapshotManager&entityTypes=kAzure&entityTypes=kAzureNative&entityTypes=kFlashBlade&entityTypes=kGCP&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware&vmName=%s' % sourceserver)

if 'vms' not in search:
    responseJSON['error'] = ('no backups found for %s' % sourceserver)
    if format2 is True:
        responseJSON['status'] = 'failed'
    display(responseJSON)
    exit(1)

searchResults = [vm for vm in search['vms'] if vm['vmDocument']['objectName'].lower() == sourceserver.lower()]

if len(searchResults) == 0:
    responseJSON['error'] = ('no backups found for %s' % sourceserver)
    if format2 is True:
        responseJSON['status'] = 'failed'
    display(responseJSON)
    exit(1)

altJobName = 'old name: %s' % jobname.lower()
altJobName2 = '%s (old name' % jobname.lower()
searchResults = [vm for vm in searchResults if vm['vmDocument']['jobName'].lower() == jobname.lower() or altJobName in vm['vmDocument']['jobName'].lower() or altJobName2 in vm['vmDocument']['jobName'].lower()]

if len(searchResults) == 0:
    responseJSON['error'] = ('%s not protected by %s' % (sourceserver, jobname))
    if format2 is True:
        responseJSON['status'] = 'failed'
    display(responseJSON)
    exit(1)

searchResults = [r for r in searchResults if 'versions' in r['vmDocument'] and len(r['vmDocument']['versions']) > 0]

if len(searchResults) == 0:
    responseJSON['error'] = ('No backups available for %s in %s' % (sourceserver, jobname))
    if format2 is True:
        responseJSON['status'] = 'failed'
    display(responseJSON)
    exit(1)

allVersions = []
for searchResult in searchResults:
    for version in searchResult['vmDocument']['versions']:
        version['doc'] = searchResult['vmDocument']
        allVersions.append(version)
allVersions = sorted(allVersions, key=lambda r: r['snapshotTimestampUsecs'], reverse=True)

if showversions or start is not None or end is not None or listfiles:
    if start is not None:
        startusecs = dateToUsecs(start)
        allVersions = [v for v in allVersions if startusecs <= v['snapshotTimestampUsecs']]
    if end is not None:
        endusecs = dateToUsecs(end)
        allVersions = [v for v in allVersions if endusecs >= v['snapshotTimestampUsecs']]
    if listfiles:
        for version in allVersions:
            showFiles(version['doc'], version)
    else:
        for version in allVersions:
            responseJSON['versions'].append({
                'runId': version['instanceId']['jobInstanceId'],
                'startTime': usecsToDate(version['instanceId']['jobStartTimeUsecs'])
            })
    exit()

# select version
if runid is not None:
    # select version with matching runId
    versions = [v for v in allVersions if runid == v['instanceId']['jobInstanceId']]
    if len(versions) == 0:
        responseJSON['error'] = ('Run ID not found')
        if format2 is True:
            responseJSON['status'] = 'failed'
        display(responseJSON)
        exit(1)
    else:
        version = versions[0]
        showFiles(version['doc'], version)
elif filedate is not None:
    # select version just after requested date
    filedateusecs = dateToUsecs(filedate)
    versions = [v for v in allVersions if filedateusecs <= v['snapshotTimestampUsecs']]
    if versions:
        version = versions[-1]
        showFiles(version['doc'], version)
    else:
        responseJSON['error'] = ('No backups from the specified date')
        if format2 is True:
            responseJSON['status'] = 'failed'
        display(responseJSON)
        exit(1)
else:
    # just use latest version
    version = allVersions[0]
    showFiles(version['doc'], version)

display(responseJSON)