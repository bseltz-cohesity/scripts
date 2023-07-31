#!/usr/bin/env python

from pyhesity import *
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
parser.add_argument('-n', '--objectname', action='append', type=str)
parser.add_argument('-l', '--objectlist', type=str, default=None)
parser.add_argument('-ex', '--exclude', action='store_true')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-q', '--qospolicy', type=str, choices=['kBackupHDD', 'kBackupSSD', 'kBackupAll'], default='kBackupHDD')
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-streams', '--streams', type=int, default=16)

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
objectname = args.objectname
objectlist = args.objectlist
exclude = args.exclude
sourcename = args.sourcename
streams = args.streams
jobname = args.jobname
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
storagedomain = args.storagedomain
pause = args.pause
qospolicy = args.qospolicy

if noprompt is True:
    prompt = False
else:
    prompt = None

if pause:
    isPaused = True
else:
    isPaused = False


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


# get list of views to protect
objects = gatherList(objectname, objectlist, name='objects', required=False)

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True, prompt=prompt)
else:
    if emailmfacode:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, emailMfaCode=True, prompt=prompt)
    else:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, mfaCode=mfacode, prompt=prompt)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if apiconnected() is False:
    print('authentication failed')
    exit(1)

# get protection source
registeredSource = [r for r in (api('get', 'protectionSources/registrationInfo?environments=kMongoDB'))['rootNodes'] if r['rootNode']['name'].lower() == sourcename.lower()]
if registeredSource is None or len(registeredSource) == 0:
    print('%s is not a registered MongoDB source' % sourcename)
    exit(1)

source = api('get', 'protectionSources?id=%s' % registeredSource[0]['rootNode']['id'])
source = source[0]
objectIds = {}
if 'nodes' not in source or source['nodes'] is None or len(source['nodes']) == 0:
    print('no databases on %s' % sourcename)
    exit(0)

for database in source['nodes']:
    objectIds[database['protectionSource']['name']] = database['protectionSource']['id']
    for collection in database['nodes']:
        objectIds['%s.%s' % (database['protectionSource']['name'], collection['protectionSource']['name'])] = collection['protectionSource']['id']

# get job info
newJob = False
protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
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
        "environment": "kMongoDB",
        "isPaused": isPaused,
        "description": "",
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "mongodbParams": {
            "objects": [],
            "concurrency": streams,
            "excludeObjectIds": [],
            "bandwidthMBPS": None,
            "sourceName": registeredSource[0]['rootNode']['name'],
            "sourceId": registeredSource[0]['rootNode']['id']
        }
    }
else:
    job = job[0]

if newJob is True:
    print('Creating protection job %s' % jobname)
else:
    print('Updating protection job %s' % job['name'])

if len(objects) == 0 or exclude:
    print('protecting %s' % sourcename)
    job['mongodbParams']['objects'] = [
        {
            "id": registeredSource[0]['rootNode']['id']
        }
    ]

for oName in objects:
    if oName in objectIds:
        if exclude:
            job['mongodbParams']['excludeObjectIds'].append(objectIds[oName])
            print('excluding %s' % oName)
        else:
            existingObject = [o for o in job['mongodbParams']['objects'] if o['id'] == objectIds[oName]]
            if existingObject is None or len(existingObject) == 0:
                job['mongodbParams']['objects'].append({"id": objectIds[oName]})
                print('protecting %s' % oName)
            else:
                print('%s already protected' % oName)
    else:
        print('%s not found' % oName)

if len(job['mongodbParams']['objects']) == 0:
    print('noting to protect')
    exit(0)

if newJob is True:
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
