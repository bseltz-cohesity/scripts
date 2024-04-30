#!/usr/bin/env python
"""Add Physical Linux Servers to File-based Protection Job Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='Ccs')
parser.add_argument('-r', '--region', type=str, required=True)
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-n', '--vmname', action='append', type=str)
parser.add_argument('-l', '--vmlist', type=str)
parser.add_argument('-p', '--policyname', type=str, required=True)
parser.add_argument('-t', '--protectiontype', type=str, choices=['All', 'CohesitySnapshot', 'AWSSnapshot'], default='CohesitySnapshot')
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)

args = parser.parse_args()

username = args.username              # username to connect to cluster
region = args.region                  # domain of username (e.g. local, or AD domain)
sourcename = args.sourcename          # name of registered AWS protection source
vmnames = args.vmname                 # name of server to protect
vmlist = args.vmlist                  # file with server names
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job
protectiontype = args.protectiontype  # protection type


# get object ID
def getObjectId(objectName):

    d = {'_object_id': None}

    def get_nodes(node):
        if 'name' in node:
            if node['name'].lower() == objectName.lower():
                d['_object_id'] = node['id']
                exit
        if 'protectionSource' in node:
            if node['protectionSource']['name'].lower() == objectName.lower():
                d['_object_id'] = node['protectionSource']['id']
                exit
        if 'nodes' in node:
            for node in node['nodes']:
                if d['_object_id'] is None:
                    get_nodes(node)
                else:
                    exit

    for source in sources:
        if d['_object_id'] is None:
            get_nodes(source)

    return d['_object_id']


# read server file
if vmnames is None:
    vmnames = []
if vmlist is not None:
    f = open(vmlist, 'r')
    vmnames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

if len(vmnames) == 0:
    print('*** no vms specified')
    exit()

# parse starttime
try:
    (hour, minute) = starttime.split(':')
    hour = int(hour)
    minute = int(minute)
    if hour < 0 or hour > 23 or minute < 0 or minute > 59:
        print('*** starttime is invalid!')
        exit(1)
except Exception:
    print('*** starttime is invalid!')
    exit(1)

# print('Connecting to CCS')

# authenticate to Cohesity
apiauth(username=username, regionid=region)
if apiconnected() is False:
    exit()

# print('Finding policy')

# find protectionPolicy
policy = [p for p in (api('get', 'data-protect/policies?types=DMaaSPolicy', mcmv2=True)['policies']) if p['name'].lower() == policyname.lower()]
if len(policy) < 1:
    print("*** Policy '%s' not found!" % policyname)
    exit(1)
else:
    policy = policy[0]

# print('Finding AWS source')

sources = api('get', 'protectionSources?environments=kAWS')

source = [s for s in sources if s['protectionSource']['name'].lower() == sourcename.lower()]
if source is None or len(source) == 0:
    print('*** AWS protection source %s not registered' % sourcename)
    exit()

protectionParams = {
    "abortInBlackouts": False,
    "priority": "kMedium",
    "objects": [
        {
            "awsParams": {
                "protectionType": "kSnapshotManager",
                "nativeProtectionTypeParams": {
                    "indexingPolicy": {
                        "enableIndexing": False,
                        "excludePaths": [],
                        "includePaths": []
                    },
                    "excludeVmTagIds": [],
                    "objects": [],
                    "cloudMigration": False,
                    "createAmi": False
                },
                "snapshotManagerProtectionTypeParams": {
                    "indexingPolicy": {
                        "enableIndexing": False,
                        "excludePaths": [],
                        "includePaths": []
                    },
                    "excludeVmTagIds": [],
                    "objects": [],
                    "cloudMigration": False,
                    "createAmi": False
                }
            },
            "environment": "kAWS"
        }
    ],
    "qosPolicy": "kBackupSSD",
    "sla": [
        {
            "slaMinutes": fullsla,
            "backupRunType": "kFull"
        },
        {
            "slaMinutes": incrementalsla,
            "backupRunType": "kIncremental"
        }
    ],
    "startTime": {
        "minute": hour,
        "timeZone": timezone,
        "hour": minute
    },
    "policyConfig": {
        "policies": []
    }
}

if protectiontype in ['All', 'CohesitySnapshot']:
    protectionParams['policyConfig']['policies'].append({
        "id": policy['id'],
        "protectionType": "kNative"
    })

if protectiontype in ['All', 'AWSSnapshot']:
    protectionParams['policyConfig']['policies'].append({
        "id": policy['id'],
        "protectionType": "kSnapshotManager"
    })

for vm in vmnames:
    # print('Finding VM %s' % vm)
    vmId = getObjectId(vm)

    if vmId is not None:
        protectionParams['objects'][0]['awsParams']['snapshotManagerProtectionTypeParams']['objects'] = [
            {
                "id": vmId,
                "volumeExclusionParams": None,
                "excludeObjectIds": []
            }
        ]
        protectionParams['objects'][0]['awsParams']['nativeProtectionTypeParams']['objects'] = [
            {
                "id": vmId,
                "volumeExclusionParams": None,
                "excludeObjectIds": []
            }
        ]
        print('Protecting %s' % vm)
        response = api('post', 'data-protect/protected-objects', protectionParams, v=2)
    else:
        print('*** VM %s not found' % vm)
