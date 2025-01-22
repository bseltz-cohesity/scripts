#!/usr/bin/env python
"""backed up files list for python"""

# version 2025.01.22

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
parser.add_argument('-s', '--sourceserver', type=str, action='append')  # name of source server
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
parser.add_argument('-ss', '--showstats', action='store_true')        # show file last modified date and size
parser.add_argument('-nt', '--newerthan', type=int, default=0)        # show files newer than X days

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
sourceservers = args.sourceserver
jobname = args.jobname
showversions = args.showversions
start = args.start
end = args.end
runid = args.runid
filedate = args.filedate
listfiles = args.listfiles
startpath = args.startpath
noindex = args.noindex
showstats = args.showstats
newerthan = args.newerthan
forceIndex = args.forceindex


def listdir(dirPath, instance, f, csv, volumeInfoCookie=None, volumeName=None, cookie=None):
    global fileCount
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
                    listdir('%s/%s' % (dirPath, entry['name']), instance, f, csv, volumeInfoCookie, volumeName)
                else:
                    # entry['fullPath'] = entry['fullPath'].encode('ascii', 'replace').decode('ascii')
                    if statfile is True:
                        filesize = entry['fstatInfo']['size']
                        mtime = usecsToDate(entry['fstatInfo']['mtimeUsecs'])
                        mtimeusecs = entry['fstatInfo']['mtimeUsecs']
                        if newerthan == 0 or mtimeusecs > timeAgo(newerthan, 'days'):
                            fileCount += 1
                            print('%s (%s) [%s bytes]' % (entry['fullPath'], mtime, filesize))
                            f.write('%s (%s) [%s bytes]\n' % (entry['fullPath'], mtime, filesize))
                            csv.write('"%s","%s","%s"\n' % (entry['fullPath'], mtime, filesize))
                    else:
                        fileCount += 1
                        print('%s' % entry['fullPath'])
                        f.write('%s\n' % entry['fullPath'])
                        csv.write('"%s","",""\n' % entry['fullPath'])
            except Exception:
                pass
    if dirList and 'cookie' in dirList:
        listdir('%s' % dirPath, instance, f, csv, volumeInfoCookie, volumeName, dirList['cookie'])


def showFiles(doc, version):
    global useLibrarian
    global fileCount
    filecount = 0

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
    instance = ("attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&jobUidObjectId=%s" %
                (attemptNum,
                    doc['objectId']['jobUid']['clusterId'],
                    doc['objectId']['jobUid']['clusterIncarnationId'],
                    doc['objectId']['entity']['id'],
                    doc['objectId']['jobId'],
                    version['instanceId']['jobInstanceId'],
                    version['instanceId']['jobStartTimeUsecs'],
                    doc['objectId']['jobUid']['objectId']))

    fileDateString = datetime.strptime(usecsToDate(version['instanceId']['jobStartTimeUsecs']), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d_%H-%M-%S')

    fsourceserver = sourceserver.replace('/', '-').replace('\\', '-')
    f = codecs.open('backedUpFiles-%s-%s-%s.txt' % (fsourceserver, version['instanceId']['jobInstanceId'], fileDateString), 'w', 'utf-8')
    csv = codecs.open('backedUpFiles-%s-%s-%s.csv' % (fsourceserver, version['instanceId']['jobInstanceId'], fileDateString), 'w', 'utf-8')
    csv.write('"Path","Last Modified","Bytes"\n')
    volumeTypes = [1, 6]
    backupType = doc['backupType']
    if backupType in volumeTypes:
        volumeList = api('get', '/vm/volumeInfo?%s&statFileEntries=%s' % (instance, statfile))
        if 'volumeInfos' in volumeList:
            volumeInfoCookie = volumeList['volumeInfoCookie']
            for volume in sorted(volumeList['volumeInfos'], key=lambda v: v['name']):
                volumeName = quote_plus(volume['name'])
                listdir(startpath, instance, f, csv, volumeInfoCookie, volumeName)
    else:
        listdir(startpath, instance, f, csv)
    print('\n%s files found' % fileCount)
    f.close()
    csv.close()


if sourceservers is None or len(sourceservers) == 0:
    print('--sourceserver is required')
    exit()

if showstats is True or newerthan > 0:
    statfile = True
else:
    statfile = False

useLibrarian = '&useLibrarian=true'  # True
fileCount = 0

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

for sourceserver in sourceservers:
    print('\n============================\n %s\n============================\n' % sourceserver)

    search = api('get', '/searchvms?entityTypes=kView&entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAWSSnapshotManager&entityTypes=kAzure&entityTypes=kAzureNative&entityTypes=kFlashBlade&entityTypes=kGCP&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware&vmName=%s' % sourceserver)

    if 'vms' not in search:
        print('no backups found for %s' % sourceserver)
        continue

    searchResults = [vm for vm in search['vms'] if vm['vmDocument']['objectName'].lower() == sourceserver.lower()]

    if len(searchResults) == 0:
        print('no backups found for %s' % sourceserver)
        continue

    altJobName = 'old name: %s' % jobname.lower()
    altJobName2 = '%s (old name' % jobname.lower()
    searchResults = [vm for vm in searchResults if vm['vmDocument']['jobName'].lower() == jobname.lower() or altJobName in vm['vmDocument']['jobName'].lower() or altJobName2 in vm['vmDocument']['jobName'].lower()]

    if len(searchResults) == 0:
        print('%s not protected by %s' % (sourceserver, jobname))
        continue

    searchResults = [r for r in searchResults if 'versions' in r['vmDocument'] and len(r['vmDocument']['versions']) > 0]

    if len(searchResults) == 0:
        print('No backups available for %s in %s' % (sourceserver, jobname))
        continue

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
                print("\n==============================")
                print("   runId: %s" % version['instanceId']['jobInstanceId'])
                print(" runDate: %s" % usecsToDate(version['instanceId']['jobStartTimeUsecs']))
                print("==============================\n")
                showFiles(version['doc'], version)
        else:
            print('%10s  %s' % ('runId', 'runDate'))
            print('%10s  %s' % ('-----', '-------'))
            for version in allVersions:
                print('%10d  %s' % (version['instanceId']['jobInstanceId'], usecsToDate(version['instanceId']['jobStartTimeUsecs'])))
        continue

    # select version
    if runid is not None:
        # select version with matching runId
        versions = [v for v in allVersions if runid == v['instanceId']['jobInstanceId']]
        if len(versions) == 0:
            print('Run ID not found')
            continue
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
            print('No backups from the specified date')
            continue
    else:
        # just use latest version
        version = allVersions[0]
        showFiles(version['doc'], version)
