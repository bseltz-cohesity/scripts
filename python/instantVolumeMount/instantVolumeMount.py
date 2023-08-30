#!/usr/bin/env python
"""Instant Volume Mount"""

# usage: ./instantVolumeMount.py -v mycluster \
#                                -u myuser \
#                                -d mydomain.net \
#                                -s server1.mydomain.net \
#                                -t server2.mydomain.net \
#                                -n 'mydomain.net\myuser' \
#                                -p swordfish

# import pyhesity wrapper module
from pyhesity import *
from time import sleep

# command line arguments
import argparse
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
parser.add_argument('-s', '--sourceserver', type=str, required=True)   # job name
parser.add_argument('-t', '--targetserver', type=str, default=None)   # run date to archive in military format with 00 seconds
parser.add_argument('-n', '--targetusername', type=str, default='')    # (optional) will use policy retention if omitted
parser.add_argument('-p', '--targetpassword', type=str, default='')  # (optional) will use policy target if omitted
parser.add_argument('-a', '--useexistingagent', action='store_true')
parser.add_argument('-vol', '--volume', action='append', type=str)
parser.add_argument('-l', '--showversions', action='store_true')      # show available snapshots
parser.add_argument('-start', '--start', type=str, default=None)          # show snapshots after date
parser.add_argument('-end', '--end', type=str, default=None)            # show snapshots before date
parser.add_argument('-r', '--runid', type=str, default=None)          # choose specific job run id

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
targetserver = args.targetserver
targetusername = args.targetusername
targetpassword = args.targetpassword
useexistingagent = args.useexistingagent
volumes = args.volume
showversions = args.showversions
start = args.start
end = args.end
runid = args.runid

if targetserver is None:
    targetserver = sourceserver

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

# find backups for source server
searchResults = api('get', '/searchvms?vmName=%s' % sourceserver)
if searchResults:
    searchResults = [v for v in searchResults['vms'] if v['vmDocument']['objectName'].lower() == sourceserver.lower()]

if len(searchResults) == 0:
    print('%s is not protected' % sourceserver)
    exit(1)

searchResults = [r for r in searchResults if 'versions' in r['vmDocument'] and len(r['vmDocument']['versions']) > 0]

if len(searchResults) == 0:
    print('No backups available for %s' % sourceserver)
    exit(1)

allVersions = []
for searchResult in searchResults:
    for version in searchResult['vmDocument']['versions']:
        version['doc'] = searchResult['vmDocument']
        allVersions.append(version)
allVersions = sorted(allVersions, key=lambda r: r['snapshotTimestampUsecs'], reverse=True)

if start is not None:
    startusecs = dateToUsecs(start)
    allVersions = [v for v in allVersions if startusecs <= v['snapshotTimestampUsecs']]
if end is not None:
    endusecs = dateToUsecs(end)
    allVersions = [v for v in allVersions if endusecs >= v['snapshotTimestampUsecs']]

if showversions:
    print('\n%10s  %s' % ('runId', 'runDate'))
    print('%10s  %s' % ('-----', '-------'))
    for version in allVersions:
        print('%10d  %s' % (version['instanceId']['jobInstanceId'], usecsToDate(version['instanceId']['jobStartTimeUsecs'])))
    print('')
    exit(0)

# select version
if runid is not None:
    runidisint = False
    try:
        runid = int(runid)
        runidisint = True
    except Exception:
        pass
    # select version with matching runId
    # print('%s:%s' % (allVersions[0]['doc']['objectId']['jobId'], allVersions[0]['instanceId']['jobStartTimeUsecs']))
    versions = [v for v in allVersions if (runidisint is True and runid == v['instanceId']['jobInstanceId']) or (runidisint is not True and runid == '%s:%s' % (v['doc']['objectId']['jobId'], v['instanceId']['jobStartTimeUsecs']))]
    if len(versions) == 0:
        print('Run ID not found')
        exit(1)
    else:
        version = versions[0]
else:
    # just use latest version
    version = allVersions[0]

doc = version['doc']
sourceEntityType = doc['objectId']['entity']['type']

# find source and target servers
entities = api('get', '/entitiesOfType?awsEntityTypes=kEC2Instance&azureEntityTypes=kVirtualMachine&environmentTypes=kVMware&environmentTypes=kPhysical&environmentTypes=kView&environmentTypes=kGenericNas&environmentTypes=kIsilon&environmentTypes=kNetapp&environmentTypes=kAzure&environmentTypes=kAWS&environmentTypes=kGCP&gcpEntityTypes=kVirtualMachine&genericNasEntityTypes=kHost&isProtected=true&isilonEntityTypes=kMountPoint&netappEntityTypes=kVolume&physicalEntityTypes=kHost&viewEntityTypes=kView&vmwareEntityTypes=kVirtualMachine')
sourceEntity = [e for e in entities if e['displayName'].lower() == sourceserver.lower()]
targetEntity = [e for e in entities if e['displayName'].lower() == targetserver.lower()]

if len(sourceEntity) == 0:
    print('source server %s not found' % sourceserver)
    exit(1)

if len(targetEntity) == 0:
    print('target server %s not found' % targetserver)
    exit(1)

if targetEntity[0]['type'] != sourceEntityType:
    print('%s is not compatible with volumes from %s' % (targetserver, sourceserver))
    exit(1)

mountTask = {
    'name': 'myMountOperation',
    'objects': [
        {
            'jobId': doc['objectId']['jobId'],
            'jobUid': doc['objectId']['jobUid'],
            'entity': sourceEntity[0],
            'jobInstanceId': version['instanceId']['jobInstanceId'],
            'startTimeUsecs': version['instanceId']['jobStartTimeUsecs']
        }
    ],
    'mountVolumesParams': {
        'targetEntity': targetEntity[0],
        'vmwareParams': {
            'bringDisksOnline': True,
            'targetEntityCredentials': {
                'username': targetusername,
                'password': targetpassword
            }
        }
    }
}

if 'parentId' in targetEntity:
    mountTask['restoreParentSource'] = {'id': targetEntity['parentId']}

if useexistingagent:
    mountTask['mountVolumesParams']['useExistingAgent'] = True

if volumes is not None:
    mountTask['mountVolumesParams']['volumeNameVec'] = volumes

print('mounting volumes to %s...' % targetserver)
result = api('post', '/restore', mountTask)

# wait for completion
if 'restoreTask' not in result:
    exit(1)
taskid = result['restoreTask']['performRestoreTaskState']['base']['taskId']
finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
status = 'unknown'
while status not in finishedStates:
    sleep(10)
    restoreTask = api('get', '/restoretasks/%s' % taskid)
    status = restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus']
print('Volume mount ended with status %s' % status)
if status == 'kSuccess':
    print('Task ID for tearDown is: %s' % restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['taskId'])
    if 'mountVolumeResultVec' in restoreTask[0]['restoreTask']['performRestoreTaskState']['mountVolumesTaskState']['mountInfo']:
        mountPoints = restoreTask[0]['restoreTask']['performRestoreTaskState']['mountVolumesTaskState']['mountInfo']['mountVolumeResultVec']
        for mountPoint in mountPoints:
            print('%s mounted to %s' % (mountPoint['originalVolumeName'], mountPoint['mountPoint']))
