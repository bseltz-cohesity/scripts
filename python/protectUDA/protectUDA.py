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
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-n', '--objectname', action='append', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-cc', '--concurrency', type=int, default=1)
parser.add_argument('-m', '--mounts', type=int, default=1)
parser.add_argument('-fa', '--fullbackupargs', type=str, default='')
parser.add_argument('-ia', '--incrbackupargs', type=str, default='')
parser.add_argument('-la', '--logbackupargs', type=str, default='')
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-q', '--qospolicy', type=str, choices=['kBackupHDD', 'kBackupSSD'], default='kBackupHDD')
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-al', '--alerton', action='append', type=str, default=[])
parser.add_argument('-ar', '--recipient', action='append', type=str, default=[])
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
sourcename = args.sourcename
objectnames = args.objectname
jobname = args.jobname
concurrency = args.concurrency
mounts = args.mounts
fullbackupargs = args.fullbackupargs
incrbackupargs = args.incrbackupargs
logbackupargs = args.logbackupargs
storagedomain = args.storagedomain
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
qospolicy = args.qospolicy
pause = args.pause
alerton = args.alerton
recipients = args.recipient

# validate alert policy
if len(alerton) == 0:
    alerton = ['kFailure']
for alert in alerton:
    if alert not in ['None', 'none', 'kFailure', 'kSuccess', 'kSlaViolation']:
        print('--alerton must be None, kFailure, kSuccess, kSlaViolation')
        exit(1)
    if alert in ['None', 'none']:
        alerton = []

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# get registered UDA source
source = None
sources = api('get', 'protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kUDA')
if sources is not None and 'rootNodes' in sources and len(sources['rootNodes']) > 0:
    source = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == sourcename.lower()]
    if source is not None and len(source) > 0:
        source = source[0]
if source is None:
    print('UDA protection source "%s" not found' % sourcename)
    exit()

sourceId = source['rootNode']['id']
sourceName = source['rootNode']['name']

if objectnames is None:
    objectnames = []

# get the protectionJob
job = [j for j in (api('get', 'data-protect/protection-groups', v=2))['protectionGroups'] if j['name'].lower() == jobname.lower()]
if job is not None and len(job) > 0:
    print('Protection group "%s" already exists' % jobname)
    exit()

if pause:
    isPaused = True
else:
    isPaused = False

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

if len(objectnames) == 0:
    objectnames.append(sourceName)

jobParams = {
    "policyId": policy['id'],
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
    "storageDomainId": viewBox['id'],
    "name": jobname,
    "environment": "kUDA",
    "isPaused": isPaused,
    "description": "",
    "udaParams": {
        "sourceId": sourceId,
        "objects": [],
        "concurrency": concurrency,
        "mounts": mounts,
        "fullBackupArgs": fullbackupargs,
        "incrBackupArgs": incrbackupargs,
        "logBackupArgs": logbackupargs
    }
}

# add alert policy
if len(alerton) > 0:
    jobParams['alertPolicy'] = {
        "backupRunStatus": alerton,
        "alertTargets": []
    }
    for recipient in recipients:
        jobParams['alertPolicy']['alertTargets'].append({
            "emailAddress": recipient,
            "locale": "en-us",
            "recipientType": "kTo"
        })

for object in objectnames:
    jobParams['udaParams']['objects'].append({"name": object})

print('Creating protection job "%s"...' % jobname)
result = api('post', 'data-protect/protection-groups', jobParams, v=2)
