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
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-sn', '--servername', type=str, default=None)
parser.add_argument('-su', '--serveruser', type=str, default=None)
parser.add_argument('-vn', '--viewname', type=str, default=None)
parser.add_argument('-s', '--script', type=str, default=None)
parser.add_argument('-ip', '--scriptparams', type=str, default=None)
parser.add_argument('-l', '--logscript', type=str, default=None)
parser.add_argument('-lp', '--logparams', type=str, default=None)
parser.add_argument('-f', '--fullscript', type=str, default=None)
parser.add_argument('-fp', '--fullparams', type=str, default=None)

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
incrementalsla = args.incrementalsla
fullsla = args.fullsla
pause = args.pause
servername = args.servername
serveruser = args.serveruser
viewname = args.viewname
script = args.script
scriptparams = args.scriptparams
logscript = args.logscript
logparams = args.logparams
fullscript = args.fullscript
fullparams = args.fullparams

if pause:
    isPaused = True
else:
    isPaused = False

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

# get cluster public key
sshInfo = api('post', 'clusters/ssh-public-key', {'workflowType': 'DataProtection'}, v=2)
if sshInfo is None or 'public_key' not in sshInfo or sshInfo['public_key'] is None:
    print('failed to get cluster public key')
    exit(1)
publicKey = sshInfo['public_key']

policies = api('get', 'data-protect/policies', v=2)['policies']
views = api('get', 'file-services/views?useCachedData=false&protocolAccesses=NFS,NFS4,S3', v=2)

# find existing job
job = None
jobs = api('get', 'data-protect/protection-groups?environments=kRemoteAdapter&isDeleted=false&isActive=true', v=2)
if jobs is not None and 'protectionGroups' in jobs and jobs['protectionGroups'] is not None and len(jobs['protectionGroups']) > 0:
    jobs = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if jobs is not None and len(jobs) > 0:
        job = jobs[0]

if job is not None:
    newJob = False
    policy = [p for p in policies if p['id'] == job['policyId']][0]

else:
    # new job
    newJob = True

    if policyname is None:
        print('-p, --policyname required')
        exit(1)

    if viewname is None:
        print('-vn, --viewname required')
        exit(1)

    if servername is None:
        print('-sn, --servername required')
        exit(1)

    if serveruser is None:
        print('-su, --serveruser required')
        exit(1)
    
    if script is None:
        print('-s, --script required')
        exit(1)

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
        "abortInBlackouts": False,
        "name": jobname,
        "environment": "kRemoteAdapter",
        "isPaused": isPaused,
        "description": "",
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "remoteAdapterParams": {
            "hosts": [
                {
                    "hostType": "kLinux"
                }
            ],
            "indexingPolicy": {
                "enableIndexing": False,
                "includePaths": [],
                "excludePaths": []
            }
        }
    }

# set policy
if policyname is not None:
    policy = [p for p in policies if p['name'].lower() == policyname.lower()]
    if policy is None or len(policy) == 0:
        print('Policy %s not found' % policyname)
        exit(1)
    else:
        policy = policy[0]
    job['policyId'] = policy['id']
else:
    policy = [p for p in policies if p['id'] == job['policyId']][0]

# set view settings
if viewname is not None:

    view = [v for v in views['views'] if v['name'].lower() == viewname.lower()]
    if view is None or len(view) == 0:
        print('view %s not found' % viewname)
        exit(1)
    else:
        view = view[0]

    job['remoteAdapterParams']['viewId'] = view['viewId']
    job['remoteAdapterParams']['remoteViewParams'] = {
        "createView": True,
        "viewName": view['name']
    }
    if 'storageDomainId' in job and job['storageDomainId'] != view['storageDomainId']:
        print('job %s and view %s are in different storage domains' % (jobname, viewname))
        exit(1)
    job['storageDomainId'] = view['storageDomainId']
else:
    view = [v for v in views['views'] if v['viewId'] == job['remoteAdapterParams']['viewId']][0]

# set host settings
if servername is not None:
    job['remoteAdapterParams']['hosts'][0]['hostname'] = servername
else:
    servername = job['remoteAdapterParams']['hosts'][0]['hostname']

if serveruser is not None:
    job['remoteAdapterParams']['hosts'][0]['username'] = serveruser
else:
    serveruser = job['remoteAdapterParams']['hosts'][0]['username']

# set script settings
if script is not None:
    job['remoteAdapterParams']['hosts'][0]['incrementalBackupScript'] = {
        "path": script,
        "params": scriptparams
    }
else:
    script = job['remoteAdapterParams']['hosts'][0]['incrementalBackupScript']['path']

if 'fullBackups' in policy['backupPolicy']['regular'] and len(policy['backupPolicy']['regular']['fullBackups']) > 0:
    if fullscript is None:
        fullscript = script
    if fullparams is None:
        fullparams = scriptparams
    job['remoteAdapterParams']['hosts'][0]['fullBackupScript'] = {
        "path": fullscript,
        "params": fullparams
    }

if 'log' in policy['backupPolicy']:
    if logscript is None:
        logscript = script
    if logparams is None:
        logparams = scriptparams
    job['remoteAdapterParams']['hosts'][0]['logBackupScript'] = {
        "path": logscript,
        "params": logparams
    }

# save job
if newJob is True:
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)

print('\n PG Name: %s' % jobname)
print('  Policy: %s' % policy['name'])
print('  Server: %s' % servername)
print('    User: %s' % serveruser)
print('  Script: %s' % script)
print('    View: %s' % view['name'])

if 'nfsMountPath' in view and view['nfsMountPath'] is not None:
    print('NFS Path: %s' % view['nfsMountPath'])
if 's3AccessPath' in view and view['s3AccessPath'] is not None:
    print(' S3 Path: %s' % view['s3AccessPath'])

print('\nCluster Public Key:')
print('%s\n' % publicKey)
