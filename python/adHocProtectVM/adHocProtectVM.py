#!/usr/bin/env python
"""BackupNow for python"""

# version 2023.11.20

# extended error codes
# ====================
# 0: Successful
# 1: Unsuccessful
# 2: connection/authentication error
# 3: Syntax Error
# 4: Timed out waiting for existing run to finish
# 5: Timed out waiting for status update
# 6: Timed out waiting for new run to appear
# 7: Timed out getting job
# 8: Target not in policy not allowed

# import pyhesity wrapper module
from pyhesity import *
from time import sleep
from datetime import datetime
from sys import exit
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mfacode', '--mfacode', type=str, default=None)
parser.add_argument('-j', '--jobName', type=str, default=None)
parser.add_argument('-l', '--localonly', action='store_true')
parser.add_argument('-nr', '--noreplica', action='store_true')
parser.add_argument('-na', '--noarchive', action='store_true')
parser.add_argument('-k', '--keepLocalFor', type=int, default=None)
parser.add_argument('-r', '--replicateTo', type=str, default=None)
parser.add_argument('-kr', '--keepReplicaFor', type=int, default=None)
parser.add_argument('-a', '--archiveTo', type=str, default=None)
parser.add_argument('-ka', '--keepArchiveFor', type=int, default=None)
parser.add_argument('-pr', '--progress', action='store_true')
parser.add_argument('-t', '--backupType', type=str, choices=['kRegular'], default='kRegular')
parser.add_argument('-x', '--abortifrunning', action='store_true')
parser.add_argument('-f', '--logfile', type=str, default=None)
parser.add_argument('-n', '--waitminutesifrunning', type=int, default=60)
parser.add_argument('-nrt', '--newruntimeoutsecs', type=int, default=3000)
parser.add_argument('-debug', '--debug', action='store_true')
parser.add_argument('-ex', '--extendederrorcodes', action='store_true')
parser.add_argument('-s', '--sleeptimesecs', type=int, default=360)
parser.add_argument('-sr', '--statusretries', type=int, default=10)
parser.add_argument('-swt', '--startwaittime', type=int, default=60)
parser.add_argument('-rwt', '--retrywaittime', type=int, default=300)
parser.add_argument('-to', '--timeoutsec', type=int, default=300)
parser.add_argument('-iswt', '--interactivestartwaittime', type=int, default=15)
parser.add_argument('-irwt', '--interactiveretrywaittime', type=int, default=30)
parser.add_argument('-int', '--interactive', action='store_true')
parser.add_argument('-vn', '--vmname', action='append', type=str)
parser.add_argument('-vl', '--vmlist', type=str)
parser.add_argument('-rs', '--refreshsource', action='store_true')
parser.add_argument('-vc', '--vcentername', type=str, default=None)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-pn', '--policyname', type=str, default=None)
parser.add_argument('-ei', '--enableindexing', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
clustername = args.clustername
mcm = args.mcm
mfacode = args.mfacode
jobName = args.jobName
keepLocalFor = args.keepLocalFor
replicateTo = args.replicateTo
keepReplicaFor = args.keepReplicaFor
archiveTo = args.archiveTo
keepArchiveFor = args.keepArchiveFor
backupType = args.backupType
localonly = args.localonly
noreplica = args.noreplica
noarchive = args.noarchive
abortIfRunning = args.abortifrunning
logfile = args.logfile
waitminutesifrunning = args.waitminutesifrunning
newruntimeoutsecs = args.newruntimeoutsecs
debugger = args.debug
extendederrorcodes = args.extendederrorcodes
sleeptimesecs = args.sleeptimesecs
progress = args.progress
statusretries = args.statusretries
startwaittime = args.startwaittime
retrywaittime = args.retrywaittime
timeoutsec = args.timeoutsec
interactivestartwaittime = args.interactivestartwaittime
interactiveretrywaittime = args.interactiveretrywaittime
interactive = args.interactive
vmname = args.vmname
vmlist = args.vmlist
refreshsource = args.refreshsource
vcentername = args.vcentername
storagedomain = args.storagedomain
policyname = args.policyname
enableindexing = args.enableindexing

cacheSetting = 'false'

if enableindexing:
    indexingEnabled = True
else:
    indexingEnabled = False

if interactive:
    startwaittime = interactivestartwaittime
    retrywaittime = interactiveretrywaittime

# enforce sleep time
if sleeptimesecs < 30:
    sleeptimesecs = 30

if newruntimeoutsecs < 720:
    newruntimeoutsecs = 720

if noprompt is True:
    prompt = False
else:
    prompt = None

wait = True

if logfile is not None:
    try:
        log = codecs.open(logfile, 'w', 'utf-8')
        log.write('%s: Script started\n\n' % datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        log.write('Command line parameters:\n\n')
        for arg, value in sorted(vars(args).items()):
            log.write("    %s: %s\n" % (arg, value))
        log.write('\n')
    except Exception:
        print('Unable to open log file %s' % logfile)
        exit(1)


def out(message, quiet=False):
    if quiet is not True:
        print(message)
    if logfile is not None:
        log.write('%s\n' % message)


def bail(code=0):
    if logfile is not None:
        log.close()
    exit(code)


if 'api_version' not in globals() or api_version < '2022.09.13':
    out('this script requires pyhesity.py version 2022.09.13 or later')
    if extendederrorcodes is True:
        bail(3)
    else:
        bail(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if LAST_API_ERROR() != 'OK':
    out(LAST_API_ERROR(), quiet=True)
    if extendederrorcodes is True:
        bail(2)
    else:
        bail(1)

if apiconnected() is False:
    out('\nFailed to connect to Cohesity cluster')
    if extendederrorcodes is True:
        bail(2)
    else:
        bail(1)

sources = {}


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


vmnames = gatherList(vmname, vmlist, name='VMs', required=True)


# refresh vCenter
def waitForRefresh(sourceId):
    authStatus = ''
    while authStatus != 'Finished':
        rootFinished = False
        sleep(5)
        rootNodes = api('get', 'protectionSources/registrationInfo?ids=%s&includeApplicationsTreeInfo=false' % sourceId)
        rootNode = [r for r in rootNodes['rootNodes'] if r['rootNode']['id'] == sourceId]
        if rootNode[0]['registrationInfo']['authenticationStatus'] == 'kFinished':
            rootFinished = True
        if rootFinished is True:
            authStatus = 'Finished'


# find protectionJob
jobs = None
newJob = False
jobRetries = 0

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

if jobName is None:
    jobName = 'VM-%s' % nowUsecs

jobs = api('get', 'data-protect/protection-groups?names=%s&environments=kVMware&isActive=true&isDeleted=false&useCachedData=%s' % (jobName, cacheSetting), v=2, timeout=timeoutsec)

if jobs['protectionGroups'] is None:
    newJob = True
    # get vcenter
    if vcentername is None:
        print('vcentername required')
        exit(1)
    else:
        vcenters = api('get', 'protectionSources/rootNodes?environments=kVMware')
        vcenter = [v for v in vcenters if v['protectionSource']['name'].lower() == vcentername.lower()]
        if not vcenters or len(vcenters) == 0:
            print('vCenter %s not registered' % vcentername)
            exit(1)
        else:
            vcenter = vcenters[0]

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

    # new job params
    job = {
        "name": jobName,
        "environment": "kVMware",
        "isPaused": True,
        "policyId": policy['id'],
        "priority": "kMedium",
        "storageDomainId": viewBox['id'],
        "description": "",
        "startTime": {
            "hour": 21,
            "minute": 00,
            "timeZone": 'US/Eastern'
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
                "slaMinutes": 360
            },
            {
                "backupRunType": "kIncremental",
                "slaMinutes": 360
            }
        ],
        "qosPolicy": "kBackupHDD",
        "vmwareParams": {
            "sourceId": vcenter['protectionSource']['id'],
            "sourceName": vcenter['protectionSource']['name'],
            "objects": [],
            "excludeObjectIds": [],
            "vmTagIds": [],
            "excludeVmTagIds": [],
            "appConsistentSnapshot": False,
            "fallbackToCrashConsistentSnapshot": False,
            "skipPhysicalRDMDisks": False,
            "globalExcludeDisks": [],
            "leverageHyperflexSnapshots": False,
            "leverageStorageSnapshots": False,
            "cloudMigration": False,
            "indexingPolicy": {
                "enableIndexing": indexingEnabled,
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
                    "/opt/splunk",
                    "/splunk"
                ]
            }
        }
    }
else:
    job = [job for job in jobs['protectionGroups'] if job['name'].lower() == jobName.lower()]
    job = job[0]

jobName = job['name']
environment = job['environment']
if refreshsource:
    print('Performing source refresh on %s' % job['vmwareParams']['sourceName'])
    result = api('post', 'protectionSources/refresh/%s' % job['vmwareParams']['sourceId'])
    waitForRefresh(job['vmwareParams']['sourceId'])

sources = api('get', 'protectionSources/virtualMachines?vCenterId=%s&useCachedData=%s' % (job['vmwareParams']['sourceId'], cacheSetting), timeout=timeoutsec)

# handle run now objects
sourceIds = []
selectedSources = []

vmsAdded = False
vmsToRemove = []
for vmname in vmnames:
    sourceId = None
    thisSource = [s for s in sources if s['name'].lower() == vmname.lower()]
    if thisSource is not None and len(thisSource) > 0:
        sourceId = thisSource[0]['id']
        sourceIds.append(sourceId)
        selectedSources.append(sourceId)
        if sourceId not in [o['id'] for o in job['vmwareParams']['objects']]:
            vmsAdded = True
            vmsToRemove.append(sourceId)
            job['vmwareParams']['objects'].append({
                "excludeDisks": None,
                "id": sourceId,
                "name": thisSource[0]['name'],
                "isAutoprotected": False
            })
        print('%s added' % thisSource[0]['name'])
    else:
        out('%s *** not found ***' % vmname)
        if extendederrorcodes is True:
            bail(3)
        else:
            bail(1)

if len(sourceIds) == 0:
    out('no VMs found, exiting')
    if extendederrorcodes is True:
        bail(3)
    else:
        bail(1)

if newJob is True:
    job = api('post', 'data-protect/protection-groups', job, v=2)
else:
    job = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)

