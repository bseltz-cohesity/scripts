#!/usr/bin/env python
"""Add Isilon volumes to a Protection Job Using Python"""

### import pyhesity wrapper module
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
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-z', '--zonename', action='append', type=str)
parser.add_argument('-n', '--volumename', action='append', type=str)
parser.add_argument('-l', '--volumelist', type=str)
parser.add_argument('-ev', '--excludevolumename', action='append', type=str)
parser.add_argument('-el', '--excludevolumelist', type=str)
parser.add_argument('-ifs', '--includerootifs', action='store_true')
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
parser.add_argument('-ei', '--enableindexing', action='store_true')
parser.add_argument('-a', '--pause', action='store_true')
parser.add_argument('-cad', '--cloudarchivedirect', action='store_true')
parser.add_argument('-ip', '--incrementalsnapshotprefix', type=str, default=None)
parser.add_argument('-fp', '--fullsnapshotprefix', type=str, default=None)
parser.add_argument('-enc', '--encryptionenabled', action='store_true')
parser.add_argument('-cl', '--usechangelist', action='store_true')

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
sourcename = args.sourcename          # name of registered isilon
zonenames = args.zonename             # names of zones to protect
volumenames = args.volumename         # namea of volumes to protect
volumelist = args.volumelist          # file with volume names
excludevolumenames = args.excludevolumename
excludevolumelist = args.excludevolumelist
includerootifs = args.includerootifs
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
pause = args.pause                    # pause new job
cloudarchivedirect = args.cloudarchivedirect  # enable cloud archive direct
incrementalsnapshotprefix = args.incrementalsnapshotprefix  # incremental snapshot prefix
fullsnapshotprefix = args.fullsnapshotprefix  # full snapshot prefux
encryptionenabled = args.encryptionenabled  # encryption enabled
usechangelist = args.usechangelist


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


volumenames = gatherList(volumenames, volumelist, name='volumes', required=False)
includes = gatherList(includes, includefile, name='includes', required=False)
excludes = gatherList(excludes, excludefile, name='excludes', required=False)
excludevolumenames = gatherList(excludevolumenames, excludevolumelist, name='excluded volumes', required=False)
volumenames = [v.lower() for v in volumenames]
excludevolumenames = [v.lower() for v in excludevolumenames]
if includerootifs is not True:
    excludevolumenames.append('/ifs')

if pause:
    isPaused = True
else:
    isPaused = False

if cloudarchivedirect:
    isCAD = True
else:
    isCAD = False

if encryptionenabled:
    encrypt = True
else:
    encrypt = False

# zone names
if zonenames is None:
    zonenames = []
else:
    zonenames = [z.lower() for z in zonenames]

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

# get isilon source
sources = api('get', 'protectionSources?environment=kIsilon')
source = [s for s in sources if s['protectionSource']['name'].lower() == sourcename.lower()]
if source is None or len(source) == 0:
    print('Isilion %s not found!' % sourcename)
    exit(1)
else:
    source = source[0]

# get object IDs to protect
objectids = []
foundVolumes = []
for zone in source['nodes']:
    if len(zonenames) == 0 or zone['protectionSource']['name'].lower() in zonenames:
        if 'nodes' in zone and zone['nodes'] is not None and len(zone['nodes']) > 0:
            for volume in zone['nodes']:
                thisvolumename = volume['protectionSource']['name'].lower()
                if (len(volumenames) == 0 or thisvolumename in volumenames) and thisvolumename not in excludevolumenames:
                    objectids.append(volume['protectionSource']['id'])
                    foundVolumes.append(volume['protectionSource']['name'].lower())

# warn on missing volumes
for volume in volumenames:
    if volume not in foundVolumes:
        print('volume %s not found!' % volume)
        exit(1)

# get job info
newJob = False
protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
jobs = protectionGroups['protectionGroups']
job = [job for job in jobs if job['name'].lower() == jobname.lower()]

if not job or len(job) < 1:
    newJob = True
    print("Job '%s' not found. Creating new job" % jobname)

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

    job = {
        "name": jobname,
        "environment": "kIsilon",
        "isPaused": isPaused,
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
            "objects": [],
            "excludeObjectIds": [],
            "directCloudArchive": isCAD,
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
            "encryptionEnabled": encrypt
        }
    }

    if not cloudarchivedirect:
        job['storageDomainId'] = sdid

    if incrementalsnapshotprefix is not None or fullsnapshotprefix is not None:
        if incrementalsnapshotprefix is not None and fullsnapshotprefix is None:
            fullsnapshotprefix = incrementalsnapshotprefix
        if fullsnapshotprefix is not None and incrementalsnapshotprefix is None:
            incrementalsnapshotprefix = fullsnapshotprefix
        job['isilonParams']['snapshotLabel'] = {
            "incrementalLabel": incrementalsnapshotprefix,
            "fullLabel": fullsnapshotprefix
        }

else:
    print('Updating job %s' % jobname)
    job = job[0]

if usechangelist is True:
    job['isilonParams']['useChangelist'] = True

# add objects to job
existingObjects = [o['id'] for o in job['isilonParams']['objects']]
for objectid in objectids:
    if objectid not in existingObjects:
        job['isilonParams']['objects'].append({"id": objectid})
        existingObjects.append(objectid)

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

# update job
if newJob is True:
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
