#!/usr/bin/env python
"""Protect Cassandra Using Python"""

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
parser.add_argument('-n', '--objectname', action='append', type=str)
parser.add_argument('-l', '--objectlist', type=str)
parser.add_argument('-sk', '--systemkeyspaces', action='store_true')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludelist', type=str)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-cc', '--concurrency', type=int, default=None)
parser.add_argument('-bw', '--bandwidth', type=int, default=None)
parser.add_argument('-dc', '--datacenter', action='append', type=str)
parser.add_argument('-ar', '--alertrecipient', action='append', type=str)
parser.add_argument('-av', '--alertslaviolation', action='store_true')
parser.add_argument('-as', '--alertsuccess', action='store_true')

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

sourcename = args.sourcename
objectnames = args.objectname
objectlist = args.objectlist
excludes = args.exclude
excludelist = args.excludelist
systemkeyspaces = args.systemkeyspaces
concurrency = args.concurrency
bandwidth = args.bandwidth
datacenters = args.datacenter

jobname = args.jobname
storagedomain = args.storagedomain
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
pause = args.pause
alertrecipients = args.alertrecipient
alertslaviolation = args.alertslaviolation
alertsuccess = args.alertsuccess

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

objectnames = gatherList(objectnames, objectlist, name='includes', required=False)
excludes = gatherList(excludes, excludelist, name='excludes', required=False)

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

# get protection source
sources = api('get', 'protectionSources/rootNodes?allUnderHierarchy=false&environments=kCassandra&includeExternalMetadata=true')
source = [s for s in sources if s['protectionSource']['name'].lower() == sourcename.lower() or s['protectionSource']['customName'].lower() == sourcename.lower()]
if source is None or len(source) == 0:
    print('Cassandra protection source "%s" not found!' % sourcename)
    exit(1)
else:
    source = api('get', 'protectionSources?useCachedData=false&includeEntityPermissionInfo=true&id=%s&allUnderHierarchy=false' % source[0]['protectionSource']['id'])[0]

# get job info
newJob = False
protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&environments=kCassandra', v=2)
jobs = protectionGroups['protectionGroups']
job = None
if jobs is not None and len(jobs) > 0:
    job = [j for j in jobs if j['name'].lower() == jobname.lower()]

if job is None or len(job) == 0:
    newJob = True

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

    job = {
        "policyId": policy['id'],
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
        "pauseInBlackouts": False,
        "storageDomainId": viewBox['id'],
        "name": jobname,
        "environment": "kCassandra",
        "isPaused": False,
        "description": "",
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "cassandraParams": {
            "objects": [],
            "concurrency": 16,
            "bandwidthMBPS": None,
            "dataCenters": [],
            "isLogBackup": False,
            "excludeObjectIds": None,
            "isSystemKeyspaceBackup": False
        }
    }
    if datacenters is not None and len(datacenters) > 0:
        job['cassandraParams']['dataCenters'] = datacenters
    if systemkeyspaces is True:
        job['cassandraParams']['isSystemKeyspaceBackup'] = True
else:
    # existing job
    job = job[0]
    if job['cassandraParams']['isSystemKeyspaceBackup'] is True:
        print('existing Job protects system keyspaces')
        systemkeyspaces = True
    else:
        print('existing job protects regular keyspaces')
        systemkeyspaces = False

if alertrecipients is not None and len(alertrecipients) > 0:    
    for r in alertrecipients:
        job['alertPolicy']['alertTargets'] = [t for t in job['alertPolicy']['alertTargets'] if t['emailAddress'].lower() != r.lower()]
        job['alertPolicy']['alertTargets'].append({
            "emailAddress": r,
            "language": "en-us",
            "recipientType": "kTo"
        })
if alertslaviolation is True:
    job['alertPolicy']['backupRunStatus'].append('kSlaViolation')
    job['alertPolicy']['backupRunStatus'] = list(set(job['alertPolicy']['backupRunStatus']))
if alertsuccess is True:
    job['alertPolicy']['backupRunStatus'].append('kSuccess')
    job['alertPolicy']['backupRunStatus'] = list(set(job['alertPolicy']['backupRunStatus'])) 

keyspaceType = 'kRegular'
if systemkeyspaces is True:
    keyspaceType = 'kSystem'

objects = {}
systemKeyspaceIDs = []

# enumerate keyspaces/tables
keyspaces = [n for n in source['nodes'] if n['protectionSource']['cassandraProtectionSource']['keyspaceInfo']['type'] == keyspaceType]
for keyspace in keyspaces:
    objects[keyspace['protectionSource']['name']] = keyspace['protectionSource']['id']
    if keyspaceType == 'kSystem':
        systemKeyspaceIDs.append(keyspace['protectionSource']['id'])
    if 'nodes' in keyspace:
        for table in keyspace['nodes']:
            objects['%s/%s' % (keyspace['protectionSource']['name'].lower(), table['protectionSource']['name'].lower())] = table['protectionSource']['id']

# configure job settings
if pause is True:
    job['isPaused'] = True

if concurrency is not None:
    job['cassandraParams']['concurrency'] = concurrency

if bandwidth is not None:
    job['cassandraParams']['bandwidthMBPS'] = bandwidth

# add selected objects
if len(objectnames) == 0:
    if systemkeyspaces is True:
        for k in systemKeyspaceIDs:
            job['cassandraParams']['objects'] = [o for o in job['cassandraParams']['objects'] if o['id'] != k]
            job['cassandraParams']['objects'].append({"id": k})
    else:    
        job['cassandraParams']['objects'] = [{"id": source['protectionSource']['id']}]
else:
    for objectname in objectnames:
        objectid = objects.get(objectname.lower(), None)
        if objectid is None:
            print('Object %s not found!' % objectname)
            exit(1)
        else:
            job['cassandraParams']['objects'] = [o for o in job['cassandraParams']['objects'] if o['id'] != objectid]
            job['cassandraParams']['objects'].append({"id": objectid})

# add exclusions
if len(excludes) > 0:
    if job['cassandraParams']['isSystemKeyspaceBackup'] is True:
        print('exlusions are not supported for system keyspace backups')
    else:
        for objectname in excludes:
            objectid = objects.get(objectname.lower(), None)
            if objectid is None:
                print('Object %s not found!' % objectname)
                exit(1)
            else:
                if job['cassandraParams']['excludeObjectIds'] is None:
                    job['cassandraParams']['excludeObjectIds'] = []
                if objectid not in job['cassandraParams']['excludeObjectIds']:
                    job['cassandraParams']['excludeObjectIds'].append(objectid)

# update job
if newJob is True:
    print('Creating protection job "%s"' % jobname)
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print('Updating protection job "%s"' % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