v2JobId = job['id']
v1JobId = v2JobId.split(':')[2]

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning', 'kCanceling', '3', '4', '5', '6', 'Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning']

jobData = {
    "copyRunTargets": [],
    "sourceIds": sourceIds,
    "runType": backupType,
    "usePolicyDefaults": True
}

# use base retention and copy targets from policy
policy = api('get', 'protectionPolicies/%s' % job['policyId'], timeout=timeoutsec)

# replication
if localonly is not True and noreplica is not True:
    if 'snapshotReplicationCopyPolicies' in policy and replicateTo is None:
        for replica in policy['snapshotReplicationCopyPolicies']:
            if replica['target'] not in [p.get('replicationTarget', None) for p in jobData['copyRunTargets']]:
                if keepReplicaFor is not None:
                    replica['daysToKeep'] = keepReplicaFor
                jobData['copyRunTargets'].append({
                    "daysToKeep": replica['daysToKeep'],
                    "replicationTarget": replica['target'],
                    "type": "kRemote"
                })
# archival
if localonly is not True and noarchive is not True:
    if 'snapshotArchivalCopyPolicies' in policy and archiveTo is None:
        for archive in policy['snapshotArchivalCopyPolicies']:
            if archive['target'] not in [p.get('archivalTarget', None) for p in jobData['copyRunTargets']]:
                if keepArchiveFor is not None:
                    archive['daysToKeep'] = keepArchiveFor
                jobData['copyRunTargets'].append({
                    "archivalTarget": archive['target'],
                    "daysToKeep": archive['daysToKeep'],
                    "type": "kArchival"
                })

