#!/usr/bin/env python
"""protect a new NFS Mount"""

### usage: ./protectNewNFSMountV2.sh -v mycluster -u admin -p "My Policy" -m "192.168.1.14:/var/nfs2"

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-p', '--policyName', type=str, required=True)
parser.add_argument('-m', '--mountPath', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
policyName = args.policyName
mountPath = args.mountPath

### authenticate
apiauth(vip, username, domain)

### find protectionPolicy
policy = [policy for policy in api('get', 'protectionPolicies') if policy['name'].lower() == policyName.lower()]
if not policy:
    print("Policy '%s' not fouond!" % policyName)
    exit()
policy = policy[0]

### find storageDomain
viewBox = api('get', 'viewBoxes')[0]

### new NAS MountPoint Definition
newNASMount = {
    'entity': {
        'type': 11,
        'genericNasEntity': {
            'protocol': 1,
            'type': 1,
            'path': mountPath
        }
    },
    'entityInfo': {
        'endpoint': mountPath,
        'type': 11
    }
}

### check for existing mountPoint
mountPoints = api('get', '/backupsources?envTypes=11')['entityHierarchy']['children'][0]['children']
mountPoint = [mountPoint for mountPoint in mountPoints if mountPoint['entity']['genericNasEntity']['path'].lower() == mountPath.lower()]
mountRoot = api('get', '/backupsources?onlyReturnOneLevel=true&envTypes=11')

### register new NAS MountPoint
if (len(mountPoint) == 0):
    result = api('post', '/backupsources', newNASMount)
    id = result['entity']['id']
else:
    id = mountPoint[0]['entity']['id']

server = mountPath.split(':')[0]
share = mountPath.split('/')[-1]
jobName = server + '-' + share

### create new to ProtectionJob

jobTask = {
    "name": jobName,
    "environment": "kGenericNas",
    "_envParams": {
        "nasProtocol": "kNfs3",
        "continueOnError": True
    },
    "parentSourceId": mountRoot['entityHierarchy']['children'][0]['entity']['id'],
    "sourceIds": [
        id
    ],
    "excludeSourceIds": [],
    "vmTagIds": [],
    "excludeVmTagIds": [],
    "priority": "kMedium",
    "alertingPolicy": [
        "kFailure"
    ],
    "timezone": "America/New_York",
    "incrementalProtectionSlaTimeMins": 60,
    "fullProtectionSlaTimeMins": 120,
    "qosType": "kBackupHDD",
    "_sourceSpecialParametersMap": {},
    "environmentParameters": {
        "nasParameters": {
            "nasProtocol": "kNfs3",
            "continueOnError": True
        }
    },
    "isActive": True,
    "_supportsAutoProtectExclusion": True,
    "sourceSpecialParameters": [],
    "isDeleted": True,
    "_supportsIndexing": False,
    "indexingPolicy": {
        "disableIndexing": True
    },
    "_hasFilePathFilters": False,
    "policyId": policy['id'],
    "_viewBoxName": viewBox['name'],
    "viewBoxId": viewBox['id'],
    "_envParamsKey": "nasParameters",
    "startTime": {
        "hour": 1,
        "minute": 00,
        "second": 00
    }
}

print('creating protection job %s' % (jobName))
result = api('post', 'protectionJobs', jobTask)
