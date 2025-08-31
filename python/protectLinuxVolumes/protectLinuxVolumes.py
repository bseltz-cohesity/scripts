#!/usr/bin/env python
"""Add Physical Linux Servers to File-based Protection Job Using Python"""

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
parser.add_argument('-mfa', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-i', '--include', action='append', type=str)
parser.add_argument('-n', '--includelist', type=str)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludelist', type=str)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)
parser.add_argument('-ei', '--enableindexing', action='store_true')
parser.add_argument('-z', '--paused', action='store_true')
parser.add_argument('-pre', '--prescript', type=str, default=None)
parser.add_argument('-preargs', '--prescriptargs', type=str, default=None)
parser.add_argument('-pretimeout', '--prescripttimeout', type=int, default=900)
parser.add_argument('-prefail', '--prescriptfail', action='store_true')
parser.add_argument('-post', '--postscript', type=str, default=None)
parser.add_argument('-postargs', '--postscriptargs', type=str, default=None)
parser.add_argument('-posttimeout', '--postscripttimeout', type=int, default=900)
parser.add_argument('-al', '--alerton', action='append', type=str, default=[])
parser.add_argument('-ar', '--recipient', action='append', type=str, default=[])
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
servernames = args.servername         # name of server to protect
serverlist = args.serverlist          # file with server names
jobname = args.jobname                # name of protection job to add server to
includes = args.include               # include path
includelist = args.includelist        # file with include paths
excludes = args.exclude               # exclude path
excludelist = args.excludelist        # file with exclude paths
storagedomain = args.storagedomain    # storage domain for new job
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job
enableindexing = args.enableindexing  # enable indexing on new job
paused = args.paused                  # pause future runs
prescript = args.prescript            # prescript
prescriptargs = args.prescriptargs    # prescript arguments
prescripttimeout = args.prescripttimeout  # prescript timeout
prescriptfail = args.prescriptfail        # fail job if prescritp fails
postscript = args.postscript              # postscript
postscriptargs = args.postscriptargs      # post script args
postscripttimeout = args.postscripttimeout  # post script timeout
alerton = args.alerton
recipients = args.recipient

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

includedvolumes = gatherList(includes, includelist, name='included volumes', required=False)
excludedvolumes = gatherList(excludes, excludelist, name='excluded volumes', required=False)
servernames = gatherList(servernames, serverlist, name='servers', required=True)

# validate alert policy
if len(alerton) == 0:
    alerton = ['kFailure']
for alert in alerton:
    if alert not in ['None', 'none', 'kFailure', 'kSuccess', 'kSlaViolation']:
        print('--alerton must be None, kFailure, kSuccess, kSlaViolation')
        exit(1)
    if alert in ['None', 'none']:
        alerton = []

if prescriptfail is True:
    continueonerror = False
else:
    continueonerror = True

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

# get job info
newJob = False
job = None
protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
if protectionGroups is not None and len(protectionGroups) > 0 and 'protectionGroups' in protectionGroups and protectionGroups['protectionGroups'] is not None:
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
        "policyId": policyid,
        "priority": "kMedium",
        "storageDomainId": sdid,
        "description": "",
        "startTime": {
            "hour": int(hour),
            "minute": int(minute),
            "timeZone": timezone
        },
        "sla": [
            {
                "backupRunType": "kIncremental",
                "slaMinutes": int(incrementalsla)
            },
            {
                "backupRunType": "kFull",
                "slaMinutes": int(fullsla)
            }
        ],
        "qosPolicy": "kBackupHDD",
        "abortInBlackouts": False,
        "isActive": True,
        "isPaused": False,
        "environment": "kPhysical",
        "permissions": [],
        "physicalParams": {
            "protectionType": "kVolume",
            "volumeProtectionTypeParams": {
                "objects": [],
                "indexingPolicy": {
                    "enableIndexing": enableindexing,
                    "includePaths": [
                        "/"
                    ],
                    "excludePaths": [
                        "/$Recycle.Bin",
                        "/Windows",
                        "/Program Files",
                        "/Program Files (x86)",
                        "/ProgramData",
                        "/System Volume Information",
                        "/Users/*/AppData",
                        "/Recovery",
                        "/var",
                        "/usr",
                        "/sys",
                        "/proc",
                        "/lib",
                        "/grub",
                        "/grub2",
                        "/opt",
                        "/splunk"
                    ]
                },
                "excludedVssWriters": [],
                "quiesce": False,
                "continueOnQuiesceFailure": False,
                "performSourceSideDeduplication": False,
                "incrementalBackupAfterRestart": True
            }
        }
    }
    # add alert policy
    if len(alerton) > 0:
        job['alertPolicy'] = {
            "backupRunStatus": alerton,
            "alertTargets": []
        }
        for recipient in recipients:
            job['alertPolicy']['alertTargets'].append({
                "emailAddress": recipient,
                "locale": "en-us",
                "recipientType": "kTo"
            })
    if paused is True:
        job['isPaused'] = True
    if prescript is not None or postscript is not None:
        job['physicalParams']['fileProtectionTypeParams']['prePostScript'] = {}
    if prescript is not None:
        job['physicalParams']['fileProtectionTypeParams']['prePostScript']['preScript'] = {
            "path": prescript,
            "params": prescriptargs,
            "timeoutSecs": prescripttimeout,
            "continueOnError": continueonerror
        }
    if postscript is not None:
        job['physicalParams']['fileProtectionTypeParams']['prePostScript']['postScript'] = {
            "path": postscript,
            "params": postscriptargs,
            "timeoutSecs": postscripttimeout
        }
