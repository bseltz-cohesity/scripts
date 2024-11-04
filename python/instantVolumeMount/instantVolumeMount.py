#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
from time import sleep
import getpass
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-o', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-s', '--sourceserver', type=str, required=True)
parser.add_argument('-t', '--targetserver', type=str, default=None)
parser.add_argument('-vis', '--hypervisor', type=str, default=None)
parser.add_argument('-e', '--environment', type=str, choices=['kVMware', 'kPhysical', 'kHyperV'], default=None)
parser.add_argument('-id', '--id', type=int, default=None)
parser.add_argument('-r', '--runid', type=str, default=None)
parser.add_argument('-date', '--date', type=str, default=None)
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-sh', '--showversions', action='store_true')
parser.add_argument('-sv', '--showvolumes', action='store_true')
parser.add_argument('-vol', '--volumes', action='append', type=str)
parser.add_argument('-a', '--useexistingagent', action='store_true')
parser.add_argument('-vu', '--vmusername', type=str, default=None)
parser.add_argument('-vp', '--vmpassword', type=str, default=None)
parser.add_argument('-debug', '--debug', action='store_true')
parser.add_argument('-x', '--usearchive', action='store_true')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
sourceserver = args.sourceserver
targetserver = args.targetserver
hypervisor = args.hypervisor
environment = args.environment
id = args.id
runid = args.runid
date = args.date
wait = args.wait
showversions = args.showversions
showvolumes = args.showvolumes
volumes = args.volumes
useexistingagent = args.useexistingagent
vmusername = args.vmusername
vmpassword = args.vmpassword
debug = args.debug
usearchive = args.usearchive


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


# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)

now = datetime.now()

existingAgent = False
if useexistingagent is True:
    existingAgent = True

# search for source object
search = api('get', 'data-protect/search/protected-objects?snapshotActions=InstantVolumeMount&searchString=%s&environments=kVMware,kPhysical,kHyperV' % sourceserver, v=2)
search['objects'] = [o for o in search['objects'] if o['name'].lower() == sourceserver.lower()]

if environment is not None:
    search['objects'] = [o for o in search['objects'] if o['environment'].lower() == environment.lower()]
elif search['objects'] is not None and len(search['objects']) > 0:
    environment = search['objects'][0]['environment']

if id is not None:
    search['objects'] = [o for o in search['objects'] if o['id'] == id]

if search['objects'] is None or len(search['objects']) == 0:
    print('%s not found' % sourceserver)
    exit()

if len(search['objects']) > 1:
    print('multiple objects found, use the --environement or --id parameters to narrow the results')
    for object in search['objects']:
        print('%s: %s (%s)' % (object['id'], object['name'], object['environment']))
    exit()
else:
    objectId = search['objects'][0]['id']
    targetSourceId = search['objects'][0]['sourceInfo']['id']

