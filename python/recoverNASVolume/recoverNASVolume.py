#!/usr/bin/env python
"""base V2 example"""

# import pyhesity wrapper module
from pyhesity import *
from time import sleep
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--sourcevolume', type=str, required=True)
parser.add_argument('-sn', '--sourcename', type=str, default=None)
parser.add_argument('-tv', '--targetvolume', type=str, default=None)
parser.add_argument('-tn', '--targetname', type=str, default=None)
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-l', '--showversions', action='store_true')
parser.add_argument('-av', '--asview', action='store_true')
parser.add_argument('-vn', '--viewname', type=str, default=None)
parser.add_argument('-smb', '--smbview', action='store_true')
parser.add_argument('-fc', '--fullcontrol', action='append', type=str)
parser.add_argument('-rw', '--readwrite', action='append', type=str)
parser.add_argument('-ro', '--readonly', action='append', type=str)
parser.add_argument('-mod', '--modify', action='append', type=str)
parser.add_argument('-ip', '--ips', action='append', type=str)
parser.add_argument('-il', '--iplist', type=str)
parser.add_argument('-rs', '--rootsquash', action='store_true')
parser.add_argument('-as', '--allsquash', action='store_true')
parser.add_argument('-ir', '--ipsreadonly', action='store_true')
parser.add_argument('-ri', '--runid', type=int, default=None)
parser.add_argument('-st', '--sleeptime', type=int, default=30)
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
emailmfacode = args.emailmfacode
sourcevolume = args.sourcevolume
sourcename = args.sourcename
targetvolume = args.targetvolume
targetname = args.targetname
overwrite = args.overwrite
showversions = args.showversions
asview = args.asview
runid = args.runid
viewname = args.viewname
smbview = args.smbview
fullcontrol = args.fullcontrol
readwrite = args.readwrite
readonly = args.readonly
modify = args.modify
ips = args.ips
iplist = args.iplist
rootsquash = args.rootsquash
allsquash = args.allsquash
ipsreadonly = args.ipsreadonly
sleeptime = args.sleeptime
wait = args.wait

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

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


ips = gatherList(ips, iplist, name='cidrs', required=False)


def addPermission(user, perms):
    sid = None
    if user.lower() == 'everyone':
        sid = 'S-1-1-0'
    elif '\\' in user:
        (workgroup, user) = user.split('\\')
        # find domain
        adDomain = [a for a in ads if a['workgroup'].lower() == workgroup.lower() or a['domainName'].lower() == workgroup.lower()]
        if adDomain is None or len(adDomain) == 0:
            print('domain %s not found' % workgroup)
            exit(1)
        else:
            # find domain princlipal/sid
            domainName = adDomain[0]['domainName']
            principal = api('get', 'activeDirectory/principals?domain=%s&includeComputers=true&search=%s' % (domainName, user))
            if principal is None or len(principal) == 0:
                print('Principal "%s" not found' % (workgroup, user))
            else:
                sid = principal[0]['sid']
    else:
        # find local or wellknown sid
        principal = api('get', 'activeDirectory/principals?includeComputers=true&search=%s' % user)
        if principal is None or len(principal) == 0:
            print('Principal "%s" not found' % user)
        else:
            sid = principal[0]['sid']
    if sid is not None:
        permission = {       
            "sid": sid,
            "type": "Allow",
            "mode": "FolderOnly",
            "access": perms
        }
        return permission
    else:
        exit(1)


def newWhiteListEntry(cidr, perm):
    (ip, netbits) = cidr.split('/')
    if netbits is None:
        netbits = '32'

    whitelistEntry = {
        "nfsAccess": perm,
        "smbAccess": perm,
        "s3Access": perm,
        "ip": ip,
        "netmaskBits": int(netbits),
        "description": ''
    }
    if allsquash:
        whitelistEntry['nfsAllSquash'] = True
    if rootsquash:
        whitelistEntry['nfsRootSquash'] = True
    return whitelistEntry


