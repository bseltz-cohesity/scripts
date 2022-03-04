#!/usr/bin/env python
"""Recover VM for python"""

### usage: ./recoverVMjob.py -v mycluster -u admin -j 'VM Backup' -vc vcenter.mydomain.net -vh esxhost1.mydomain.net -ds datastore1 -n 'VM Network' -s recover -f myfolder

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-vm', '--vmname', type=str, required=True)
parser.add_argument('-vc', '--vcentername', type=str, default=None)
parser.add_argument('-dc', '--datacentername', type=str, default=None)
parser.add_argument('-vh', '--vhost', type=str, default=None)
parser.add_argument('-f', '--foldername', type=str, default='vm')
parser.add_argument('-n', '--networkname', type=str, default=None)
parser.add_argument('-s', '--datastorename', type=str, default=None)
parser.add_argument('-pre', '--prefix', type=str, default='')
parser.add_argument('-p', '--poweron', action='store_true')
parser.add_argument('-x', '--detachnetwork', action='store_true')
parser.add_argument('-m', '--preservemacaddress', action='store_true')
parser.add_argument('-t', '--recoverytype', type=str, choices=['InstantRecovery', 'CopyRecovery'], default='InstantRecovery')
parser.add_argument('-l', '--listrecoverypoints', action='store_true')
parser.add_argument('-r', '--recoverypoint', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
vmname = args.vmname
vcentername = args.vcentername
datacentername = args.datacentername
vhost = args.vhost
foldername = args.foldername
networkname = args.networkname
datastorename = args.datastorename
prefix = args.prefix
poweron = args.poweron
detachnetwork = args.detachnetwork
preservemacaddress = args.preservemacaddress
recoverytype = args.recoverytype
listrecoverypoints = args.listrecoverypoints
recoverypoint = args.recoverypoint

if vcentername is not None:
    if datacentername is None:
        print('datacentername is required')
        exit()
    if vhost is None:
        print('vhost is required')
        exit()
    if datastorename is None:
        print('datastorename is required')
        exit()
    if networkname is None and detachnetwork is not True:
        print('networkname is required')
        exit()

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
if recoverypoint is not None:
    recoverypointUsecs = dateToUsecs(recoverypoint)
else:
    recoverypointUsecs = nowUsecs

### authenticate
apiauth(vip, username, domain)

### find the VM to recover
vms = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=%s&environments=kVMware' % vmname, v=2)
vms = [vm for vm in vms['objects'] if vm['name'].lower() == vmname.lower()]
if len(vms) == 0:
    print('vm %s not found' % vmname)
    exit()

### select a snapshot
selectedsnapshot = None
for vm in vms:
    snapshots = api('get', 'data-protect/objects/%s/snapshots' % vm['id'], v=2)
    for snapshot in sorted(snapshots['snapshots'], key=lambda s: s['runStartTimeUsecs'], reverse=True):
        runDate = usecsToDate(snapshot['runStartTimeUsecs'])
        if listrecoverypoints:
            print(runDate)
        else:
            if recoverypoint is not None:
                if runDate == recoverypoint:
                    selectedsnapshot = snapshot
                    break
            else:
                selectedsnapshot = snapshot
                break

if listrecoverypoints:
    exit()

if selectedsnapshot is None:
    print('No recovery point found for %s' % usecsToDate(recoverypointUsecs))
    exit()

restoreTaskName = "Recover-VM_%s" % now.strftime("%Y-%m-%d_%H-%M-%S")

restoreParams = {
    "name": restoreTaskName,
    "snapshotEnvironment": "kVMware",
    "vmwareParams": {
        "objects": [
            {
                "snapshotId": selectedsnapshot['id']
            }
        ],
        "recoveryAction": "RecoverVMs",
        "recoverVmParams": {
            "targetEnvironment": "kVMware",
            "recoverProtectionGroupRunsParams": [],
            "vmwareTargetParams": {
                "recoveryTargetConfig": {
                    "recoverToNewSource": False
                },
                "powerOnVms": False,
                "continueOnError": False,
                "recoveryProcessType": recoverytype
            }
        }
    }
}

if vcentername:
    # select vCenter
    vCenterSource = [v for v in api('get', 'protectionSources?environments=kVMware') if v['protectionSource']['name'].lower() == vcentername.lower()]
    vCenterList = api('get', '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter&vmwareEntityTypes=kStandaloneHost')
    vCenter = [v for v in vCenterList if v['displayName'].lower() == vcentername.lower()]
    if len(vCenterSource) == 0 or len(vCenter) == 0:
        print('vcenter %s not found' % vcentername)
        exit()
    vCenterId = vCenter[0]['id']

    # select data center
    dataCenterSource = [d for d in vCenterSource[0]['nodes'][0]['nodes'] if d['protectionSource']['name'].lower() == datacentername.lower()]
    if len(dataCenterSource) == 0:
        print('Datacenter %s not found' % datacentername)
        exit()

    # select host
    hostSource = [h for h in dataCenterSource[0]['nodes'][0]['nodes'] if h['protectionSource']['name'].lower() == vhost.lower()]
    if len(hostSource) == 0:
        print('Host %s not found' % vhost)
        exit()

    # select resource pool
    resourcePoolSource = [r for r in hostSource[0]['nodes'] if r['protectionSource']['vmWareProtectionSource']['type'] == 'kResourcePool']
    resourcePoolId = resourcePoolSource[0]['protectionSource']['id']
    resourcePool = [r for r in api('get', '/resourcePools?vCenterId=%s' % vCenterId) if r['resourcePool']['id'] == resourcePoolId]
    resourcePool = resourcePool[0]

    # select datastore
    datastores = [d for d in api('get', '/datastores?resourcePoolId=%s&vCenterId=%s' % (resourcePoolId, vCenterId)) if d['vmwareEntity']['name'].lower() == datastorename.lower()]
    if len(datastores) == 0:
        print('Datastore %s not found' % datastorename)
        exit()

    # select VM folder
    vmFolders = api('get', '/vmwareFolders?resourcePoolId=%s&vCenterId=%s' % (resourcePoolId, vCenterId))
    vmFolder = [v for v in vmFolders['vmFolders'] if v['displayName'].lower() == foldername]
    if len(vmFolder) == 0:
        print('folder %s not found' % foldername)
        exit()

    # select network
    network = None
    if networkname is not None:
        network = [n for n in api('get', '/networkEntities?resourcePoolId=%s&vCenterId=%s' % (resourcePoolId, vCenterId)) if n['displayName'].lower() == networkname.lower()]
        if len(network) == 0:
            print('network %s not found' % networkname)
            exit()

    restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryTargetConfig']['recoverToNewSource'] = True
    restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryTargetConfig']['newSourceConfig'] = {
        "sourceType": "kVCenter",
        "vCenterParams": {
            "source": {
                "id": vCenterId
            },
            "networkConfig": {
                "detachNetwork": False,
                "newNetworkConfig": {
                    "disableNetwork": True,
                    "preserveMacAddress": False
                }
            },
            "datastores": [
                datastores[0]
            ],
            "resourcePool": {
                "id": resourcePoolId
            },
            "vmFolder": {
                "id": vmFolder[0]['id']
            }
        }
    }

    if preservemacaddress:
        restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryTargetConfig']['newSourceConfig']['vCenterParams']['networkConfig']['newNetworkConfig']['preserveMacAddress'] = True

    if detachnetwork is not True:
        restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryTargetConfig']['newSourceConfig']['vCenterParams']['networkConfig']['newNetworkConfig']['disableNetwork'] = False

    if network is not None:
        restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryTargetConfig']['newSourceConfig']['vCenterParams']['networkConfig']['newNetworkConfig']['networkPortGroup'] = {
            "id": network[0]['id']
        }
else:
    restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryTargetConfig']['originalSourceConfig'] = {
        "networkConfig": {
            "detachNetwork": False,
            "disableNetwork": False
        }
    }
    if detachnetwork:
        restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryTargetConfig']['originalSourceConfig']['networkConfig'] = {
            "detachNetwork": False,
            "disableNetwork": True
        }

if poweron:
    restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['powerOnVms'] = True

if prefix != '':
    prefix = '%s-' % prefix
    restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['renameRecoveredVmsParams'] = {
        'prefix': prefix,
    }
    print('Recovering %s as %s%s...' % (vmname, prefix, vmname))
else:
    print('Recovering %s...' % vmname)

result = api('post', 'data-protect/recoveries', restoreParams, v=2)
