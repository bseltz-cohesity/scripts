#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
import codecs
import argparse

try:
    from urllib.parse import quote_plus
except Exception:
    from urllib import quote_plus

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-o', '--objectcount', type=int, default=100)
parser.add_argument('-p', '--matchpath', type=str, default='/Windows/System32/drivers/CrowdStrike/C-00000291')  # '/scripts/python/build/archiveEndOfMonth/localpycs/pyimod0')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
objectcount = args.objectcount
matchpath = args.matchpath

startpath = matchpath[0:matchpath.rindex('/')]
matchpath = matchpath.lower()

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = '%s-%s-CrowdStrikeReport.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('"Object Name","Environment","Protected","Useful Protection Group","Latest Backup","Latest File"\n')


def listdir(dirPath, instance, volumeInfoCookie=None, volumeName=None, cookie=None):
    global fileList
    useLibrarian = False
    statfile = False
    thisDirPath = quote_plus(dirPath).replace('%2F%2F', '%2F')
    if cookie is not None:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=%s&dirPath=%s&volumeInfoCookie=%s&volumeName=%s&cookie=%s' % (instance, useLibrarian, statfile, thisDirPath, volumeInfoCookie, volumeName, cookie), quiet=True)
        else:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=%s&dirPath=%s&cookie=%s' % (instance, useLibrarian, statfile, thisDirPath, cookie), quiet=True)
    else:
        if volumeName is not None:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=%s&dirPath=%s&volumeInfoCookie=%s&volumeName=%s' % (instance, useLibrarian, statfile, thisDirPath, volumeInfoCookie, volumeName), quiet=True)
        else:
            dirList = api('get', '/vm/directoryList?%s&useLibrarian=%s&statFileEntries=%s&dirPath=%s' % (instance, useLibrarian, statfile, thisDirPath), quiet=True)
    if dirList and 'entries' in dirList:
        for entry in sorted(dirList['entries'], key=lambda e: e['name']):
            try:
                if entry['type'] == 'kDirectory':
                    nextDirPath = '%s/%s' % (dirPath, entry['name'])
                    if volumeName is not None:
                        shortPath = nextDirPath[1:].lower()
                    else:
                        shortPath = nextDirPath[3:].lower()
                    if shortPath in matchpath:
                        listdir('%s/%s' % (dirPath, entry['name']), instance, volumeInfoCookie, volumeName)
                else:
                    if matchpath in entry['fullPath'].lower():
                        fileList.append(entry['fullPath'])
            except Exception:
                pass
    if dirList and 'cookie' in dirList:
        listdir('%s' % dirPath, instance, volumeInfoCookie, volumeName, dirList['cookie'])


volumeTypes = [1, 6]
paginationCookie = 0

while True:
    search = api('get', 'data-protect/search/objects?osTypes=kWindows&paginationCookie=%s&count=%s' % (paginationCookie, objectcount), v=2)
    for obj in search['objects']:
        print('%s (%s)' % (obj['name'], obj['environment']))
        protectionGroup = ''
        protected = False
        fileList = ['']
        latestFile = ''
        usefulProtectionGroup = ''
        latestBackup = ''
        for protectionInfo in obj['objectProtectionInfos']:
            if protectionInfo['protectionGroups'] is None:
                continue
            for pg in protectionInfo['protectionGroups']:
                protected = True
                protectionGroup = pg['name']
                v1JobId = pg['id'].split(':')[2]
                searchResults = api('get', '/searchvms?vmName=%s&jobIds=%s' % (obj['name'], v1JobId))
                if 'vms' not in searchResults:
                    continue
                searchResults = [vm for vm in searchResults['vms'] if vm['vmDocument']['objectName'].lower() == obj['name'].lower()]
                
                allVersions = []
                for searchResult in searchResults:
                    for version in searchResult['vmDocument']['versions']:
                        version['doc'] = searchResult['vmDocument']
                        allVersions.append(version)
                allVersions = sorted(allVersions, key=lambda r: r['snapshotTimestampUsecs'], reverse=True)
                version = allVersions[0]
                doc = version['doc']
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
                backupType = doc['backupType']
                if backupType in volumeTypes:
                    volumeList = api('get', '/vm/volumeInfo?%s' % instance)
                    if 'volumeInfos' in volumeList:
                        volumeInfoCookie = volumeList['volumeInfoCookie']
                        for volume in sorted(volumeList['volumeInfos'], key=lambda v: v['name']):
                            volumeName = quote_plus(volume['name'])
                            listdir('/%s' % startpath, instance, volumeInfoCookie, volumeName)
                else:
                    driveletters = [d['mountPointVec'][0] for d in doc['objectId']['entity']['physicalEntity']['volumeInfoVec'] if 'mountPointVec' in d and d['mountPointVec'] is not None and len(d['mountPointVec']) > 0]
                    for driveletter in driveletters:
                        shortdriveletter = driveletter[0:1]
                        listdir('/%s%s' % (shortdriveletter, startpath), instance)
                        latestFile = sorted(fileList)[-1]
                        if latestFile != '':
                            break

                latestFile = sorted(fileList)[-1]
                if latestFile != '':
                    print('    %s' % latestFile)

                if latestFile != '' and usefulProtectionGroup == '':
                    usefulProtectionGroup = protectionGroup
                    latestBackup = usecsToDate(version['instanceId']['jobStartTimeUsecs'])
        f.write('"%s","%s","%s","%s","%s","%s"\n' % (obj['name'], obj['environment'], protected, usefulProtectionGroup, latestBackup, latestFile))
    if str(search['count']) == str(search['paginationCookie']):
        break
    else:
        paginationCookie = search['paginationCookie']

f.close()
print('\nOutput saved to %s\n' % outfile)
