#!/usr/bin/env python
"""backed up files list for python"""

# version 2020.07.10

# usage: ./backedUpFileList.py -v mycluster \
#                              -u myuser \
#                              -d mydomain.net \
#                              -s server1.mydomain.net \
#                              -j myjob \
#                              -f '2020-06-29 12:00:00'

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from urllib import quote_plus

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # username
parser.add_argument('-d', '--domain', type=str, default='local')      # domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')         # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)     # optional password
parser.add_argument('-s', '--sourceserver', type=str, required=True)  # name of source server
parser.add_argument('-j', '--jobname', type=str, required=True)       # narrow search by job name
parser.add_argument('-l', '--showverions', action='store_true')       # show available snapshots
parser.add_argument('-r', '--runid', type=int, default=None)          # choose specific job run id
parser.add_argument('-f', '--filedate', type=str, default=None)       # date to restore from

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
sourceserver = args.sourceserver
jobname = args.jobname
showversions = args.showverions
runid = args.runid
filedate = args.filedate

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

search = api('get', '/searchvms?entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAWSSnapshotManager&entityTypes=kAzure&entityTypes=kAzureNative&entityTypes=kFlashBlade&entityTypes=kGCP&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware&vmName=%s' % sourceserver)

if 'vms' not in search:
    print('%s not found' % sourceserver)
    exit(1)

searchResults = [vm for vm in search['vms'] if vm['vmDocument']['objectName'].lower() == sourceserver.lower()]
if len(search['vms']) == 0:
    print('%s not found' % sourceserver)
    exit(1)

searchResults = [vm for vm in searchResults if vm['vmDocument']['jobName'].lower() == jobname.lower()]
if len(search['vms']) == 0:
    print('%s not protected by %s' % (sourceserver, jobname))
    exit(1)

searchResult = sorted(searchResults, key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]

doc = searchResult['vmDocument']

if showversions:
    print('%10s  %s' % ('runId', 'runDate'))
    print('%10s  %s' % ('-----', '-------'))
    for version in doc['versions']:
        print('%10d  %s' % (version['instanceId']['jobInstanceId'], usecsToDate(version['instanceId']['jobStartTimeUsecs'])))
    exit(0)

# select version
if runid is not None:
    # select version with matching runId
    versions = [v for v in doc['versions'] if runid == v['instanceId']['jobInstanceId']]
    if len(versions) == 0:
        print('Run ID not found')
        exit(1)
    else:
        version = versions[0]
elif filedate is not None:
    # select version just after requested date
    filedateusecs = dateToUsecs(filedate)
    versions = [v for v in doc['versions'] if filedateusecs <= v['snapshotTimestampUsecs']]
    if versions:
        version = versions[-1]
    else:
        print('No backups from the specified date')
        exit(1)
else:
    # just use latest version
    version = doc['versions'][0]

instance = ("attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&jobUidObjectId=%s" %
            (version['instanceId']['attemptNum'],
             doc['objectId']['jobUid']['clusterId'],
             doc['objectId']['jobUid']['clusterIncarnationId'],
             doc['objectId']['entity']['id'],
             doc['objectId']['jobId'],
             version['instanceId']['jobInstanceId'],
             version['instanceId']['jobStartTimeUsecs'],
             doc['objectId']['jobUid']['objectId']))

fileDateString = datetime.strptime(usecsToDate(version['instanceId']['jobStartTimeUsecs']), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d_%H-%M-%S')

f = open('backedUpFiles-%s-%s.txt' % (sourceserver, fileDateString), 'w')


def listdir(dirPath, instance, volumeInfoCookie=None, volumeName=None):
    thisDirPath = quote_plus(dirPath)
    if volumeName is not None:
        dirList = api('get', '/vm/directoryList?%s&dirPath=%s&statFileEntries=false&volumeInfoCookie=%s&volumeName=%s' % (instance, thisDirPath, volumeInfoCookie, volumeName))
    else:
        dirList = api('get', '/vm/directoryList?%s&dirPath=%s&statFileEntries=false' % (instance, thisDirPath))
    if 'entries' in dirList:
        for entry in sorted(dirList['entries'], key=lambda e: e['name']):
            if entry['type'] == 'kDirectory':
                listdir('%s/%s' % (dirPath, entry['name']), instance, volumeInfoCookie, volumeName)
            else:
                print(entry['fullPath'])
                f.write('%s\n' % entry['fullPath'])


volumeTypes = [1, 6]
backupType = doc['backupType']
if backupType in volumeTypes:
    volumeList = api('get', '/vm/volumeInfo?%s&statFileEntries=false' % instance)
    if 'volumeInfos' in volumeList:
        volumeInfoCookie = volumeList['volumeInfoCookie']
        for volume in sorted(volumeList['volumeInfos'], key=lambda v: v['name']):
            volumeName = quote_plus(volume['name'])
            listdir('/', instance, volumeInfoCookie, volumeName)
else:
    listdir('/', instance)

f.close()
