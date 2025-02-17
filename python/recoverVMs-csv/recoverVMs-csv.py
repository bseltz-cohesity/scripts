#!/usr/bin/env python
"""Recover VMs for python version 2025-02-15a"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import csv

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
parser.add_argument('-pre', '--prefix', type=str, default='')
parser.add_argument('-p', '--poweron', action='store_true')
parser.add_argument('-x', '--detachnetwork', action='store_true')
parser.add_argument('-m', '--preservemacaddress', action='store_true')
parser.add_argument('-t', '--recoverytype', type=str, choices=['InstantRecovery', 'CopyRecovery'], default='InstantRecovery')
parser.add_argument('-tn', '--taskname', type=str, default=None)
parser.add_argument('-csv', '--csvfile', type=str, required=True)
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-diff', '--differentialrecovery', action='store_true')
parser.add_argument('-k', '--keepexistingvm', action='store_true')
parser.add_argument('-coe', '--continueoneerror', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-dbg', '--debug', action='store_true')

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
prefix = args.prefix
poweron = args.poweron
detachnetwork = args.detachnetwork
preservemacaddress = args.preservemacaddress
recoverytype = args.recoverytype
taskname = args.taskname
csvfile = args.csvfile
overwrite = args.overwrite
diff = args.differentialrecovery
keep = args.keepexistingvm
continueoneerror = args.continueoneerror
debug = args.debug

now = datetime.now()

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

csvgroups = {}
vmnames = []
thiscsv = open(csvfile)
reader = csv.DictReader(thiscsv)
for row in reader:
    thisGroupName = '%s-%s-%s-%s-%s-%s' % (row['vcenter'], row['datacenter'], row['host'], row['folder'], row['network'], row['datastore'])
    if thisGroupName not in csvgroups.keys():
        csvgroups[thisGroupName] = {
            "vcenter": row['vcenter'],
            "datacenter": row['datacenter'],
            "host": row['host'],
            "folder": row['folder'],
            "network": row['network'],
            "datastore": row['datastore'],
            "vms": []
        }
    thisGroup = csvgroups[thisGroupName]
    thisGroup['vms'].append(row['vm_name'])
    vmnames.append(row['vm_name'])
# display(csvgroups)

if taskname is None:
    taskname = "Recover-VM_%s" % now.strftime("%Y-%m-%d_%H-%M-%S")

vcentercache = {}
datastorecache = {}
networkcache = {}

vCenterList = api('get', '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter&vmwareEntityTypes=kStandaloneHost')
if vCenterList is None or len(vCenterList) == 0:
    print('no vCenters found')
    exit(1)


def recoverVMs(thisGroup):
    global overwrite
    global prefix
    global debug
    theseVMnames = thisGroup['vms']
    vcentername = thisGroup['vcenter']
    datacentername = thisGroup['datacenter']
    vhost = thisGroup['host']
    datastorenames = [thisGroup['datastore']]
    networkname = thisGroup['network']
    foldername = thisGroup['folder']
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

    if continueoneerror is True:
        restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['continueOnError'] = True

    # overwrite options
    if keep is True:
        restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['powerOffAndRenameExistingVm'] = True
    else:
        if recoverytype == 'CopyRecovery' and diff is True:
            overwrite = True
            restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['attemptDifferentialRestore'] = True
        if overwrite is True:
            restoreParams['vmwareParams']['recoverVmParams']['vmwareTargetParams']['overwriteExistingVm'] = True

    recoverMessages = []

    for vmname in sorted(theseVMnames):
        # find the VM to recover
        if debug:
            print('* finding VM %s' % vmname)
        vms = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=%s&environments=kVMware' % vmname, v=2)
        vms = [vm for vm in vms['objects'] if vm['name'].lower() == vmname.lower()]
        if len(vms) == 0:
            print('vm %s not found' % vmname)
            return None

        # select a snapshot
        selectedsnapshot = None
        for vm in vms:
            if debug:
                print('* finding snapshots for VM %s' % vmname)
            snapshots = api('get', 'data-protect/objects/%s/snapshots' % vm['id'], v=2)
            for snapshot in sorted(snapshots['snapshots'], key=lambda s: s['runStartTimeUsecs'], reverse=True):
                selectedsnapshot = snapshot
                break

        if selectedsnapshot is None:
            print('warning: no recovery point found for %s' % vmname)
            continue
        else:
            recoverMessages.append('Recovering %s' % vmname)
            restoreParams['vmwareParams']['objects'].append({
                "snapshotId": selectedsnapshot['id']
            })

    if len(restoreParams['vmwareParams']['objects']) == 0:
        print('No VMs ready for restore')
        return None

    if vcentername:
        # select vCenter
        vCenter = [v for v in vCenterList if v['displayName'].lower() == vcentername.lower()]
        if len(vCenter) == 0:
            print('vCenter %s not found' % vcentername)
            return None
        vCenterId = vCenter[0]['id']
        if str(vCenterId) in vcentercache.keys():
            vCenterSources = vcentercache[str(vCenterId)]
        else:
            if debug is True:
                print('* getting vcenter')
            vCenterSources = api('get', 'protectionSources?id=%s&environments=kVMware&includeVMFolders=true&excludeTypes=kDatastore,kVirtualMachine,kVirtualApp,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&useCachedData=true' % vCenterId)
            vcentercache[str(vCenterId)] = vCenterSources
        if vCenterSources is None or len(vCenterSources) == 0:
            print('vCenter %s not found' % vcentername)
            return None
        vCenterSource = [v for v in vCenterSources if v['protectionSource']['name'].lower() == vcentername.lower()]
        if len(vCenterSource) == 0 or len(vCenter) == 0:
            print('vCenter %s not found' % vcentername)
            return None
        vCenterId = vCenter[0]['id']

        # select data center
        dataCenterSource = [d for d in vCenterSource[0]['nodes'][0]['nodes'] if d['protectionSource']['name'].lower() == datacentername.lower()]
        if len(dataCenterSource) == 0:
            print('Datacenter %s not found' % datacentername)
            return None

        # select host
        hostSource = [h for h in dataCenterSource[0]['nodes'][0]['nodes'] if h['protectionSource']['name'].lower() == vhost.lower()]
        if len(hostSource) == 0:
            print('Host %s not found' % vhost)
            return None

        # select resource pool
        resourcePoolSource = [r for r in hostSource[0]['nodes'] if r['protectionSource']['vmWareProtectionSource']['type'] == 'kResourcePool']
        resourcePoolId = resourcePoolSource[0]['protectionSource']['id']

        # select datastore
        dsid = '%s=%s' % (resourcePoolId, vCenterId)
        if dsid in datastorecache.keys():
            datastores = datastorecache[dsid]
        else:
            if debug is True:
                print('* getting datastore')
            datastores = [d for d in api('get', '/datastores?resourcePoolId=%s&vCenterId=%s' % (resourcePoolId, vCenterId)) if d['vmwareEntity']['name'].lower() in [d.lower() for d in datastorenames]]
            datastorecache[dsid] = datastores
        if len(datastores) < len(datastorenames):
            for datastorename in datastorenames:
                founddatastore = [d for d in datastores if d['displayName'].lower() == datastorename.lower()]
                if founddatastore is None or len(founddatastore) == 0:
                    print('Datastore %s not found' % datastorename)
            return None

        vmFolderId = {}

        def walkVMFolders(node, parent=None, fullPath=''):
            fullPath = "%s/%s" % (fullPath, node['protectionSource']['name'].lower())
            if '/vm' in fullPath and node['protectionSource']['vmWareProtectionSource']['type'] == 'kFolder':
                vmFolderId[fullPath] = node['protectionSource']['id']
                vmFolderId["%s" % fullPath[1:]] = node['protectionSource']['id']
                if len(fullPath.split('vm/')) > 1:
                    relativePath = fullPath.split('vm/', 2)[1]
                    vmFolderId[relativePath] = node['protectionSource']['id']
                    vmFolderId["/%s" % relativePath] = node['protectionSource']['id']
            if 'nodes' in node:
                for subnode in node['nodes']:
                    walkVMFolders(subnode, node, fullPath)

        walkVMFolders(dataCenterSource[0])
        if foldername is None:
            foldername = '/%s/vm' % datacentername.lower()
        folderId = vmFolderId.get(foldername.lower(), None)
        if folderId is None:
            print('folder %s not found' % foldername)
            return None

        # select network
        network = None
        if networkname is not None:
            netid = '%s-%s' % (resourcePoolId, vCenterId)
            if netid in networkcache.keys():
                network = networkcache[netid]
            else:
                if debug is True:
                    print('* getting network')
                network = [n for n in api('get', '/networkEntities?resourcePoolId=%s&vCenterId=%s' % (resourcePoolId, vCenterId)) if n['displayName'].lower() == networkname.lower()]
                networkcache[netid] = network
            if len(network) == 0:
                print('network %s not found' % networkname)
                return None

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
                "datastores": datastores,
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

    for recoverMessage in recoverMessages:
        print(recoverMessage)

    if debug:
        print('* submitting recovery task')
    recovery = api('post', 'data-protect/recoveries', restoreParams, v=2)

    if 'id' not in recovery:
        print('recovery error occured')
        if 'messages' in recovery and len(recovery['messages']) > 0:
            print(recovery['messages'][0])


for thisGroupName in csvgroups.keys():
    thisGroup = csvgroups[thisGroupName]
    recoverVMs(thisGroup)
