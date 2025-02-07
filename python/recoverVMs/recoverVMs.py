#!/usr/bin/env python
"""Recover VMs for python version 2025-02-06a"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep

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
parser.add_argument('-f', '--foldername', type=str, default=None)
parser.add_argument('-n', '--networkname', type=str, default=None)
parser.add_argument('-s', '--datastorename', action='append', type=str, default=None)
parser.add_argument('-pre', '--prefix', type=str, default='')
parser.add_argument('-p', '--poweron', action='store_true')
parser.add_argument('-x', '--detachnetwork', action='store_true')
parser.add_argument('-m', '--preservemacaddress', action='store_true')
parser.add_argument('-t', '--recoverytype', type=str, choices=['InstantRecovery', 'CopyRecovery'], default='InstantRecovery')
parser.add_argument('-l', '--listrecoverypoints', action='store_true')
parser.add_argument('-r', '--recoverypoint', type=str, default=None)
parser.add_argument('-nt', '--newerthanhours', type=int, default=None)
parser.add_argument('-tn', '--taskname', type=str, default=None)
parser.add_argument('-j', '--jobname', type=str, default=None)
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-diff', '--differentialrecovery', action='store_true')
parser.add_argument('-k', '--keepexistingvm', action='store_true')
parser.add_argument('-coe', '--continueoneerror', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')

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
datastorenames = args.datastorename
prefix = args.prefix
poweron = args.poweron
detachnetwork = args.detachnetwork
preservemacaddress = args.preservemacaddress
recoverytype = args.recoverytype
listrecoverypoints = args.listrecoverypoints
recoverypoint = args.recoverypoint
newerthanhours = args.newerthanhours
taskname = args.taskname
jobname = args.jobname
overwrite = args.overwrite
diff = args.differentialrecovery
keep = args.keepexistingvm
continueoneerror = args.continueoneerror
wait = args.wait

if vcentername is not None:
    if datacentername is None:
        print('datacentername is required')
        exit()
    if vhost is None:
        print('vhost is required')
        exit()
    if datastorenames is None or len(datastorenames) == 0:
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


now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
if recoverypoint is not None:
    recoverypointUsecs = dateToUsecs(recoverypoint)
else:
    recoverypointUsecs = nowUsecs
if newerthanhours is not None:
    newerthanUsecs = nowUsecs - (newerthanhours * 3600000000)

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

if jobname is not None:
    jobs = api('get', 'protectionJobs?environments=kVMware')
    if jobs is not None:
        job = [j for j in jobs if j['name'].lower() == jobname.lower()]
        if len(job) == 0:
            print('protection group %s not found' % jobname)
            exit(1)
        search = api('get', '/searchvms?jobIds=%s' % job[0]['id'])
        vmnames = [o['vmDocument']['objectName'] for o in search['vms']]
    else:
        print('protection group %s not found' % jobname)
        exit(1)

vmnames = gatherList(vmnames, vmlist, name='VMs', required=True)

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

for vmname in sorted(vmnames):
    # find the VM to recover
    vms = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=%s&environments=kVMware' % vmname, v=2)
    vms = [vm for vm in vms['objects'] if vm['name'].lower() == vmname.lower()]
    if len(vms) == 0:
        print('vm %s not found' % vmname)
        exit(1)

    # select a snapshot
    selectedsnapshot = None
    for vm in vms:
        snapshots = api('get', 'data-protect/objects/%s/snapshots' % vm['id'], v=2)
        if newerthanhours is not None:
            snapshots['snapshots'] = [s for s in snapshots['snapshots'] if s['runStartTimeUsecs'] >= newerthanUsecs]
            # if len(snapshots['snapshots']) == 0:
            #     print('warning: no backups for VM %s in the last %s hours' % (vmname, newerthanhours))
            #     continue
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
        exit(0)

    if selectedsnapshot is None:
        if newerthanhours is not None:
            print('warning: no backups for VM %s in the last %s hours' % (vmname, newerthanhours))
        else:
            print('warning: no recovery point found for %s at %s' % (vmname, usecsToDate(recoverypointUsecs)))
        continue
    else:
        recoverMessages.append('Recovering %s' % vmname)
        restoreParams['vmwareParams']['objects'].append({
            "snapshotId": selectedsnapshot['id']
        })

if len(restoreParams['vmwareParams']['objects']) == 0:
    print('No VMs ready for restore')
    exit(1)

if vcentername:
    # select vCenter
    vCenterSources = api('get', 'protectionSources?environments=kVMware&includeVMFolders=true')
    if vCenterSources is None:
        print('No vCenter sources found')
        exit(1)
    vCenterSource = [v for v in vCenterSources if v['protectionSource']['name'].lower() == vcentername.lower()]
    vCenterList = api('get', '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter&vmwareEntityTypes=kStandaloneHost')
    vCenter = [v for v in vCenterList if v['displayName'].lower() == vcentername.lower()]
    if len(vCenterSource) == 0 or len(vCenter) == 0:
        print('vCenter %s not found' % vcentername)
        exit(1)
    vCenterId = vCenter[0]['id']

    # select data center
    dataCenterSource = [d for d in vCenterSource[0]['nodes'][0]['nodes'] if d['protectionSource']['name'].lower() == datacentername.lower()]
    if len(dataCenterSource) == 0:
        print('Datacenter %s not found' % datacentername)
        exit(1)

    # select host
    hostSource = [h for h in dataCenterSource[0]['nodes'][0]['nodes'] if h['protectionSource']['name'].lower() == vhost.lower()]
    if len(hostSource) == 0:
        print('Host %s not found' % vhost)
        exit(1)

    # select resource pool
    resourcePoolSource = [r for r in hostSource[0]['nodes'] if r['protectionSource']['vmWareProtectionSource']['type'] == 'kResourcePool']
    resourcePoolId = resourcePoolSource[0]['protectionSource']['id']
    resourcePool = [r for r in api('get', '/resourcePools?vCenterId=%s' % vCenterId) if r['resourcePool']['id'] == resourcePoolId]
    resourcePool = resourcePool[0]

    # select datastore
    datastores = [d for d in api('get', '/datastores?resourcePoolId=%s&vCenterId=%s' % (resourcePoolId, vCenterId)) if d['vmwareEntity']['name'].lower() in [d.lower() for d in datastorenames]]
    if len(datastores) < len(datastorenames):
        for datastorename in datastorenames:
            founddatastore = [d for d in datastores if d['displayName'].lower() == datastorename.lower()]
            if founddatastore is None or len(founddatastore) == 0:
                print('Datastore %s not found' % datastorename)
        exit(1)

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
        exit(1)

    # select network
    network = None
    if networkname is not None:
        network = [n for n in api('get', '/networkEntities?resourcePoolId=%s&vCenterId=%s' % (resourcePoolId, vCenterId)) if n['displayName'].lower() == networkname.lower()]
        if len(network) == 0:
            print('network %s not found' % networkname)
            exit(1)

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

recovery = api('post', 'data-protect/recoveries', restoreParams, v=2)

# wait for restores to complete
finishedStates = ['Canceled', 'Succeeded', 'Failed']
if 'id' not in recovery:
    print('recovery error occured')
    if 'messages' in recovery and len(recovery['messages']) > 0:
        print(recovery['messages'][0])
    exit(1)

if wait is True:
    print("Waiting for recoveries to complete...")
    while 1:
        sleep(30)
        recoveryTask = api('get', 'data-protect/recoveries/%s?includeTenants=true' % recovery['id'], v=2)
        status = recoveryTask['status']
        if status is not None and status in finishedStates:
            break
    print("Recoveries ended with status: %s" % status)
    if status == 'Failed':
        if 'messages' in recoveryTask and len(recoveryTask['messages']) > 0:
            print(recoveryTask['messages'][0])
    if status == 'Succeeded':
        exit(0)
    else:
        exit(1)
exit(0)
