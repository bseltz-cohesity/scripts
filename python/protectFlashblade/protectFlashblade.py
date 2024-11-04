#!/usr/bin/env python
"""Protect FlashBlade Volumes"""

# import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-j', '--jobname', type=str, required=True)   # name of protection job
parser.add_argument('-p', '--policyname', type=str)               # name of protection policy
parser.add_argument('-s', '--starttime', type=str, default='20:00')  # job start time
parser.add_argument('-i', '--include', action='append', type=str)    # include path
parser.add_argument('-n', '--includefile', type=str)               # include path file
parser.add_argument('-e', '--exclude', action='append', type=str)  # exclude path
parser.add_argument('-x', '--excludefile', type=str)               # exclude path file
parser.add_argument('-t', '--timezone', type=str, default='America/New_York')  # timezone for job
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-ei', '--enableindexing', action='store_true')     # enable indexing
parser.add_argument('-f', '--flashbladesource', type=str, required=True)
parser.add_argument('-vol', '--volumename', action='append', type=str)
parser.add_argument('-l', '--volumelist', type=str)
parser.add_argument('-c', '--cloudarchivedirect', action='store_true')  # cloud archive direct
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')  # storage domain
parser.add_argument('-a', '--allvolumes', action='store_true')
parser.add_argument('-z', '--paused', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobname = args.jobname
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
includes = args.include
includefile = args.includefile
excludes = args.exclude
excludefile = args.excludefile
incrementalsla = args.incrementalsla
fullsla = args.fullsla
enableindexing = args.enableindexing
volumes = args.volumename
volumelist = args.volumelist
cloudarchivedirect = args.cloudarchivedirect
storagedomain = args.storagedomain
flashbladesource = args.flashbladesource
allvolumes = args.allvolumes
paused = args.paused

# cloud archive direct storage domain
if cloudarchivedirect:
    storagedomain = 'Direct_Archive_Viewbox'

# indexing
disableindexing = True
if enableindexing is True:
    disableindexing = False

# parse starttime
try:
    (hour, minute) = starttime.split(':')
except Exception:
    print('starttime is invalid!')
    exit(1)

# gather includes
if includes is None:
    includes = []
if includefile is not None:
    f = open(includefile, 'r')
    includes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()
if len(includes) == 0:
    includes += '/'

# gather excludes
if excludes is None:
    excludes = []
if excludefile is not None:
    f = open(excludefile, 'r')
    excludes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# gather volumes
if volumes is None:
    volumes = []
if volumelist is not None:
    f = open(volumelist, 'r')
    volumes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()
if len(volumes) == 0 and allvolumes is not True:
    print('No volumes specified!')
    exit(1)

if cloudarchivedirect and len(volumes) > 1:
    print('Cloud Archive Direct jobs are limited to a single volume')
    exit(1)

# authenticate
apiauth(vip, username, domain)

# find storage domain
sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
if len(sd) < 1:
    print("Storage domain %s not found!" % storagedomain)
    exit(1)
sdid = sd[0]['id']

# get flashblade source
sources = api('get', 'protectionSources?environments=kFlashBlade')
flashblade = [s for s in sources if s['protectionSource']['name'].lower() == flashbladesource.lower()]
if len(flashblade) < 1:
    print('FlashBlade %s not registered in Cohesity' % flashbladesource)
    exit(1)
else:
    flashblade = flashblade[0]
parentId = flashblade['protectionSource']['id']

# gather source ids for volumes
sourceids = []

if len(volumes) > 0 or allvolumes is True:
    if cloudarchivedirect and len(volumes) > 1:
        print("Cloud Archive Direct jobs are limited to a single volume")
        exit(1)
    if allvolumes is True:
        if len(flashblade['nodes']) > 1 and cloudarchivedirect:
            print("Cloud Archive Direct jobs are limited to a single volume")
            exit(1)
        sourceVolumes = [n for n in flashblade['nodes']]
    else:
        sourceVolumes = [n for n in flashblade['nodes'] if n['protectionSource']['name'].lower() in [v.lower() for v in volumes]]
    # display(sourceVolumes)
    sourceVolumes = [s for s in sourceVolumes if s['protectionSource']['flashBladeProtectionSource']['fileSystem']['backupEnabled'] is True and 'kNfs' in s['protectionSource']['flashBladeProtectionSource']['fileSystem']['protocols']]
    sourceVolumeNames = [n['protectionSource']['name'] for n in sourceVolumes]
    sourceIds = [n['protectionSource']['id'] for n in sourceVolumes]
    missingVolumes = [v for v in volumes if v not in sourceVolumeNames]
    if len(missingVolumes) > 0:
        print("Volumes %s not found" % ', '.join(missingVolumes))
        exit(1)
elif cloudarchivedirect:
    print("Cloud Archive Direct jobs are limited to a single volume")
    exit(1)
else:
    sourceids.append(parentId)

# new or existing job
job = [j for j in api('get', 'protectionJobs?environments=kFlashBlade&isActive=true&isDeleted=false') if j['name'].lower() == jobname.lower()]
if len(job) < 1:
    # find protectionPolicy
    if policyname is None:
        print('Policy name required for new job')
        exit(1)
    policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
    if len(policy) < 1:
        print("Policy '%s' not found!" % policyname)
        exit(1)
    policyid = policy[0]['id']

    jobparams = {
        'name': jobname,
        'description': '',
        'environment': 'kFlashBlade',
        'policyId': policyid,
        'viewBoxId': sdid,
        'parentSourceId': parentId,
        'sourceIds': sourceIds,
        'startTime': {
            'hour': int(hour),
            'minute': int(minute)
        },
        'timezone': timezone,
        'incrementalProtectionSlaTimeMins': incrementalsla,
        'fullProtectionSlaTimeMins': fullsla,
        'priority': 'kMedium',
        'alertingPolicy': [
            'kFailure'
        ],
        'indexingPolicy': {
            'disableIndexing': disableindexing,
            'allowPrefixes': [
                '/'
            ]
        },
        'abortInBlackoutPeriod': False,
        'qosType': 'kBackupHDD',
        'environmentParameters': {
            'nasParameters': {
                'nasProtocol': 'kNfs3',
                'continueOnError': True,
                'filePathFilters': {
                    'protectFilters': includes,
                    'excludeFilters': excludes
                }
            }
        },
        'isDirectArchiveEnabled': cloudarchivedirect,
    }
    if paused is True:
        jobparams['isPaused'] = True
    print('Creating protection job %s...' % jobname)
    result = api('post', 'protectionJobs', jobparams)
else:
    if cloudarchivedirect:
        print('Cloud Archive Direct jobs are limited to a single volume')
        exit(1)
    print('Updating protection job %s...' % jobname)
    job[0]['sourceIds'] += sourceids
    job[0]['sourceIds'] = list(set(job[0]['sourceIds']))
    result = api('put', 'protectionJobs/%s' % job[0]['id'], job[0])
