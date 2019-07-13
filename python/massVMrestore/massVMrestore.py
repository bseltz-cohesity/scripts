#!/usr/bin/env python
"""mass VM restore for python"""

### usage: ./massVMrestore.py -v mycluster -u myusername -d mydomain.net -j 'My Job' -vc vcenter.mydomain.net -n 'VM Network' [ -s mysuffix ] [ -f Test ] [ -p ] [ -t massVMrestore.json ] [ -mf 85 ]
### example: ./recoverVMjobV3.py -v bseltzve01 -u admin -j 'VM Backup' -vc vcenter6.seltzer.net -n 'VM Network' -s v9 -f Test

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import json

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # vip to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity domain
parser.add_argument('-j', '--jobname', type=str, required=True)  # protection job name
parser.add_argument('-vc', '--vcentername', type=str, required=True)  # vcenter source
parser.add_argument('-t', '--targets', type=str, default='massVMrestore.json')  # target config file
parser.add_argument('-f', '--foldername', type=str, default='vm')  # vm folder name
parser.add_argument('-n', '--networkname', type=str, required=True)  # vm network name
parser.add_argument('-s', '--suffix', type=str, default='')  # vm name suffix
parser.add_argument('-p', '--poweron', action='store_true')  # power on VMs (default is false)
parser.add_argument('-mf', '--maxfull', type=int, default=85)  # max full percentage of datastores

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobname = args.jobname
vcentername = args.vcentername
foldername = args.foldername
networkname = args.networkname
suffix = args.suffix
poweron = args.poweron
targetfile = args.targets
maxfull = args.maxfull

### authenticate
apiauth(vip, username, domain)


# function to map resourcepools to hosts
def get_resourcepool(obj, parent, hostname):
    global respoolid
    if 'nodes' in obj:
        if obj['protectionSource']['name'] == hostname:
            for node in obj['nodes']:
                if node['protectionSource']['vmWareProtectionSource']['type'] == 'kResourcePool':
                    respoolid = node['protectionSource']['id']
                    break
        for node in obj['nodes']:
            get_resourcepool(node, obj['protectionSource']['name'], hostname)


# get vcenter info
vcentersource = None
vcenterid = None
sources = api('get', 'protectionSources')
for source in sources:
    if source['protectionSource']['name'].lower() == vcentername.lower():
        vcentersource = source
        vcenterid = source['protectionSource']['id']

vcenter = [vcenter for vcenter in api('get', '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter') if vcenter['displayName'].lower() == vcentername.lower()]
if vcenter:
    vcenterentity = vcenter[0]
else:
    print("vcenter %s not found!" % vcentername)
    exit(1)

# find vms for recovery
vms = api('get', "/searchvms?entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAzure&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kView&entityTypes=kVMware&vmName=%s" % jobname)

vmlist = []

if 'count' in vms:
    for vm in vms['vms']:
        print('adding %s to the task queue' % vm['vmDocument']['objectName'])
        vmlist.append({
            "objectName": vm['vmDocument']['objectName'],
            "objectInfo": vm['vmDocument'],
            "recovered": False
        })
else:
    print("Job %s not found" % jobname)
    exit(1)

# sort vms by size
vmlistsorted = sorted(vmlist, key=lambda vm: vm['objectInfo']['versions'][0]['primaryPhysicalSizeBytes'], reverse=True)

# get resource pools
resourcepools = api('get', '/resourcePools?vCenterId=%s' % vcenterid)

# get target locations
targets = json.load(open(targetfile, 'r'))['targets']

targetdatastores = {}

for target in targets:

    # get resource pool for the host
    respoolid = None
    get_resourcepool(vcentersource, '', target['hostname'])
    resourcepoolid = respoolid
    for resourcepool in resourcepools:
        if resourcepool['resourcePool']['id'] == resourcepoolid:
            target['resourcepool'] = resourcepool['resourcePool']
    if 'resourcepool' not in target:
        print('could not find resource pool for host %s' % target['hostname'])
        exit(1)

    # get datastore
    target['datastorename'] = target['datastorename'].lower()
    datastores = api('get', '/datastores?vCenterId=%s&resourcePoolId=%s' % (vcenterid, resourcepoolid))
    for datastore in datastores:
        if datastore['displayName'].lower() == target['datastorename']:
            target['datastore'] = datastore
            target['queuedbytes'] = 0
            target['vmqueue'] = []
            if target['datastorename'] not in targetdatastores:
                targetdatastores[target['datastorename']] = {}
            targetdatastores[target['datastorename']]['capacity'] = datastore['vmwareEntity']['datastoreInfo']['capacity']
            targetdatastores[target['datastorename']]['freeSpace'] = datastore['vmwareEntity']['datastoreInfo']['freeSpace']
            targetdatastores[target['datastorename']]['queuedbytes'] = 0

    if 'datastore' not in target:
        print('could not find datastore %s' % target['datastorename'])
        exit(1)