# get list of available snapshots
snapshots = api('get', 'data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (objectId, ','.join([s['protectionGroupId'] for s in search['objects'][0]['latestSnapshotsInfo']])), v=2)
if usearchive is True:
    snapshots['snapshots'] = [s for s in snapshots['snapshots'] if s['snapshotTargetType'] != 'Local']
else:
    snapshots['snapshots'] = [s for s in snapshots['snapshots'] if s['snapshotTargetType'] == 'Local']

if runid is not None:
    snapshots['snapshots'] = [s for s in snapshots['snapshots'] if str(s['runInstanceId']) == runid or s['protectionGroupRunId'] == runid]

if date is not None:
    dateUsecs = (dateToUsecs(date)) + 60000000
    snapshots['snapshots'] = [s for s in snapshots['snapshots'] if s['runStartTimeUsecs'] <= dateUsecs]

if len(snapshots['snapshots']) == 0:
    print('no snapshots available')
    exit()

if showversions:
    for snapshot in sorted(snapshots['snapshots'], key=lambda s: s['runStartTimeUsecs'], reverse=True):
        print('%s  %s  (%s)' % (snapshot['runInstanceId'], usecsToDate(snapshot['runStartTimeUsecs']), snapshot['snapshotTargetType']))
    exit()

snapshot = sorted(snapshots['snapshots'], key=lambda s: s['runStartTimeUsecs'], reverse=True)[0]

# volumes
if showvolumes or (volumes is not None and len(volumes) > 0):
    snapVolumes = api('get', 'data-protect/snapshots/%s/volume?includeSupportedOnly=false' % snapshot['id'], v=2)
    if volumes is not None and len(volumes) > 0:
        missingVolumes = [v for v in volumes if v.lower() not in [n['name'].lower() for n in snapVolumes['volumes']]]
        if len(missingVolumes) > 0:
            print('volumes %s not found' % ', '.join(missingVolumes))
            exit()
        snapVolumes['volumes'] = [v for v in snapVolumes['volumes'] if v['name'].lower() in [n.lower() for n in volumes]]

    if showvolumes:
        for volume in snapVolumes['volumes']:
            print(volume['name'])
        exit()

# recovery parameters
targetName = sourceserver
if targetserver:
    targetName = '%s_to_%s' % (sourceserver, targetserver)

recoveryParams = {
    "name": "Recover_%s_%s" % (targetName, now.strftime('%Y-%m-%d_%H:%M:%S')),
    "snapshotEnvironment": environment
}

# vmware params
if environment == 'kVMware':
    recoveryParams["vmwareParams"] = {
        "objects": [
            {
                "snapshotId": snapshot['id']
            }
        ],
        "recoveryAction": "InstantVolumeMount",
        "mountVolumeParams": {
            "targetEnvironment": environment,
            "vmwareTargetParams": {
                "mountToOriginalTarget": True,
                "originalTargetConfig": {
                    "bringDisksOnline": True,
                    "useExistingAgent": existingAgent,
                    "targetVmCredentials": None
                },
                "newTargetConfig": None,
                "readOnlyMount": False,
                "volumeNames": None
            }
        }
    }
    targetParams = recoveryParams['vmwareParams']['mountVolumeParams']['vmwareTargetParams']
    targetConfig = targetParams['originalTargetConfig']

    # alternate target params
    if targetserver and targetserver.lower() != sourceserver.lower():

        # find vCenter
        if hypervisor:
            rootNodes = api('get', 'protectionSources/rootNodes?environments=kVMware')
            if rootNodes is not None and len(rootNodes) > 0:
                rootNodes = [n for n in rootNodes if n['protectionSource']['name'].lower() == hypervisor.lower()]
            if rootNodes is None or len(rootNodes) == 0:
                print('VMware source $hypervisor not found')
                exit()
            else:
                targetSourceId = rootNodes[0]['protectionSource']['id']

        # find VM
        vms = api('get', 'protectionSources/virtualMachines?vCenterId=%s' % targetSourceId)
        vm = [v for v in vms if v['name'].lower() == targetserver.lower()]
        if vm is None or len(vm) == 0:
            print('VM target %s not found' % targetserver)
            exit()

        targetParams['mountToOriginalTarget'] = False
        targetParams['originalTargetConfig'] = None
        targetParams['newTargetConfig'] = {
            "bringDisksOnline": True,
            "useExistingAgent": existingAgent,
            "targetVmCredentials": None,
            "mountTarget": {
                "id": vm[0]['id']
            }
        }
        targetConfig = targetParams['newTargetConfig']

    # vm credentials for autodeploy agent
    if existingAgent is False:
        if vmusername is None:
            print('--vmusername required if not using --useexistingagent')
            exit()
        if vmpassword is None:
            vmpassword = getpass.getpass("Enter password for VM user %s: " % vmusername)
        targetConfig['targetVmCredentials'] = {
            "username": vmusername,
            "password": vmpassword
        }

# physical params
if environment == 'kPhysical':
    recoveryParams["physicalParams"] = {
        "objects": [
            {
                "snapshotId": snapshot['id']
            }
        ],
        "recoveryAction": "InstantVolumeMount",
        "mountVolumeParams": {
            "targetEnvironment": environment,
            "physicalTargetParams": {
                "mountToOriginalTarget": True,
                "originalTargetConfig": {
                    "serverCredentials": None
                },
                "newTargetConfig": None,
                "readOnlyMount": False,
                "volumeNames": None
            }
        }
    }
    targetParams = recoveryParams['physicalParams']['mountVolumeParams']['physicalTargetParams']
    targetConfig = targetParams['originalTargetConfig']

    # alternate target params
    targetId = None
    if targetserver and targetserver.lower() != sourceserver.lower():
        rootNodes = api('get', 'protectionSources?environments=kPhysical')
        if rootNodes is not None and len(rootNodes) > 0 and 'nodes' in rootNodes[0] and rootNodes[0]['nodes'] is not None and len(rootNodes[0]['nodes']) > 0:
            rootNodes = [n for n in rootNodes[0]['nodes'] if n['protectionSource']['name'].lower() == targetserver.lower()]
            if rootNodes is not None and len(rootNodes) > 0:
                targetId = rootNodes[0]['protectionSource']['id']
            else:
                print('physical target %s not found' % targetserver)
                exit()
        else:
            print('x physical target %s not found' % targetserver)
            exit()
        targetParams['mountToOriginalTarget'] = False
        targetParams['originalTargetConfig'] = None
        targetParams['newTargetConfig'] = {
            "serverCredentials": None,
            "mountTarget": {
                "id": targetId
            }
        }

# hyperV params
if environment == 'kHyperV':
    recoveryParams["hypervParams"] = {
        "objects": [
            {
                "snapshotId": snapshot['id']
            }
        ],
        "recoveryAction": "InstantVolumeMount",
        "mountVolumeParams": {
            "targetEnvironment": environment,
            "hypervTargetParams": {
                "mountToOriginalTarget": True,
                "originalTargetConfig": {
                    "bringDisksOnline": True,
                    "targetVmCredentials": None
                },
                "newTargetConfig": None,
                "readOnlyMount": False,
                "volumeNames": None
            }
        }
    }
    targetParams = recoveryParams['hypervParams']['mountVolumeParams']['hypervTargetParams']
    targetConfig = targetParams['originalTargetConfig']

    # alternate target params
    if targetserver and targetserver.lower() != sourceserver.lower():

        # find vCenter
        if hypervisor:
            rootNodes = api('get', 'protectionSources/rootNodes?environments=kHyperV')
            if rootNodes is not None and len(rootNodes) > 0:
                rootNodes = [n for n in rootNodes if n['protectionSource']['name'].lower() == hypervisor.lower()]
            if rootNodes is None or len(rootNodes) == 0:
                print('HyperV source %s not found' % hypervisor)
                exit()
            else:
                targetSourceId = rootNodes[0]['protectionSource']['id']

        # find VM
        sources = api('get', 'protectionSources?id=%s' % targetSourceId)
        thisVMId = getObjectId(targetserver)
        if thisVMId is None:
            print('VM target %s not found' % targetserver)
            exit()

        targetParams['mountToOriginalTarget'] = False
        targetParams['originalTargetConfig'] = None
        targetParams['newTargetConfig'] = {
            "bringDisksOnline": True,
            "targetVmCredentials": None,
            "mountTarget": {
                "id": thisVMId
            }
        }
        targetConfig = targetParams['newTargetConfig']

    # vm credentials for autodeploy agent
    if vmusername is None:
        print('--vmusername required for HyperV VMs')
        exit()
    if vmpassword is None:
        vmpassword = getpass.getpass("Enter password for VM user %s: " % vmusername)
    targetConfig['targetVmCredentials'] = {
        "username": vmusername,
        "password": vmpassword
    }

# specify volumes to mount
if volumes is not None and len(volumes) > 0:
    targetParams['volumeNames'] = [v['name'] for v in snapVolumes['volumes']]

# display(recoveryParams)
# exit()
print('Performing instant volume mount...')
if debug is True:
    display(recoveryParams)
recovery = api('post', 'data-protect/recoveries', recoveryParams, v=2)

# wait
if 'id' in recovery:
    v1TaskId = recovery['id'].split(':')[2]
    print('Task ID for tearDown is: %s' % v1TaskId)
    if wait:
        finishedStates = ['Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning']
        while recovery['status'] not in finishedStates:
            sleep(10)
            recovery = api('get', 'data-protect/recoveries/%s' % recovery['id'], v=2)
        print('Mount operation ended with status: %s' % recovery['status'])
        if recovery['status'] != 'Succeeded':
            exit(1)
        if environment == 'kVMware':
            mounts = recovery['vmwareParams']['mountVolumeParams']['vmwareTargetParams']['mountedVolumeMapping']
        elif environment == 'kPhysical':
            mounts = recovery['physicalParams']['mountVolumeParams']['physicalTargetParams']['mountedVolumeMapping']
        else:
            mounts = recovery['hypervParams']['mountVolumeParams']['hypervTargetParams']['mountedVolumeMapping']
        for mount in mounts:
            print('%s mounted to %s' % (mount['originalVolume'], mount['mountedVolume']))
exit(0)
