#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--objectname', action='append', type=str)
parser.add_argument('-l', '--objectlist', type=str, default=None)
parser.add_argument('-ex', '--exclude', action='append', type=str)
parser.add_argument('-el', '--excludelist', type=str, default=None)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-q', '--qospolicy', type=str, choices=['kBackupHDD', 'kBackupSSD', 'kBackupAll'], default='kBackupHDD')
parser.add_argument('-r', '--backuprole', type=str, choices=['SecondaryPreferred', 'PrimaryPreferred', 'SecondaryOnly'], default='SecondaryPreferred')
parser.add_argument('-f', '--incrementalonfailure', action='store_true')
parser.add_argument('-pn','--preferredbackupnode',action='append', type=str) # preferredBackupNodes
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
objectname = args.objectname
objectlist = args.objectlist
exclude = args.exclude
excludelist = args.excludelist
jobname = args.jobname
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
storagedomain = args.storagedomain
pause = args.pause
qospolicy = args.qospolicy
backuprole = args.backuprole
incrementalonfailure = args.incrementalonfailure
preferredbackupnodes = args.preferredbackupnode

if noprompt is True:
    prompt = False
else:
    prompt = None

if pause:
    isPaused = True
else:
    isPaused = False

if incrementalonfailure:
    convertToFullOnFailure = True
else:
    convertToFullOnFailure = False

objectIds = {}

# get object ID
def getObjectIds(source):
    global objectIds
    def get_nodes(node, parent):
        name = node['protectionSource']['name'].lower()
        id = node['protectionSource']['id']
        if parent != '':
            name = '%s/%s' % (parent, name)
        objectIds[name] = id
        if 'nodes' in node:
            for node in node['nodes']:
                    get_nodes(node, name)

    get_nodes(source, '')

# gather list function
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


# get list of objects to protect
objects = gatherList(objectname, objectlist, name='objects', required=True)
excludes = gatherList(exclude, excludelist, name='excludes', required=False)

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
registeredSources = api('get', 'protectionSources/registrationInfo?environments=kMongoDBPhysical')
sources = {}

# get job info
newJob = False
protectionGroups = api('get', 'data-protect/protection-groups?environments=kMongoDBPhysical&isDeleted=false&isActive=true', v=2)
jobs = protectionGroups['protectionGroups']
job = [job for job in jobs if job['name'].lower() == jobname.lower()]

if not job or len(job) < 1:
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

    job = {
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
        "qosPolicy": qospolicy,
        "storageDomainId": sdid,
        "name": jobname,
        "environment": "kMongoDBPhysical",
        "isPaused": isPaused,
        "description": "",
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "mongodbOpsParams": {
            "objects": [],
            "excludeObjectIds": [],
            "convertToFullOnFailure": convertToFullOnFailure,
            "preferredNode": backuprole,
            "preferredBackupNodes": None
        }
    }
    if preferredbackupnodes is not None and len(preferredbackupnodes) > 0:
        job['mongodbOpsParams']['preferredBackupNodes'] = ','.join(preferredbackupnodes)
else:
    job = job[0]

for object in objects:
    oparts = object.split('/')
    # source
    sourcename = oparts[0]
    if sourcename.lower() not in sources:
        registeredSource = [s for s in registeredSources['rootNodes'] if s['rootNode']['name'].lower() == sourcename.lower()]
        if registeredSource is not None and len(registeredSource) > 0:
            source = api('get','protectionSources?environments=kMongoDBPhysical&id=%s' % registeredSource[0]['rootNode']['id'])
            sources[sourcename.lower()] = 'x'
            getObjectIds(source[0])
        else:
            print('source %s not found' % sourcename)
            exit(1)

    if object.lower() in objectIds:
        job['mongodbOpsParams']['objects'] = [o for o in job['mongodbOpsParams']['objects'] if o['id'] != objectIds[object.lower()]]
        job['mongodbOpsParams']['objects'].append({'id': objectIds[object.lower()]})
    else:
        print('object %s not found' % object)
        exit(1)

for object in excludes:
    if object.lower() in objectIds:
        job['mongodbOpsParams']['excludeObjectIds'] = [o for o in job['mongodbOpsParams']['excludeObjectIds'] if o['id'] != objectIds[object.lower()]]
        job['mongodbOpsParams']['excludeObjectIds'].append(objectIds[object.lower()])
    else:
        print('exclude object %s not found' % object)
        exit(1)

if len(job['mongodbOpsParams']['objects']) == 0:
    print('noting to protect')
    exit(1)

if newJob is True:
    print('Creating protection job %s' % jobname)
else:
    print('Updating protection job %s' % job['name'])

if newJob is True:
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
