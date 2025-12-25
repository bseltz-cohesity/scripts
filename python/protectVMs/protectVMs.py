#!/usr/bin/env python
"""protect VMware VMs Using Python"""

### import pyhesity wrapper module
from pyhesity import *

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
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-n', '--vmname', action='append', type=str)
parser.add_argument('-l', '--vmlist', type=str)
parser.add_argument('-vc', '--vcentername', type=str, default=None)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-ei', '--enableindexing', action='store_true')

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
emailmfacode = args.emailmfacode
jobname = args.jobname
vmname = args.vmname
vmlist = args.vmlist
vcentername = args.vcentername
storagedomain = args.storagedomain
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
pause = args.pause
enableindexing = args.enableindexing


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


vmnames = gatherList(vmname, vmlist, name='VMs', required=True)

if pause:
    isPaused = True
else:
    isPaused = False

if enableindexing:
    indexingEnabled = True
else:
    indexingEnabled = False

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

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

# get vCenter protection source
vcenters = api('get', 'protectionSources/rootNodes?environments=kVMware')

# find existing job
job = None
jobs = api('get', 'data-protect/protection-groups?environments=kVMware&pruneSourceIds=true&pruneExcludedSourceIds=true&isActive=true&isDeleted=false&useCachedData=true', v=2)
if jobs is not None and 'protectionGroups' in jobs and jobs['protectionGroups'] is not None and len(jobs['protectionGroups']) > 0:
    jobs = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if jobs is not None and len(jobs) > 0:
        job = jobs[0]

if job is not None:
    newJob = False
    vcenter = [v for v in vcenters if v['protectionSource']['id'] == job['vmwareParams']['sourceId']][0]

else:
    # new job
    newJob = True

    # get vcenter
    if vcentername is None:
        print('vcentername required')
        exit(1)
    else:
        vcenter = [v for v in vcenters if v['protectionSource']['name'].lower() == vcentername.lower()]
        if not vcenters or len(vcenters) == 0:
            print('vCenter %s not registered' % vcentername)
            exit(1)
        else:
            vcenter = vcenters[0]

    # get policy
    if policyname is None:
        print('Policy name required')
        exit(1)
    else:
        policy = [p for p in (api('get', 'data-protect/policies', v=2))['policies'] if p['name'].lower() == policyname.lower()]
        if policy is None or len(policy) == 0:
            print('Policy %s not found' % policyname)
            exit(1)
        else:
            policy = policy[0]

    # get storageDomain
    viewBoxId = None
    if 'primaryBackupTarget' not in policy['backupPolicy']['regular'] or policy['backupPolicy']['regular']['primaryBackupTarget']['targetType'] != 'Archival':
        viewBox = [v for v in api('get', 'viewBoxes') if v['name'].lower() == storagedomain.lower()]
        if viewBox is None or len(viewBox) == 0:
            print('Storage Domain %s not found' % storagedomain)
            exit(1)
        else:
            viewBox = viewBox[0]
            viewBoxId = viewBox['id']

    # parse starttime
    try:
        (hour, minute) = starttime.split(':')
        hour = int(hour)
        minute = int(minute)
        if hour < 0 or hour > 23 or minute < 0 or minute > 59:
            print('starttime is invalid!')
            exit(1)
    except Exception:
        print('starttime is invalid!')
        exit(1)

    # new job params
    job = {
        "name": jobname,
        "environment": "kVMware",
        "isPaused": isPaused,
        "policyId": policy['id'],
        "priority": "kMedium",
        "storageDomainId": viewBoxId,
        "description": "",
        "startTime": {
            "hour": hour,
            "minute": minute,
            "timeZone": timezone
        },
        "abortInBlackouts": False,
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "sla": [
            {
                "backupRunType": "kFull",
                "slaMinutes": fullsla
            },
            {
                "backupRunType": "kIncremental",
                "slaMinutes": incrementalsla
            }
        ],
        "qosPolicy": "kBackupHDD",
        "vmwareParams": {
            "sourceId": vcenter['protectionSource']['id'],
            "objects": [],
            "excludeObjectIds": [],
            "vmTagIds": [],
            "excludeVmTagIds": [],
            "appConsistentSnapshot": False,
            "fallbackToCrashConsistentSnapshot": False,
            "skipPhysicalRDMDisks": False,
            "globalExcludeDisks": [],
            "leverageHyperflexSnapshots": False,
            "leverageStorageSnapshots": False,
            "cloudMigration": False,
            "indexingPolicy": {
                "enableIndexing": indexingEnabled,
                "includePaths": [
                    "/"
                ],
                "excludePaths": [
                    "/$Recycle.Bin",
                    "/Windows",
                    "/Program Files",
                    "/Program Files (x86)",
                    "/ProgramData",
                    "/System Volume Information",
                    "/Users/*/AppData",
                    "/Recovery",
                    "/var",
                    "/usr",
                    "/sys",
                    "/proc",
                    "/lib",
                    "/grub",
                    "/grub2",
                    "/opt/splunk",
                    "/splunk"
                ]
            }
        }
    }

vms = api('get', 'protectionSources/virtualMachines?id=%s' % vcenter['protectionSource']['id'])
for thisvmname in vmnames:
    thisvm = [v for v in vms if v['name'].lower() == thisvmname.lower()]
    if thisvm is not None and len(thisvm) > 0:
        if len(thisvm) > 1:
            print('*** found duplicate VM names, protecing all...')
        for vm in thisvm:
            if vm['id'] not in [o['id'] for o in job['vmwareParams']['objects']]:
                newobject = {
                    "excludeDisks": None,
                    "id": vm['id'],
                    "name": vm['name'],
                    "isAutoprotected": False
                }
                job['vmwareParams']['objects'].append(newobject)
            print('    protecting %s' % thisvmname)
    else:
        print('    warning: %s not found' % thisvmname)

# create or update job
if newJob is True:
    print('Creating protection job %s' % jobname)
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print('Updating protection job %s' % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
