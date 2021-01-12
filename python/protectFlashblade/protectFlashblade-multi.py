#!/usr/bin/env python
"""Protect FlashBlade Volumes"""

# usage:
# ./protectFlashblade-multi.py -v mycluster \
#                              -u myuser \
#                              -d mydomain.net \
#                              -p 'My Policy' \
#                              -f flashblad01 \
#                              -l myvolumelist.txt \
#                              -t 'America/New_York' \
#                              -ei \
#                              -s '00:00' \
#                              -is 180

# import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
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

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
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
if len(volumes) == 0:
    print('No volumes specified!')
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

sourceVolumes = [n for n in flashblade['nodes'] if n['protectionSource']['name'].lower() in [v.lower() for v in volumes]]
sourceVolumeNames = [n['protectionSource']['name'] for n in sourceVolumes]
# sourceIds = [n['protectionSource']['id'] for n in sourceVolumes]
missingVolumes = [v for v in volumes if v not in sourceVolumeNames]
if len(missingVolumes) > 0:
    print("Volumes %s not found" % ', '.join(missingVolumes))
    exit(1)

for sourceVolume in sourceVolumes:
    jobname = '%s-%s' % (flashbladesource, sourceVolume['protectionSource']['name'])
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
            'sourceIds': [sourceVolume['protectionSource']['id']],
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
        print('Creating protection job %s...' % jobname)
        result = api('post', 'protectionJobs', jobparams)
    else:
        print('job %s already exists' % jobname)
