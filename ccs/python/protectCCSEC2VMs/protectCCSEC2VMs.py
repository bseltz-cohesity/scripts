#!/usr/bin/env python
"""Add Physical Linux Servers to File-based Protection Job Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='dmaas')
parser.add_argument('-r', '--region', type=str, required=True)
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-n', '--vmname', action='append', type=str)
parser.add_argument('-l', '--vmlist', type=str)
parser.add_argument('-g', '--tagname', action='append', type=str)
parser.add_argument('-p', '--policyname', type=str, required=True)
parser.add_argument('-t', '--protectiontype', type=str, choices=['All', 'CohesitySnapshot', 'AWSSnapshot'], default='CohesitySnapshot')
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)
parser.add_argument('-b', '--bootdiskonly', action='store_true')
parser.add_argument('-x', '--excludedisk', action='append', type=str)

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
tagnames = args.tagname
bootdiskonly = args.bootdiskonly
excludedisks = args.excludedisk


# gather server list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


vmnames = gatherList(vmnames, vmlist, name='VMs', required=False)
tagnames = gatherList(tagnames, name='tags', required=False)
excludedisks = gatherList(excludedisks, name='excluded disks', required=False)

if len(vmnames) == 0 and len(tagnames) == 0:
    print('No VMs or tags specified')
    exit()


# get object
def getObject(objectName):

    d = {'_object': None}

    def get_nodes(node):

        if node['protectionSource']['awsProtectionSource']['type'] == 'kEC2Instance' and node['protectionSource']['name'].lower() == objectName.lower():
            d['_object'] = node
            exit
        if 'nodes' in node:
            for node in node['nodes']:
                if d['_object'] is None:
                    get_nodes(node)
                else:
                    exit

    get_nodes(source)

    return d['_object']


def getObjectsByTag(tagName):
    
    d = {'_objects': []}

    def get_nodes(node):

        if node['protectionSource']['awsProtectionSource']['type'] == 'kEC2Instance' and 'tagAttributes' in node['protectionSource']['awsProtectionSource'] and tagName in [n['name'] for n in node['protectionSource']['awsProtectionSource']['tagAttributes']]:
            d['_objects'].append(node)
        if 'nodes' in node:
            for node in node['nodes']:
                get_nodes(node)
            else:
                exit

    get_nodes(source)

    return d['_objects']


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

# authenticate to Cohesity
apiauth(username=username, regionid=region)
if apiconnected() is False:
    exit()

sources = api('get', 'protectionSources?environments=kAWS')

source = [s for s in sources if s['protectionSource']['name'].lower() == sourcename.lower()]
if source is None or len(source) == 0:
    print('*** AWS protection source %s not registered' % sourcename)
    exit()
source = source[0]

vmsToAdd = []

if len(tagnames) > 0:
    for tagname in tagnames:
        print('Enumerating Tag: %s' % tagname)
        taggedVMs = getObjectsByTag(tagname)
        if len(taggedVMs) > 0:
            vmsToAdd = vmsToAdd + taggedVMs
        else:
            print('No VMs with Tag %s found' % tagname)

if len(vmnames) > 0:
    for vmname in vmnames:
        print('Finding VM %s' % vmname)
        vm = getObject(vmname)
        if vm is not None:
            if vm['protectionSource']['name'] not in [n['protectionSource']['name'] for n in vmsToAdd]:
                vmsToAdd.append(vm)
        else:
            print('VM %s not found' % vmname)

if len(vmsToAdd) == 0:
    print('No VMs found')
    exit()

# find protectionPolicy
policy = [p for p in (api('get', 'data-protect/policies?types=DMaaSPolicy', mcmv2=True)['policies']) if p['name'].lower() == policyname.lower()]
if len(policy) < 1:
    print("*** Policy '%s' not found!" % policyname)
    exit(1)
else:
    policy = policy[0]

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

for vm in vmsToAdd:

    volumeExclusionParams = None
    excludedVolumeIds = []
    if bootdiskonly is True or len(excludedisks) > 0:
        for volume in vm['protectionSource']['awsProtectionSource']['volumes']:
            if bootdiskonly is True and volume['isRootDevice'] is False:
                excludedVolumeIds.append(volume['id'])
            elif len(excludedisks) > 0 and volume['deviceName'] in excludedisks:
                excludedVolumeIds.append(volume['id'])
    if len(excludedVolumeIds) > 0:
        volumeExclusionParams = {
            "volumeIds": excludedVolumeIds
        }

    protectionParams['objects'][0]['awsParams']['snapshotManagerProtectionTypeParams']['objects'] = [
        {
            "id": vm['protectionSource']['id'],
            "volumeExclusionParams": volumeExclusionParams,
            "excludeObjectIds": []
        }
    ]
    protectionParams['objects'][0]['awsParams']['nativeProtectionTypeParams']['objects'] = [
        {
            "id":  vm['protectionSource']['id'],
            "volumeExclusionParams": volumeExclusionParams,
            "excludeObjectIds": []
        }
    ]
    print('Protecting %s' % vm['protectionSource']['name'])
    response = api('post', 'data-protect/protected-objects', protectionParams, v=2)
