#!/usr/bin/env python
"""Auto-protect VMs by Tag Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-vc', '--vcentername', type=str, required=True)
parser.add_argument('-i', '--includetag', action='append', type=str)
parser.add_argument('-e', '--excludetag', action='append', type=str)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-a', '--appconsistent', action='store_true')

args = parser.parse_args()

vip = args.vip                        # cluster name/ip
username = args.username              # username to connect to cluster
domain = args.domain                  # domain of username (e.g. local, or AD domain)
password = args.password              # password or API key
useApiKey = args.useApiKey            # use API key for authentication
jobname = args.jobname                # name of protection job to add server to
vcentername = args.vcentername        # name of vcd source to protect
includetags = args.includetag         # only include vapps that start with this prefix
excludetags = args.excludetag         # exclude vapps that start with this prefix
storagedomain = args.storagedomain    # storage domain for new job
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job
pause = args.pause                    # pause new job
appconsistent = args.appconsistent

if pause:
    isPaused = True
else:
    isPaused = False

if appconsistent:
    appconsistency = True
else:
    appconsistency = False

# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# get vCenter protection source
vcenters = [s for s in api('get', 'protectionSources/rootNodes?environments=kVMware') if s['protectionSource']['name'].lower() == vcentername.lower()]
if not vcenters or len(vcenters) == 0:
    print('vCenter %s not registered' % vcentername)
    exit(1)
else:
    vcenter = vcenters[0]
vcenter = api('get', 'protectionSources?id=%s&environments=kVMware&excludeTypes=kDatastore,kVirtualMachine,kVirtualApp,kStoragePod,kNetwork,kDistributedVirtualPortgroup&useCachedData=true' % vcenter['protectionSource']['id'])
vcenter = vcenter[0]

# get object ID function
def getObjectId(objectName, source):

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

    get_nodes(source)
    return d['_object_id']


# gather include tag IDs
includeTagIds = []
if includetags is not None:
    for tag in includetags:
        tagId = getObjectId(tag, vcenter)
        if tagId is not None:
            includeTagIds.append(tagId)
        else:
            print('tag %s not found' % tag)
            exit(1)

# gather exclude tag IDs
excludeTagIds = []
if excludetags is not None:
    for tag in excludetags:
        tagId = getObjectId(tag, vcenter)
        if tagId is not None:
            excludeTagIds.append(tagId)
        else:
            print('tag %s not found' % tag)
            exit(1)

if excludeTagIds.count == 0 and includetags.count == 0:
    print('No tags specified')
    exit(1)

# find existing job
job = None
jobs = api('get', 'data-protect/protection-groups?environments=kVMware&isDeleted=false&isActive=true', v=2)
if jobs is not None and len(jobs) > 0 and 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
    jobs = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if jobs is not None and len(jobs) > 0:
        job = jobs[0]

if job is not None:
    newJob = False
    if job['vmwareParams']['sourceId'] != vcenter['protectionSource']['id']:
        print('Job %s uses a different vCenter, please use a new or different job' % jobname)
        exit(1)
else:
    # new job
    newJob = True
    if includeTagIds.count == 0:
        print('No include tags specified')
        exit(1)

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
    viewBox = [v for v in api('get', 'viewBoxes') if v['name'].lower() == storagedomain.lower()]
    if viewBox is None or len(viewBox) == 0:
        print('Storage Domain %s not found' % storagedomain)
        exit(1)
    else:
        viewBox = viewBox[0]

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
        "storageDomainId": viewBox['id'],
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
            "objects": [],
            "excludeObjectIds": [],
            "vmTagIds": [],
            "excludeVmTagIds": [],
            "appConsistentSnapshot": appconsistency,
            "fallbackToCrashConsistentSnapshot": False,
            "skipPhysicalRDMDisks": False,
            "globalExcludeDisks": [],
            "leverageHyperflexSnapshots": False,
            "leverageStorageSnapshots": False,
            "cloudMigration": False,
            "indexingPolicy": {
                "enableIndexing": True,
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

# include tags
if len(includeTagIds) > 0:
    if newJob is True:
        job['vmwareParams']['vmTagIds'] = []
    else:
        if 'vmTagIds' not in job['vmwareParams'] or job['vmwareParams']['vmTagIds'] is None:
            job['vmwareParams']['vmTagIds'] = []
    if list(includetags) not in job['vmwareParams']['vmTagIds']:
        job['vmwareParams']['vmTagIds'].append(includeTagIds)

# exclude tags
if len(excludeTagIds) > 0:
    if newJob is True:
        job['vmwareParams']['excludeVmTagIds'] = []
    else:
        if 'excludeVmTagIds' not in job['vmwareParams'] or job['vmwareParams']['excludeVmTagIds'] is None:
            job['vmwareParams']['excludeVmTagIds'] = []
    if list(excludeTagIds) not in job['vmwareParams']['excludeVmTagIds']:
        job['vmwareParams']['excludeVmTagIds'].append(excludeTagIds)

# make lists unique
if job['vmwareParams']['vmTagIds'] is not None and len(job['vmwareParams']['vmTagIds']) > 0:
    job['vmwareParams']['vmTagIds'] = [list(x) for x in set(tuple(x) for x in job['vmwareParams']['vmTagIds'])]

if job['vmwareParams']['excludeVmTagIds'] is not None and len(job['vmwareParams']['excludeVmTagIds']) > 0:
    job['vmwareParams']['excludeVmTagIds'] = [list(x) for x in set(tuple(x) for x in job['vmwareParams']['excludeVmTagIds'])]

# create or update job
if newJob is True:
    print('Creating protection job %s' % jobname)
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print('Updating protection job %s' % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
