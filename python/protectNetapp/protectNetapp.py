#!/usr/bin/env python
"""Protect Netapp C-mode Using Python"""

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
parser.add_argument('-z', '--svmname', action='append', type=str)
parser.add_argument('-n', '--volumename', action='append', type=str)
parser.add_argument('-l', '--volumelist', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-i', '--include', action='append', type=str)
parser.add_argument('-f', '--includefile', type=str)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludefile', type=str)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)
parser.add_argument('-a', '--pause', action='store_true')
parser.add_argument('-c', '--cloudarchivedirect', action='store_true')
parser.add_argument('-ip', '--incrementalsnapshotprefix', type=str, default=None)
parser.add_argument('-fp', '--fullsnapshotprefix', type=str, default=None)

args = parser.parse_args()

vip = args.vip                        # cluster name/ip
username = args.username              # username to connect to cluster
domain = args.domain                  # domain of username (e.g. local, or AD domain)
password = args.password              # password or API key
useApiKey = args.useApiKey            # use API key for authentication
sourcename = args.sourcename          # name of registered Netapp source to protect
svmnames = args.svmname             # names of zones to protect
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
pause = args.pause                    # pause new job
cloudarchivedirect = args.cloudarchivedirect  # enable cloud archive direct
incrementalsnapshotprefix = args.incrementalsnapshotprefix
fullsnapshotprefix = args.fullsnapshotprefix

if pause:
    isPaused = True
else:
    isPaused = False

if cloudarchivedirect:
    isCAD = True
else:
    isCAD = False

# svm names
if svmnames is None:
    svmnames = []
else:
    svmnames = [z.lower() for z in svmnames]

# read volume file
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

# get registered Netapp source
sources = [s for s in api('get', 'protectionSources?environments=kNetapp') if s['protectionSource']['name'].lower() == sourcename.lower()]
if not sources or len(sources) == 0:
    print('Netapp source %s not registered' % sourcename)
    exit(1)
else:
    source = sources[0]

# gather SVMs
svms = []
if source['protectionSource']['netappProtectionSource']['type'] == 'kVserver':
    svms.append(source)
else:
    svms = [node for node in source['nodes']]

objectIds = []
foundVolumes = []

if len(volumenames) == 0 and len(svmnames) == 0:
    # select entire source
    objectIds.append(source['protectionSource']['id'])
elif len(volumenames) == 0:
    # select entire svms
    for svmname in svmnames:
        svm = [s for s in svms if s['protectionSource']['name'].lower() == svmname.lower()]
        if svm is None or len(svm) == 0:
            print('SVM %s not found' % svmname)
            exit(1)
        objectIds.append(svm[0]['protectionSource']['id'])
else:
    # select individual volumes
    for svm in svms:
        if len(svmnames) == 0 or svm['protectionSource']['name'].lower() in svmnames:
            for volume in svm['nodes']:
                if volume['protectionSource']['name'].lower() in volumenames:
                    objectIds.append(volume['protectionSource']['id'])
                    foundVolumes.append(volume['protectionSource']['name'].lower())

# warn on missing volumes
for volume in volumenames:
    if volume not in foundVolumes:
        print('volume %s not found!' % volume)
        exit(1)

# get job info
newJob = False

protectionGroups = api('get', 'data-protect/protection-groups?environments=kNetapp&isDeleted=false&isActive=true', v=2)
jobs = protectionGroups['protectionGroups']
if jobs is None:
    job = None
else:
    job = [job for job in jobs if job['name'].lower() == jobname.lower()]

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

    job = {
        "policyId": policyid,
        "startTime": {
            "hour": hour,
            "minute": minute,
            "timeZone": timezone
        },
        "priority": "kMedium",
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
        "abortInBlackouts": False,
        "name": jobname,
        "environment": "kNetapp",
        "isPaused": isPaused,
        "description": "",
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "netappParams": {
            "objects": [],
            "directCloudArchive": isCAD,
            "nativeFormat": True,
            "indexingPolicy": {
                "enableIndexing": True,
                "includePaths": [
                    "/"
                ],
                "excludePaths": []
            },
            "protocol": "kNfs3",
            "continueOnError": True,
            "encryptionEnabled": False,
            "backupExistingSnapshot": True,
            "excludeObjectIds": []
        }
    }

    if not cloudarchivedirect:
        job['storageDomainId'] = sdid

    if incrementalsnapshotprefix is not None or fullsnapshotprefix is not None:
        if incrementalsnapshotprefix is not None and fullsnapshotprefix is None:
            fullsnapshotprefix = incrementalsnapshotprefix
        if fullsnapshotprefix is not None and incrementalsnapshotprefix is None:
            incrementalsnapshotprefix = fullsnapshotprefix
        job['netappParams']['snapshotLabel'] = {
            "incrementalLabel": incrementalsnapshotprefix,
            "fullLabel": fullsnapshotprefix
        }

else:
    print('Updating job %s' % jobname)
    job = job[0]

# add objects to job
existingObjects = [o['id'] for o in job['netappParams']['objects']]
for objectid in objectIds:
    if objectid not in existingObjects:
        job['netappParams']['objects'].append({"id": objectid})
        existingObjects.append(objectid)

# add includes and excludes
if len(includes) > 0 or len(excludes) > 0:
    if 'fileFilters' not in job['netappParams']:
        job['netappParams']['fileFilters'] = {}
    if 'includeList' not in job['netappParams']['fileFilters']:
        job['netappParams']['fileFilters']['includeList'] = []
        if len(includes) == 0:
            job['netappParams']['fileFilters']['includeList'].append('/')
    if 'excludeList' not in job['netappParams']['fileFilters']:
        job['netappParams']['fileFilters']['excludeList'] = []
    for include in includes:
        if include not in job['netappParams']['fileFilters']['includeList']:
            job['netappParams']['fileFilters']['includeList'].append(include)
    for exclude in excludes:
        if exclude not in job['netappParams']['fileFilters']['excludeList']:
            job['netappParams']['fileFilters']['excludeList'].append(exclude)

# update job
if newJob is True:
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