def applyViewSettings():
    global sharePermissions
    updateView = False
    if len(ips) > 0 or smbview:
        newView = [v for v in (api('get', 'file-services/views?viewNames=%s' % viewname, v=2))['views'] if v['name'] == viewname][0]
        newView['category'] = 'FileServices'
        if smbview:
            del newView['nfsMountPaths']
            newView['enableSmbViewDiscovery'] = True
            if 'versioning' in newView:
                del newView['versioning']
            newView['protocolAccess'] = [
                {
                    "type": "SMB",
                    "mode": "ReadWrite"
                }
            ]
            newView['sharePermissions'] = {'permissions': sharePermissions}
        if len(ips) > 0:
            newView['subnetWhitelist'] = []
            perm = 'kReadWrite'
            if readonly:
                perm = 'kReadOnly'
            for cidr in ips:
                (ip, netbits) = cidr.split('/')
                newView['subnetWhitelist'] = [w for w in newView['subnetWhitelist'] if w['ip'] != ip]
                newView['subnetWhitelist'].append(newWhiteListEntry(cidr, perm))
            newView['subnetWhitelist'] = [w for w in newView['subnetWhitelist'] if w is not None]
        result = api('put', 'file-services/views/%s' % newView['viewId'], newView, v=2)
performOverwrite = False
if overwrite:
    performOverwrite = True

# find source volume
search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverNasVolume,RecoverSanVolumes&searchString=%s&environments=kNetapp,kIsilon,kGenericNas,kFlashBlade,kGPFS,kElastifile,kPure' % sourcevolume, v=2)
if 'objects' in search and search['objects'] is not None:
    objects = [o for o in search['objects'] if o['name'].lower() == sourcevolume.lower()]
    if objects is None or len(objects) == 0:
        print('NAS volume %s not found' % sourcevolume)
        exit(1)
    if sourcename:
        objects = [o for o in objects if 'sourceInfo' in o and o['sourceInfo'] is not None and 'name' in o['sourceInfo'] and o['sourceInfo']['name'].lower() == sourcename.lower()]
    if objects is None or len(objects) == 0:
        print('NAS volume %s not found on %s' % (sourcevolume, sourcename))
        exit(1)