# use copy targets specified at the command line
if replicateTo is not None:
    if keepReplicaFor is None:
        out("--keepReplicaFor is required")
        if extendederrorcodes is True:
            bail(3)
        else:
            bail(1)
    remote = [remote for remote in api('get', 'remoteClusters', timeout=timeoutsec) if remote['name'].lower() == replicateTo.lower()]
    if len(remote) > 0:
        remote = remote[0]
        jobData['copyRunTargets'].append({
            "type": "kRemote",
            "daysToKeep": keepReplicaFor,
            "replicationTarget": {
                "clusterId": remote['clusterId'],
                "clusterName": remote['name']
            }
        })
    else:
        out("Remote Cluster %s not found!" % replicateTo)
        if extendederrorcodes is True:
            bail(3)
        else:
            bail(1)

if archiveTo is not None:
    if keepArchiveFor is None:
        out("--keepArchiveFor is required")
        if extendederrorcodes is True:
            bail(3)
        else:
            bail(1)
    vault = [vault for vault in api('get', 'vaults', timeout=timeoutsec) if vault['name'].lower() == archiveTo.lower()]
    if len(vault) > 0:
        vault = vault[0]
        jobData['copyRunTargets'].append({
            "archivalTarget": {
                "vaultId": vault['id'],
                "vaultName": vault['name'],
                "vaultType": "kCloud"
            },
            "daysToKeep": keepArchiveFor,
            "type": "kArchival"
        })
    else:
        out("Archive target %s not found!" % archiveTo)
        if extendederrorcodes is True:
            bail(3)
        else:
            bail(1)

