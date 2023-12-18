#!/usr/bin/env python
"""Recover VMs for python"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

### command line arguments
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
parser.add_argument('-mfa', '--mfacode', type=str, default=None)
parser.add_argument('-vm', '--vmname', action='append', type=str, default=None)
parser.add_argument('-vl', '--vmlist', type=str, default=None)
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
parser.add_argument('-tn', '--taskname', type=str, default=None)

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
vmnames = args.vmname
vmlist = args.vmlist
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
taskname = args.taskname

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


# gather list function
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


vmnames = gatherList(vmnames, vmlist, name='VMs', required=True)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
if recoverypoint is not None:
    recoverypointUsecs = dateToUsecs(recoverypoint)
else:
    recoverypointUsecs = nowUsecs

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

if taskname is None:
    taskname = "Recover-VM_%s" % now.strftime("%Y-%m-%d_%H-%M-%S")

restoreParams = {
    "name": taskname,
    "snapshotEnvironment": "kVMware",
    "vmwareParams": {
        "objects": [],
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

for vmname in vmnames:
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
                    restoreParams['vmwareParams']['objects'].append({
                        "snapshotId": selectedsnapshot['id']
                    })
                    break

    if listrecoverypoints:
        exit()

    if selectedsnapshot is None:
        print('No recovery point found for %s at %s' % (vmname, usecsToDate(recoverypointUsecs)))
        exit()

if vcentername:
    # select vCenter
    vCenterSource = [v for v in api('get', 'protectionSources?environments=kVMware&includeVMFolders=true') if v['protectionSource']['name'].lower() == vcentername.lower()]
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

    vmFolderId = {}

    def walkVMFolders(node, parent=None, fullPath=''):
        fullPath = "%s/%s" % (fullPath, node['protectionSource']['name'].lower())
        if len(fullPath.split('vm/')) > 1:
            relativePath = fullPath.split('vm/', 2)[1]
            vmFolderId[fullPath] = node['protectionSource']['id']
            vmFolderId[relativePath] = node['protectionSource']['id']
            vmFolderId["/%s" % relativePath] = node['protectionSource']['id']
            vmFolderId["%s" % fullPath[1:]] = node['protectionSource']['id']
        if 'nodes' in node:
            for subnode in node['nodes']:
                walkVMFolders(subnode, node, fullPath)

    walkVMFolders(vCenterSource[0])
    folderId = vmFolderId.get(foldername.lower(), None)
    if folderId is None:
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
                "id": folderId
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

print('Recovering VMs')

result = api('post', 'data-protect/recoveries', restoreParams, v=2)
