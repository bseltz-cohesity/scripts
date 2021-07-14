#!/usr/bin/env python
"""Add Isilon volumes to a Protection Job Using Python"""

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
parser.add_argument('-z', '--zonename', action='append', type=str)
parser.add_argument('-n', '--volumename', action='append', type=str)
parser.add_argument('-l', '--volumelist', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-i', '--include', action='append', type=str)
parser.add_argument('-f', '--includefile', type=str)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludefile', type=str)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, required=True)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-ei', '--enableindexing', action='store_true')     # enable indexing
parser.add_argument('-c', '--cloudarchivedirect', action='store_true')     # enable CAD

args = parser.parse_args()

vip = args.vip                        # cluster name/ip
username = args.username              # username to connect to cluster
domain = args.domain                  # domain of username (e.g. local, or AD domain)
password = args.password              # password or API key
useApiKey = args.useApiKey            # use API key for authentication
sourcename = args.sourcename          # name of registered isilon
zonenames = args.zonename             # names of zones to protect
volumenames = args.volumename         # namea of volumes to protect
volumelist = args.volumelist          # file with volume names
jobname = args.jobname                # name of protection job to add server to
includes = args.include               # include path
includefile = args.includefile        # file with include paths
excludes = args.exclude               # exclude path
excludefile = args.excludefile        # file with exclude paths
storagedomain = args.storagedomain    # storage domain for new job
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job
enableindexing = args.enableindexing  # enable indexing on new job
cloudarchivedirect = args.cloudarchivedirect  # enable cloud archive direct

# zone names
if zonenames is None:
    zonenames = []
else:
    zonenames = [z.lower() for z in zonenames]

# read server file
if volumenames is None:
    volumenames = []
if volumelist is not None:
    f = open(volumelist, 'r')
    volumenames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
volumenames = [v.lower() for v in volumenames]

# read include file

if includes is None:
    includes = []
if includefile is not None:
    f = open(includefile, 'r')
    includes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# read exclude file
if excludes is None:
    excludes = []
if excludefile is not None:
    f = open(excludefile, 'r')
    excludes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# get isilon source
sources = api('get', 'protectionSources?environment=kIsilon')
source = [s for s in sources if s['protectionSource']['name'].lower() == sourcename.lower()]
if source is None or len(source) == 0:
    print('Isilion %s not found!' % sourcename)
    exit(1)
else:
    source = source[0]

# find protectionPolicy
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

# get object IDs to protect
objects = {}
foundVolumes = []
for zone in source['nodes']:
    if len(zonenames) == 0 or zone['protectionSource']['name'].lower() in zonenames:
        for volume in zone['nodes']:
            if len(volumenames) == 0 or volume['protectionSource']['name'].lower() in volumenames:
                objects[volume['protectionSource']['name'].lower()] = volume['protectionSource']['id']
                foundVolumes.append(volume['protectionSource']['name'].lower())

# warn on missing volumes
for volume in volumenames:
    if volume not in foundVolumes:
        print('volume %s not found!' % volume)
        exit(1)

protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
jobs = protectionGroups['protectionGroups']
for volume in objects:
    thisjobname = '%s%s' % (jobname, volume.replace('/', '-'))
    job = [j for j in jobs if j['name'].lower() == thisjobname.lower()]

    if not job or len(job) < 1:
        print("Creating new job %s" % thisjobname)

        job = {
            "name": thisjobname,
            "environment": "kIsilon",
            "isPaused": False,
            "policyId": policyid,
            "priority": "kMedium",
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
            "isilonParams": {
                "objects": [
                    {
                        "id": objects[volume]
                    }
                ],
                "excludeObjectIds": [],
                "directCloudArchive": cloudarchivedirect,
                "nativeFormat": True,
                "indexingPolicy": {
                    "enableIndexing": enableindexing,
                    "includePaths": [
                        "/"
                    ],
                    "excludePaths": []
                },
                "protocol": "kNfs3",
                "continueOnError": True,
                "useChangelist": False,
                "encryptionEnabled": False
            }
        }

        if not cloudarchivedirect:
            job['storageDomainId'] = sdid

        # add includes and excludes
        if len(includes) > 0 or len(excludes) > 0:
            if 'fileFilters' not in job['isilonParams']:
                job['isilonParams']['fileFilters'] = {}
            if 'includeList' not in job['isilonParams']['fileFilters']:
                job['isilonParams']['fileFilters']['includeList'] = []
                if len(includes) == 0:
                    job['isilonParams']['fileFilters']['includeList'].append('/')
            if 'excludeList' not in job['isilonParams']['fileFilters']:
                job['isilonParams']['fileFilters']['excludeList'] = []
            for include in includes:
                if include not in job['isilonParams']['fileFilters']['includeList']:
                    job['isilonParams']['fileFilters']['includeList'].append(include)
            for exclude in excludes:
                if exclude not in job['isilonParams']['fileFilters']['excludeList']:
                    job['isilonParams']['fileFilters']['excludeList'].append(exclude)

        result = api('post', 'data-protect/protection-groups', job, v=2)
    else:
        print('Job %s already exists' % thisjobname)
