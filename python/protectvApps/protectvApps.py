#!/usr/bin/env python
"""Add Physical Linux Servers to File-based Protection Job Using Python"""

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
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-o', '--orgname', type=str, required=True)
parser.add_argument('-c', '--vdcname', type=str, required=True)
parser.add_argument('-t', '--vapptype', type=str, choices=['all', 'kVirtualApp', 'kvAppTemplate'], default='all')
parser.add_argument('-n', '--numtoprotect', type=int, default=None)
parser.add_argument('-i', '--includeprefix', action='append', type=str)
parser.add_argument('-e', '--excludeprefix', action='append', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-z', '--pause', action='store_true')

args = parser.parse_args()

vip = args.vip                        # cluster name/ip
username = args.username              # username to connect to cluster
domain = args.domain                  # domain of username (e.g. local, or AD domain)
password = args.password              # password or API key
useApiKey = args.useApiKey            # use API key for authentication
sourcename = args.sourcename          # name of vcd source to protect
orgname = args.orgname                # name of vcd org to protect
vdcname = args.vdcname                # name of org vdc to protect
vapptype = args.vapptype              # type to protect
numtoprotect = args.numtoprotect      # number of vapps to add to the job
includeprefix = args.includeprefix    # only include vapps that start with this prefix
excludeprefix = args.excludeprefix    # exclude vapps that start with this prefix
jobname = args.jobname                # name of protection job to add server to
storagedomain = args.storagedomain    # storage domain for new job
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job
pause = args.pause                    # pause new job

# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if numtoprotect is not None and numtoprotect < 1:
    print('-n, --numtoprotect must be greater than zero')
    exit()

# get VCD registered source
sources = [s for s in api('get', 'protectionSources?environments=kVMware') if s['protectionSource']['vmWareProtectionSource']['type'] == 'kvCloudDirector' and s['protectionSource']['name'].lower() == sourcename.lower()]
if not sources or len(sources) == 0:
    print('VCD source %s not registered' % sourcename)
    exit(1)
else:
    source = sources[0]

# gather already protected sourceids
jobs = [j for j in api('get', 'protectionJobs?environment=kVMware&isDeleted=false') if j['parentSourceId'] in [s['protectionSource']['id'] for s in sources]]
protectedsourceids = []
for j in jobs:
    protectedsourceids = protectedsourceids + j['sourceIds']

# get VCD Organization
orgs = [o for o in source['nodes'] if o['protectionSource']['vmWareProtectionSource']['type'] == 'kOrganization' and o['protectionSource']['name'].lower() == orgname.lower()]
if not orgs or len(orgs) == 0:
    print('VCD Org %s not found' % orgname)
    exit(1)
else:
    org = orgs[0]

# get VCD Virtual Datacenter
vdcs = [v for v in org['nodes'] if v['protectionSource']['vmWareProtectionSource']['type'] == 'kVirtualDatacenter' and v['protectionSource']['name'].lower() == vdcname.lower()]
if not vdcs or len(vdcs) == 0:
    print("VCD Vdc %s not found" % vdcname)
    exit(1)
else:
    vdc = vdcs[0]

# get vApps
vapps = vdc['nodes']
if vapptype != 'all':
    vapps = [v for v in vapps if v['protectionSource']['vmWareProtectionSource']['type'].lower() == vapptype.lower()]

if includeprefix and len(includeprefix) > 0:
    vapps = [v for v in vapps if len([f for f in includeprefix if v['protectionSource']['name'].lower().startswith(f.lower())]) > 0]

if excludeprefix and len(excludeprefix) > 0:
    vapps = [v for v in vapps if len([f for f in excludeprefix if not v['protectionSource']['name'].lower().startswith(f.lower())]) > 0]

vappids = [v['protectionSource']['id'] for v in vapps if v['protectionSource']['id'] not in protectedsourceids]
if len(vappids) == 0:
    print('No vApps found to protect')
    exit(1)

unprotectedvappcount = len(vappids)

# get job info
newJob = False

job = [j for j in api('get', 'protectionJobs?environment=kVMware') if j['name'].lower() == jobname.lower()]

if not job or len(job) == 0:

    newJob = True

    # find protectionPolicy
    if policyname is None:
        print('Policy name required for new job')
        exit(1)
    policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
    if len(policy) < 1:
        print("Policy '%s' not found!" % policyname)
        exit(1)
    policyid = policy[0]['id']

    # find storage domain
    sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
    if len(sd) < 1:
        print("Storage domain %s not found!" % storagedomain)
        exit(1)
    sdid = sd[0]['id']

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

    print("Creating new Job '%s'" % jobname)

    # limit number of vApps to add to the new job
    if numtoprotect is not None and numtoprotect > 0:
        vappids = vappids[0:numtoprotect]
        unprotectedvappcount = unprotectedvappcount - len(vappids)
        print('Protecting %s vApps. %s remain unprotected' % (len(vappids), unprotectedvappcount))
    else:
        print('Protecting %s vApps' % len(vappids))

    job = {
        "policyId": policyid,
        "environment": "kVMware",
        "parentSourceId": source['protectionSource']['id'],
        "LeverageSanTransport": None,
        "timezone": timezone,
        "viewBoxId": sdid,
        "priority": "kLow",
        "name": jobname,
        "indexingPolicy": {
            "allowPrefixes": [
                "/"
            ],
            "disableIndexing": False,
            "denyPrefixes": [
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
                "/grub2"
            ]
        },
        "sourceIds": vappids,
        "startTime": {
            "minute": minute,
            "hour": hour
        }
    }

else:
    job = job[0]

    if job['parentSourceId'] != source['protectionSource']['id']:
        print('Job %s protects a different vCloud/vCenter' % jobname)
        exit(1)

    # unprotectedvappcount = unprotectedvappcount - len(vappids)

    # limit number of vApps to add to the new job
    if numtoprotect is not None and numtoprotect > 0:
        vappids = [i for i in vappids if i not in job['sourceIds']]
        if vappids is not None and len(vappids) > 0:
            vappids = vappids[0:numtoprotect]
            unprotectedvappcount = unprotectedvappcount - len(vappids)
            print("Updating Job '%s'" % jobname)
            print('Protecting %s vApps. %s remain unprotected' % (len(vappids), unprotectedvappcount))
        else:
            print('All vApps are already protected')
            exit()
    else:
        print('Protecting %s vApps' % len(vappids))

    job['sourceIds'] += vappids

# update job
if newJob is True:
    createdjob = api('post', 'protectionJobs', job)
    if(pause is True):
        result = api('post', 'protectionJobs/states', {"action": "kPause", "jobIds": [createdjob['id']]})
else:
    job['sourceIds'] = list(set(job['sourceIds']))
    result = api('put', 'protectionJobs/%s' % job['id'], job)