# get last run ID
runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=1&includeObjectDetails=false&useCachedData=%s' % (v2JobId, cacheSetting), v=2, timeout=timeoutsec)
if runs is not None and 'runs' in runs and len(runs['runs']) > 0:
    newRunId = lastRunId = runs['runs'][0]['protectionGroupInstanceId']
    lastRunUsecs = runs['runs'][0]['localBackupInfo']['startTimeUsecs']
else:
    newRunId = lastRunId = 1
    lastRunUsecs = 1662164882000000

# run protectionJob
startUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
waitUntil = nowUsecs + (waitminutesifrunning * 60000000)
reportWaiting = True
if debugger:
    print(':DEBUG: waiting for new run to be accepted')
runNow = api('post', "protectionJobs/run/%s" % v1JobId, jobData, quiet=True, timeout=timeoutsec)
while runNow != "":
    runError = LAST_API_ERROR()
    if 'Protection group can only have one active backup run at a time' not in runError and 'Backup job has an existing active backup run' not in runError:
        out(runError)
        if 'TARGET_NOT_IN_POLICY_NOT_ALLOWED' in runError:
            if extendederrorcodes is True:
                bail(8)
            else:
                bail(1)
        if 'InvalidRequest' in runError:
            if extendederrorcodes is True:
                bail(3)
            else:
                bail(1)
    else:
        if reportWaiting is True:
            if abortIfRunning:
                out('job is already running')
                bail(0)
            out('Waiting for existing run to finish')
            reportWaiting = False
    now = datetime.now()
    nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
    if nowUsecs >= waitUntil:
        out('Timed out waiting for existing run')
        if extendederrorcodes is True:
            bail(4)
        else:
            bail(1)
    sleep(retrywaittime)
    if debugger:
        runNow = api('post', "protectionJobs/run/%s" % v1JobId, jobData, timeout=timeoutsec)
    else:
        runNow = api('post', "protectionJobs/run/%s" % v1JobId, jobData, quiet=True, timeout=timeoutsec)
out("Running %s..." % jobName)

