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
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-s', '--sourceserver', type=str, required=True)   # job name
parser.add_argument('-t', '--targetserver', type=str, default=None)   # run date to archive in military format with 00 seconds
parser.add_argument('-n', '--targetusername', type=str, default='')    # (optional) will use policy retention if omitted
parser.add_argument('-p', '--targetpassword', type=str, default='')  # (optional) will use policy target if omitted
parser.add_argument('-a', '--useexistingagent', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
sourceserver = args.sourceserver
targetserver = args.targetserver
targetusername = args.targetusername
targetpassword = args.targetpassword
useexistingagent = args.useexistingagent

if targetserver is None:
    targetserver = sourceserver

# authenticate
apiauth(vip, username, domain)

# find backups for source server
searchResults = api('get', '/searchvms?vmName=%s' % sourceserver)
if searchResults:
    searchResults = [v for v in searchResults['vms'] if v['vmDocument']['objectName'].lower() == sourceserver.lower()]

if len(searchResults) == 0:
    print("%s is not protected" % sourceserver)
    exit(1)

# find newest among multiple jobs
searchResult = sorted(searchResults, key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]
doc = searchResult['vmDocument']

# find source and target servers
entities = api('get', '/entitiesOfType?awsEntityTypes=kEC2Instance&azureEntityTypes=kVirtualMachine&environmentTypes=kVMware&environmentTypes=kPhysical&environmentTypes=kView&environmentTypes=kGenericNas&environmentTypes=kIsilon&environmentTypes=kNetapp&environmentTypes=kAzure&environmentTypes=kAWS&environmentTypes=kGCP&gcpEntityTypes=kVirtualMachine&genericNasEntityTypes=kHost&isProtected=true&isilonEntityTypes=kMountPoint&netappEntityTypes=kVolume&physicalEntityTypes=kHost&viewEntityTypes=kView&vmwareEntityTypes=kVirtualMachine')
sourceEntity = [e for e in entities if e['displayName'].lower() == sourceserver.lower()]
targetEntity = [e for e in entities if e['displayName'].lower() == targetserver.lower()]

if len(sourceEntity) == 0:
    print("source server %s not found")
    exit(1)

if len(targetEntity) == 0:
    print("target server %s not found")
    exit(1)

mountTask = {
    'name': 'myMountOperation',
    'objects': [
        {
            'jobId': doc['objectId']['jobId'],
            'jobUid': doc['objectId']['jobUid'],
            'entity': sourceEntity[0],
            'jobInstanceId': doc['versions'][0]['instanceId']['jobInstanceId'],
            'startTimeUsecs': doc['versions'][0]['instanceId']['jobStartTimeUsecs']
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

print("mounting volumes to %s..." % targetserver)
result = api('post', '/restore', mountTask)

# wait for completion
taskid = result['restoreTask']['performRestoreTaskState']['base']['taskId']
finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
status = 'unknown'
while status not in finishedStates:
    sleep(3)
    restoreTask = api('get', '/restoretasks/%s' % taskid)
    status = restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus']
print("Volume mount ended with status %s" % status)
if status == 'kSuccess':
    print('Task ID for tearDown is: %s' % restoreTask[0]['restoreTask']['performRestoreTaskState']['base']['taskId'])
    mountPoints = restoreTask[0]['restoreTask']['performRestoreTaskState']['mountVolumesTaskState']['mountInfo']['mountVolumeResultVec']
    for mountPoint in mountPoints:
        print('%s mounted to %s' % (mountPoint['originalVolumeName'], mountPoint['mountPoint']))
