#!/usr/bin/env python
"""Protect Generic Nas Mountpoints"""

# usage:

# ./protectGenericNas.ps1 -v mycluster \
#                         -u myuser \
#                         -d mydomain.net \
#                         -p 'My Policy' \
#                         -j 'My New Job' \
#                         -m \\myserver\myshare

# import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-mfa', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', type=str, required=True)   # name of protection job
parser.add_argument('-p', '--policyname', type=str)               # name of protection policy
parser.add_argument('-s', '--starttime', type=str, default='20:00')  # job start time
parser.add_argument('-m', '--mountpath', action='append', type=str)     # mount path
parser.add_argument('-f', '--mountpathlist', type=str)                  # mount paths in text file
parser.add_argument('-i', '--include', action='append', type=str)    # include path
parser.add_argument('-n', '--includelist', type=str)               # include path file
parser.add_argument('-e', '--exclude', action='append', type=str)  # exclude path
parser.add_argument('-x', '--excludelist', type=str)               # exclude path file
parser.add_argument('-tz', '--timezone', type=str, default='America/Los_Angeles')  # timezone for job
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-ei', '--enableindexing', action='store_true')     # enable indexing
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')  # storage domain
parser.add_argument('-z', '--paused', action='store_true')

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
jobname = args.jobname
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
includes = args.include
includelist = args.includelist
excludes = args.exclude
excludelist = args.excludelist
incrementalsla = args.incrementalsla
fullsla = args.fullsla
enableindexing = args.enableindexing
mountpaths = args.mountpath
mountpathlist = args.mountpathlist
paused = args.paused
storagedomain = args.storagedomain

# indexing
disableindexing = True
if enableindexing is True:
    disableindexing = False

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

includes = gatherList(includes, includelist, name='includes', required=False)
if len(includes) == 0:
    includes += '/'

excludes = gatherList(excludes, excludelist, name='excludes', required=False)
if '/.snapshot/' not in excludes:
    excludes.append('/.snapshot/')

mountpaths = gatherList(mountpaths, mountpathlist, name='mount paths', required=True)

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

# get generic NAS mount points root
sources = api('get', 'protectionSources?environments=kGenericNas')
parentsourceid = sources[0]['protectionSource']['id']

# gather source ids for mountpaths
sourceids = []
for mountpath in mountpaths:
    source = [s for s in sources[0]['nodes'] if s['protectionSource']['name'].lower() == mountpath.lower()]
    if len(source) < 1:
        print('Mount Path %s is not registered in Cohesity' % mountpath)
        exit(1)
    print('protecting %s' % mountpath)
    sourceids.append(source[0]['protectionSource']['id'])

# new or existing job
jobs = api('get', 'data-protect/protection-groups?useCachedData=false&isDeleted=false&isActive=true&environments=kGenericNas', v=2)
if jobs['protectionGroups'] is not None:
    job = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
else:
    job = []

newJob = False
if len(job) < 1:
    newJob = True
    # find protectionPolicy
    if policyname is None:
        print('Policy name required for new job')
        exit(1)
    policies = api('get', 'data-protect/policies', v=2)
    policy = [p for p in policies['policies'] if p['name'].lower() == policyname.lower()]
    if len(policy) < 1:
        print("Policy '%s' not found!" % policyname)
        exit(1)
    policyid = policy[0]['id']
    try:
        primaryTargetType = policy[0]['backupPolicy']['regular']['primaryBackupTarget']['targetType']
    except Exception:
        primaryTargetType = 'Local'

    # find storage domain
    if primaryTargetType == 'Archival':
        sdid = None
    else:
        sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
        if len(sd) < 1:
            print("Storage domain %s not found!" % storagedomain)
            exit(1)
        sdid = sd[0]['id']

    # parse starttime
    try:
        (hour, minute) = starttime.split(':')
    except Exception:
        print('starttime is invalid!')
        exit(1)

    jobparams = {
        "policyId": policyid,
        "startTime": {
            "hour": int(hour),
            "minute": int(minute),
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
        "storageDomainId": sdid,
        "name": jobname,
        "environment": "kGenericNas",
        "isPaused": False,
        "description": "",
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "genericNasParams": {
            "objects": [],
            "indexingPolicy": {
                "enableIndexing": False,
                "includePaths": [
                    "/"
                ],
                "excludePaths": []
            },
            "protocol": "kNfs3",
            "continueOnError": True,
            "fileFilters": {
                "includeList": includes,
                "excludeList": excludes
            },
            "encryptionEnabled": False,
            "excludeObjectIds": []
        }
    }
    if paused is True:
        jobparams['isPaused'] = True
    if enableindexing is True:
        jobparams['genericNasParams']['indexingPolicy']['enableIndexing'] = True
else:
    jobparams = job[0]

for sourceid in sourceids:
    jobparams['genericNasParams']['objects'] = [o for o in jobparams['genericNasParams']['objects'] if o['id'] != sourceid]
    jobparams['genericNasParams']['objects'].append({'id': sourceid})

if newJob is True:
    print('Creating protection job %s...' % jobname)
    result = api('post', 'data-protect/protection-groups', jobparams, v=2)
else:
    print('Updating protection job %s...' % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % jobparams['id'], jobparams, v=2)
