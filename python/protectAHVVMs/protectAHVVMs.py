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
parser.add_argument('-sn', '--sourcename', type=str, default=None)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-ei', '--enableindexing', action='store_true')
parser.add_argument('-ed', '--excludedisk', action='append', type=str)
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
sourcename = args.sourcename
storagedomain = args.storagedomain
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
pause = args.pause
enableindexing = args.enableindexing
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


vmnames = gatherList(vmname, vmlist, name='VMs', required=True)

if pause:
    isPaused = True
else:
    isPaused = False

if enableindexing:
    indexingEnabled = True
else:
    indexingEnabled = False


# get object ID
def getObjectId(objectName):

    d = {'_object_id': None}

    def get_nodes(node):
        if 'name' in node:
            if node['name'].lower() == objectName.lower():
                d['_object_id'] = node
                exit
        if 'protectionSource' in node:
            if node['protectionSource']['name'].lower() == objectName.lower():
                d['_object_id'] = node['protectionSource']
                exit
        if 'nodes' in node:
            for node in node['nodes']:
                if d['_object_id'] is None:
                    get_nodes(node)
                else:
                    exit

    if d['_object_id'] is None:
        get_nodes(source)

    return d['_object_id']


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

# get AHV protection source
sources = api('get', 'protectionSources/rootNodes?environments=kAcropolis')

# find existing job
job = None
jobs = api('get', 'data-protect/protection-groups?environments=kAcropolis&isDeleted=false&isActive=true', v=2)
if jobs is not None and 'protectionGroups' in jobs and jobs['protectionGroups'] is not None and len(jobs['protectionGroups']) > 0:
    jobs = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if jobs is not None and len(jobs) > 0:
        job = jobs[0]

if job is not None:
    newJob = False
    source = [v for v in sources if v['protectionSource']['id'] == job['acropolisParams']['sourceId']][0]
    source = api('get','protectionSources?id=%s' % source['protectionSource']['id'])[0]
else:
    # new job
    newJob = True

    # get AHV source
    if sourcename is None:
        print('sourcename required')
        exit(1)
    else:
        source = [v for v in sources if v['protectionSource']['name'].lower() == sourcename.lower()]
        if not source or len(source) == 0:
            print('AHV source %s not registered' % sourcename)
            exit(1)
        else:
            source = source[0]
    source = api('get','protectionSources?id=%s' % source['protectionSource']['id'])[0]
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
        "environment": "kAcropolis",
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
        "acropolisParams": {
            "appConsistentSnapshot": False,
            "continueOnQuiesceFailure": True,
            "sourceId": source['protectionSource']['id'],
            "objects": [],
            "excludeObjectIds": [],
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

for thisvmname in vmnames:
    vm = getObjectId(thisvmname)
    if vm is not None:
        if vm['id'] not in [o['id'] for o in job['acropolisParams']['objects']]:
            newobject = {
                "excludeDisks": None,
                "id": vm['id'],
                "name": vm['name'],
                "isAutoprotected": False
            }
            if excludedisks is not None and len(excludedisks) > 0:
                newobject['excludeDisks'] = []
                for x in excludedisks:
                    (controllerType, unitNumber) = x.split(':')
                    newobject['excludeDisks'].append({
                        "controllerType": controllerType,
                        "unitNumber": int(unitNumber)
                    })
            job['acropolisParams']['objects'].append(newobject)
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