# find snapshots
allSnapshots = []
for object in objects:
    snapshots = api('get', 'data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (object['id'], object['latestSnapshotsInfo'][0]['protectionGroupId']), v=2)
    if snapshots is not None and 'snapshots' in snapshots and snapshots['snapshots'] is not None:
        allSnapshots = allSnapshots + snapshots['snapshots']

if len(allSnapshots) == 0:
    print('No snapshots found for %s' % sourcevolume)

if showversions:
    for snapshot in allSnapshots:
        print('%s: %s (%s)' % (usecsToDate(snapshot['runStartTimeUsecs'], snapshot['runInstanceId'], snapshot['snapshotTargetType'])))
    exit()

if runid:
    thisSnapshot = [s for s in allSnapshots if s['runInstanceId'] == runid]
    if thisSnapshot is None or len(thisSnapshot) == 0:
        print('No snapshot found for %s with runId %s' % (sourcevolume, runid))
        exit(1)
else:
    thisSnapshot = allSnapshots[1]
restoreTaskName = "Recover_Storage_Volumes_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

# recover as view
sharePermissionsApplied = False
sharePermissions = []
ads = api('get', 'activeDirectory')

if asview:
    wait = True
    sleeptime = 5
    if readwrite is None:
        readwrite = []
    if fullcontrol is None: 
        fullcontrol = []
    if readonly is None:
        readonly = []
    if modify is None:
        modify = []
    if smbview:
        for user in readwrite:
            sharePermissionsApplied = True
            sharePermissions.append(addPermission(user, 'ReadWrite'))
        for user in fullcontrol:
            sharePermissionsApplied = True
            sharePermissions.append(addPermission(user, 'FullControl'))
        for user in readonly:
            sharePermissionsApplied = True
            sharePermissions.append(addPermission(user, 'ReadOnly'))
        for user in modify:
            sharePermissionsApplied = True
            sharePermissions.append(addPermission(user, 'Modify'))
        if sharePermissionsApplied is False:
            sharePermissions.append(addPermission('Everyone', 'FullControl'))
    if viewname is None:
        viewname = (sourcevolume.split('\\')[-1]).split('/')[-1]

    recoveryParams = {
        "name": restoreTaskName,
        "snapshotEnvironment": thisSnapshot['environment'],
        "genericNasParams": {
            "objects": [
                {
                    "snapshotId": thisSnapshot['id']
                }
            ],
            "recoveryAction": "RecoverNasVolume",
            "recoverNasVolumeParams": {
                "targetEnvironment": "kView",
                "viewTargetParams": {
                    "viewName": viewname,
                    "qosPolicy": {
                        "id": 6,
                        "name": "TestAndDev High",
                        "priority": "kHigh",
                        "weight": 320,
                        "workLoadType": "TestAndDev",
                        "minRequests": 10,
                        "seqWriteSsdPct": 100,
                        "seqWriteHydraPct": 100
                    }
                }
            }
        }
    }
else:
    # recovery params
    paramsName = [k for k in thisSnapshot.keys() if 'Params' in k][0]
    targetParamsName = '%s%sTargetParams' % (thisSnapshot['environment'][1:2].lower(), thisSnapshot['environment'][2:])
    recoveryParams = {
        "name": restoreTaskName,
        "snapshotEnvironment": thisSnapshot['environment'],
        paramsName: {
            "objects": [
                {
                    "snapshotId": thisSnapshot['id']
                }
            ],
            "recoveryAction": "RecoverNasVolume",
            "recoverNasVolumeParams": {
                "targetEnvironment": thisSnapshot['environment'],
                targetParamsName: {
                    "recoverToNewSource": False,
                    "originalSourceConfig": {
                        "overwriteExistingFile": performOverwrite,
                        "preserveFileAttributes": True,
                        "continueOnError": True,
                        "encryptionEnabled": False
                    }
                }
            }
        }
    }

    # find target volume
    if targetvolume:
        targets = api('get', 'protectionSources/rootNodes?environments=kNetapp,kIsilon,kGenericNas,kFlashBlade,kGPFS,kElastifile,kPure')
        if targets is not None and len(targets) > 0 and targetname:
            targets = [t for t in targets if t['protectionSource']['name'].lower() == targetname.lower()]
        if targets is None or len(targets) == 0:
            print('target %s not found' % targetname)
            exit(1)

        foundVolumes = []
        for target in targets:
            sources = api('get', 'protectionSources?useCachedData=false&id=%s&allUnderHierarchy=false' % target['protectionSource']['id'])
            for source in sources:
                for node in source['nodes']:
                    if 'nodes' in node:
                        for subnode in node['nodes']:
                            if subnode['protectionSource']['name'].lower() == targetvolume.lower():
                                foundVolumes.append(subnode)
                    elif node['protectionSource']['name'].lower() == targetvolume.lower():
                        foundVolumes.append(node)

        if len(foundVolumes) == 0:
            print('Target volume %s not found' % targetvolume)
            exit(1)
        elif len(foundVolumes) > 1:
            print('More than one target volume found. Please specify -tn, --targetname')
            exit(1)

        # alternate target recovery params
        recoveryParams[paramsName]['recoverNasVolumeParams'] = {
            "targetEnvironment": foundVolumes[0]['protectionSource']['environment'],
            targetParamsName: {
                "recoverToNewSource": True,
                "newSourceConfig": {
                    "volume": {
                        "id": foundVolumes[0]['protectionSource']['id']
                    },
                    "overwriteExistingFile": performOverwrite,
                    "preserveFileAttributes": True,
                    "continueOnError": True,
                    "encryptionEnabled": False
                }
            }
        }
print('Recovering %s' % sourcevolume)
recovery = api('post', 'data-protect/recoveries', recoveryParams, v=2)

# wait for restores to complete
finishedStates = ['Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning']
if 'id' not in recovery:
    print('an error occurred')
    exit(1)

if wait:
    print('Waiting for recovery to complete')
    status = 'unknown'
    while status not in finishedStates:
        sleep(sleeptime)
        recoveryTask = api('get', 'data-protect/recoveries/%s?includeTenants=true' % recovery['id'], v=2)
        status = recoveryTask['status']
    print('Recovery task finished with status: %s' % status)
    if status in ['Failed', 'SucceededWithWarning']:
        if 'messages' in recoveryTask and recoveryTask['messages'] is not None and len(recoveryTask['messages']) > 0:
            print('%s', recoveryTask['messages'][0])
    if status == 'Succeeded':
        if asview:
            applyViewSettings()
        exit(0)
    else:
        exit(1)
exit(0)