# wait for new job run to appear
if wait is True:
    timeOutUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    while newRunId <= lastRunId:
        sleep(startwaittime)
        if len(selectedSources) > 0:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=10&includeObjectDetails=true&useCachedData=%s' % (v2JobId, cacheSetting), v=2, timeout=timeoutsec)
            if runs is not None and 'runs' in runs and len(runs['runs']) > 0:
                runs = [r for r in runs['runs'] if selectedSources[0] in [o['object']['id'] for o in r['objects']]]
        else:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=1&includeObjectDetails=false&useCachedData=%s' % (v2JobId, cacheSetting), v=2, timeout=timeoutsec)
            if runs is not None and 'runs' in runs and len(runs['runs']) > 0:
                runs = runs['runs']
        if runs is not None and 'runs' not in runs and len(runs) > 0:
            runs = [r for r in runs if r['protectionGroupInstanceId'] > lastRunId]
        if runs is not None and 'runs' not in runs and len(runs) > 0:
            newRunId = runs[0]['protectionGroupInstanceId']
            v2RunId = runs[0]['id']
        if debugger:
            print(':DEBUG: Previous Run ID: %s' % lastRunId)
            print(':DEBUG:   Latest Run ID: %s\n' % newRunId)
        # timeout waiting for new run to appear
        nowUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        if (timeOutUsecs + (newruntimeoutsecs * 1000000)) < nowUsecs:
            out("Timed out waiting for new run to appear")
            if extendederrorcodes is True:
                bail(6)
            else:
                bail(1)
        if newRunId > lastRunId:
            run = runs[0]
            break
        sleep(retrywaittime)
    out("New Job Run ID: %s" % v2RunId)

# remove added VMs
if vmsAdded is True:
    if newJob is True:
        result = api('delete', 'data-protect/protection-groups/%s' % job['id'], {'deleteSnapshots': False}, v=2)
    else:
        job['vmwareParams']['objects'] = [o for o in job['vmwareParams']['objects'] if o['id'] not in vmsToRemove]
        job = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)

# wait for job run to finish and report completion
if wait is True:
    status = 'unknown'
    lastProgress = -1
    statusRetryCount = 0
    while status not in finishedStates:
        x = 0
        s = 0
        if lastProgress < 100:
            sleep(sleeptimesecs)
        try:
            status = run['localBackupInfo']['status']
            if status in finishedStates:
                break
            # wait for percent complete to reach 100
            while lastProgress < 100:
                try:
                    progressPath = run['localBackupInfo']['progressTaskId']
                    progressMonitor = api('get', '/progressMonitors?taskPathVec=%s&excludeSubTasks=false&includeFinishedTasks=false' % progressPath, timeout=timeoutsec)
                    progressTotal = progressMonitor['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                    percentComplete = int(round(progressTotal))
                    statusRetryCount = 0
                    if percentComplete > lastProgress:
                        if progress:
                            out('%s%% completed' % percentComplete)
                        lastProgress = percentComplete
                    if percentComplete < 100:
                        sleep(sleeptimesecs)
                except Exception:
                    sleep(sleeptimesecs)
                    statusRetryCount += 1
                    if statusRetryCount > statusretries:
                        out("Timed out waiting for status update")
                        if extendederrorcodes is True:
                            bail(5)
                        else:
                            bail(1)
            statusRetryCount = 0
            run = api('get', 'data-protect/protection-groups/%s/runs/%s?includeObjectDetails=false&useCachedData=%s' % (v2JobId, v2RunId, cacheSetting), v=2, timeout=timeoutsec)
        except Exception:
            statusRetryCount += 1
            if debugger:
                ":DEBUG: error getting updated status"
            else:
                pass
            if statusRetryCount > statusretries:
                out("Timed out waiting for status update")
                if extendederrorcodes is True:
                    bail(5)
                else:
                    bail(1)
    out("Job finished with status: %s" % run['localBackupInfo']['status'])
    if run['localBackupInfo']['status'] == 'Failed':
        out('Error: %s' % run['localBackupInfo']['messages'][0])
    if run['localBackupInfo']['status'] == 'SucceededWithWarning':
        out('Warning: %s' % run['localBackupInfo']['messages'][0])

# return exit code
if wait is True:
    if logfile is not None:
        try:
            log.write('Backup ended %s\n' % usecsToDate(run['localBackupInfo']['endTimeUsecs']))
        except Exception:
            log.write('Backup ended')
    if run['localBackupInfo']['status'] == 'Succeeded' or run['localBackupInfo']['status'] == 'SucceededWithWarning':
        bail(0)
    else:
        bail(1)
else:
    bail(0)