### find VM network
networkentity = None
networks = api('get', '/networkEntities?vCenterId=%s&resourcePoolId=%s' % (vcenterid, resourcepoolid))
for network in networks:
    if network['displayName'].lower() == networkname.lower():
        networkentity = network
if networkentity is None:
    print("VM network %s not found!" % networkname)
    exit(1)

### find folder
folderentity = None
folders = api('get', '/vmwareFolders?vCenterId=%s&resourcePoolId=%s' % (vcenterid, resourcepoolid))
for folder in folders['vmFolders']:
    if folder['displayName'].lower() == foldername.lower():
        folderentity = folder
if folderentity is None:
    print("VM folder %s not found!" % foldername)
    exit(1)

### distribute vms into target queues
for vm in vmlistsorted:
    targetlistsorted = sorted(targets, key=lambda target: target['queuedbytes'])
    foundtarget = False
    for target in targetlistsorted:
        if foundtarget is False:
            minimumfreespace = targetdatastores[target['datastorename']]['capacity'] * (100 - maxfull) / 100
            estimatedfree = targetdatastores[target['datastorename']]['freeSpace'] - targetdatastores[target['datastorename']]['queuedbytes'] - vm['objectInfo']['versions'][0]['primaryPhysicalSizeBytes']
            if estimatedfree > minimumfreespace:
                target['vmqueue'].append(vm)
                target['queuedbytes'] += vm['objectInfo']['versions'][0]['primaryPhysicalSizeBytes']
                targetdatastores[target['datastorename']]['queuedbytes'] += vm['objectInfo']['versions'][0]['primaryPhysicalSizeBytes']
                targetdatastores[target['datastorename']]['freeSpace'] -= vm['objectInfo']['versions'][0]['primaryPhysicalSizeBytes']
                foundtarget = True
    if foundtarget is False:
        print('Not enough datastore capacity! Please add more targets and try again.')

### launch recovery tasks
for target in targets:
    if target['queuedbytes'] > 0:

        taskName = '%s-%s-%s-%s' % (jobname.replace(' ', '-'),
                                    target['hostname'].replace('.', '-'),
                                    target['datastorename'],
                                    datetime.now().strftime("%Y-%m-%d-%H-%M-%S"))

        restoreParams = {
            "name": taskName,
            "objects": [],
            "powerStateConfig": {
                "powerOn": poweron
            },
            "continueRestoreOnError": True,
            "restoreParentSource": vcenterentity,
            "restoredObjectsNetworkConfig": {
                "networkEntity": networkentity,
                "disableNetwork": False
            },
            "resourcePoolEntity": target['resourcepool'],
            "datastoreEntity": target['datastore'],
            "vmwareParams": {
                "targetVmFolder": folderentity
            }
        }
        # add vms to this recovery task
        for vm in target['vmqueue']:
            versionid = 0
            versionNum = 0
            foundLocalSnapshot = False
            # find latest local snapshot for this vm
            for version in vm['objectInfo']['versions']:
                for replicaVec in version['replicaInfo']['replicaVec']:
                    if replicaVec['target']['type'] == 1 and foundLocalSnapshot is False:
                        foundLocalSnapshot = True
                        versionid = versionNum
                versionNum += 1
            if foundLocalSnapshot:
                restoreParams['objects'].append(
                    {
                        "jobId": vm['objectInfo']['objectId']['jobId'],
                        "jobUid": vm['objectInfo']['objectId']['jobUid'],
                        "entity": vm['objectInfo']['objectId']['entity'],
                        "jobInstanceId": vm['objectInfo']['versions'][versionid]['instanceId']['jobInstanceId'],
                        "startTimeUsecs": vm['objectInfo']['versions'][versionid]['instanceId']['jobStartTimeUsecs'],
                    }
                )
            else:
                # skip this vm if there's no local snapshot
                print('vm %s has no local snapshot. not restoring' % vm['objectName'])

        if suffix:
            # add the suffix if specified
            restoreParams['renameRestoredObjectParam'] = {"suffix": '-' + suffix}

        # start this recovery task
        print("Starting recovery %s..." % (taskName))
        recoveryStatus = api('post', '/restore', restoreParams)