else:
    job = job[0]
    if 'physicalParams' not in job or job['physicalParams']['protectionType'] != 'kVolume':
        print("Job '%s' is not a block-based physical protection job" % jobname)
        exit(1)

# get registered physical servers
physicalServersRoot = api('get', 'protectionSources/rootNodes?allUnderHierarchy=false&environments=kPhysical')
physicalServersRootId = physicalServersRoot[0]['protectionSource']['id']
physicalServers = api('get', 'protectionSources?allUnderHierarchy=false&id=%s&includeEntityPermissionInfo=true' % physicalServersRootId)[0]['nodes']

for servername in servernames:
    # find server
    physicalServer = [s for s in physicalServers if s['protectionSource']['name'].lower() == servername.lower() and s['protectionSource']['physicalProtectionSource']['hostType'] != 'kWindows']
    if not physicalServer:
        print("******** %s is not a registered Linux/AIX/Solaris server ********" % servername)
    else:
        physicalServer = physicalServer[0]
        lvmvolumes = [v for v in physicalServer['protectionSource']['physicalProtectionSource']['volumes'] if 'guid' in v]
        if lvmvolumes is None or len(lvmvolumes) == 0:
            print('%s has no LVM volumes to protect' % servername)
            continue
        # get sourceSpecialParameters
        existingobject = [o for o in job['physicalParams']['volumeProtectionTypeParams']['objects'] if o['id'] == physicalServer['protectionSource']['id']]
        if len(existingobject) > 0:
            thisobject = existingobject[0]
            thisobject['volumeGuids'] = None
            print('  updating %s in job %s...' % (servername, jobname))
            newObject = False
        else:
            thisobject = {
                "id": physicalServer['protectionSource']['id'],
                "name": physicalServer['protectionSource']['name'],
                "enableSystemBackup": None,
                "volumeGuids": None,
                "excludedVssWriters": []
            }
            print('  adding %s to job %s...' % (servername, jobname))
            newObject = True

        # include/exclude volumes
        if len(includedvolumes) > 0 or len(excludedvolumes) > 0:
            if len(includedvolumes) > 0:
                for i in includedvolumes:
                    lvmvolume = [v for v in lvmvolumes if i.lower() in [v['guid'].lower(), v['label'].lower(), v['devicePath'].lower()] or ('mountPoints' in v and i in v['mountPoints'])]
                    if lvmvolume is not None and len(lvmvolume) > 0:
                        if thisobject['volumeGuids'] is None:
                            thisobject['volumeGuids'] = []
                        thisobject['volumeGuids'].append(lvmvolume[0]['guid'])
                    else:
                        print('  * volume %s not found on %s' % (i, servername))
            else:
                thisobject['volumeGuids'] = []
                for v in lvmvolumes:
                    includevolume = True
                    for e in excludedvolumes:
                        if e.lower() in [v['guid'].lower(), v['label'].lower(), v['devicePath'].lower()] or ('mountPoints' in v and e in v['mountPoints']):
                            includevolume = False
                    if includevolume is True:
                        if thisobject['volumeGuids'] is None:
                            thisobject['volumeGuids'] = []
                        thisobject['volumeGuids'].append(v['guid'])
                if len(thisobject['volumeGuids']) == 0:
                    print('  * No LVM volumes protected on %s, removing from job' % servername)
                    newObject == False
                    job['physicalParams']['volumeProtectionTypeParams']['objects'] = [o for o in job['physicalParams']['volumeProtectionTypeParams']['objects'] if o['id'] != physicalServer['protectionSource']['id']]
        # include new parameter
        if newObject is True:
            job['physicalParams']['volumeProtectionTypeParams']['objects'].append(thisobject)

# update job
if newJob is True:
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
