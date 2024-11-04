#!/usr/bin/env python
"""BackupNow for python"""

# version 2024.10.28

# version history
# ===============
# 2023.01.10 - enforce sleeptimesecs >= 30 and newruntimeoutsecs >= 720
# 2023.02.17 - implement retry on get protectionJobs - added error code 7
# 2023.03.29 - version bump
# 2023.04.11 - fixed bug in line 70 - last run is None error, added metafile check for new run
# 2023.04.13 - fixed log archiving bug
# 2023.04.14 - fixed metadatafile watch bug
# 2023.06.25 - added -pl --purgeoraclelogs (first added 2023-06-08)
# 2023.07.05 - updated payload to solve p11 error "TARGET_NOT_IN_POLICY_NOT_ALLOWED%!(EXTRA int64=0)"
# 2023-08-14 - updated script to exit with failure on "TARGET_NOT_IN_POLICY_NOT_ALLOWED"
# 2023-09-03 - added support for read replica, various optimizations and fixes, increased sleepTimeSecs to 360, increased newruntimeoutsecs to 3000
# 2023-09-06 - added --timeoutsec 300, --nocache, granular sleep times, interactive mode, default sleepTimeSecs 3000
# 2023-09-13 - improved error handling on start request, exit on kInvalidRequest
# 2023-11-20 - tighter API call to find protection job, monitor completion with progress API rather than runs API
# 2023-11-29 - fixed hang on object not in job run
# 2023-12-03 - version bump
# 2023-12-11 - Added Succeeded with Warning extended exit code 9
# 2024.02.19 - expanded existing run string matches
# 2024.03.06 - moved cache wait until after authentication
# 2024.03.07 - minor updates to progress loop
# 2024.03.08 - refactored status monitor loop, added -q --quickdemo mode
# 2024.06.03 - fix unintended replication/archival
# 2024.06.07 - added support for Entra ID (Open ID) authentication
# 2024.07.08 - reintroduced -k, --keepLocalFor functionality
# 2024.09.06 - added support for Ft Knox
# 2024-10-28 - fixed oracle log purge
#
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
# 9: Succeeded with Warnings

# import pyhesity wrapper module
from pyhesity import *
from time import sleep
from datetime import datetime
from sys import exit
import codecs
import copy

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-v2', '--vip2', type=str, default=None)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mfacode', '--mfacode', type=str, default=None)
parser.add_argument('-j', '--jobName', type=str, required=True)
parser.add_argument('-j2', '--jobName2', type=str, default=None)
parser.add_argument('-y', '--usepolicy', action='store_true')
parser.add_argument('-l', '--localonly', action='store_true')
parser.add_argument('-nr', '--noreplica', action='store_true')
parser.add_argument('-na', '--noarchive', action='store_true')
parser.add_argument('-k', '--keepLocalFor', type=int, default=None)
parser.add_argument('-r', '--replicateTo', type=str, default=None)
parser.add_argument('-kr', '--keepReplicaFor', type=int, default=None)
parser.add_argument('-a', '--archiveTo', type=str, default=None)
parser.add_argument('-ka', '--keepArchiveFor', type=int, default=None)
parser.add_argument('-e', '--enable', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-pr', '--progress', action='store_true')
parser.add_argument('-t', '--backupType', type=str, choices=['kLog', 'kRegular', 'kFull'], default='kRegular')
parser.add_argument('-o', '--objectname', action='append', type=str)
parser.add_argument('-m', '--metadatafile', type=str, default=None)
parser.add_argument('-x', '--abortifrunning', action='store_true')
parser.add_argument('-f', '--logfile', type=str, default=None)
parser.add_argument('-n', '--waitminutesifrunning', type=int, default=60)
parser.add_argument('-cp', '--cancelpreviousrunminutes', type=int, default=0)
parser.add_argument('-nrt', '--newruntimeoutsecs', type=int, default=3000)
parser.add_argument('-debug', '--debug', action='store_true')
parser.add_argument('-ex', '--extendederrorcodes', action='store_true')
parser.add_argument('-s', '--sleeptimesecs', type=int, default=360)
parser.add_argument('-es', '--exitstring', type=str, default=None)
parser.add_argument('-est', '--exitstringtimeoutsecs', type=int, default=120)
parser.add_argument('-sr', '--statusretries', type=int, default=10)
parser.add_argument('-pl', '--purgeoraclelogs', action='store_true')
parser.add_argument('-nc', '--nocache', action='store_true')
parser.add_argument('-swt', '--startwaittime', type=int, default=60)
parser.add_argument('-cwt', '--cachewaittime', type=int, default=60)
parser.add_argument('-rwt', '--retrywaittime', type=int, default=300)
parser.add_argument('-to', '--timeoutsec', type=int, default=300)
parser.add_argument('-iswt', '--interactivestartwaittime', type=int, default=15)
parser.add_argument('-irwt', '--interactiveretrywaittime', type=int, default=30)
parser.add_argument('-int', '--interactive', action='store_true')
parser.add_argument('-q', '--quickdemo', action='store_true')
parser.add_argument('-entraId', '--entraId', action='store_true')
args = parser.parse_args()

vip = args.vip
vip2 = args.vip2
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
clustername = args.clustername
mcm = args.mcm
mfacode = args.mfacode
jobName = args.jobName
jobName2 = args.jobName2
keepLocalFor = args.keepLocalFor
replicateTo = args.replicateTo
keepReplicaFor = args.keepReplicaFor
archiveTo = args.archiveTo
keepArchiveFor = args.keepArchiveFor
enable = args.enable
wait = args.wait
backupType = args.backupType
objectnames = args.objectname
usepolicy = args.usepolicy
localonly = args.localonly
noreplica = args.noreplica
noarchive = args.noarchive
metadatafile = args.metadatafile
abortIfRunning = args.abortifrunning
logfile = args.logfile
waitminutesifrunning = args.waitminutesifrunning
cancelpreviousrunminutes = args.cancelpreviousrunminutes
newruntimeoutsecs = args.newruntimeoutsecs
debugger = args.debug
extendederrorcodes = args.extendederrorcodes
sleeptimesecs = args.sleeptimesecs
progress = args.progress
exitstring = args.exitstring
exitstringtimeoutsecs = args.exitstringtimeoutsecs
statusretries = args.statusretries
purgeoraclelogs = args.purgeoraclelogs
nocache = args.nocache
startwaittime = args.startwaittime
cachewaittime = args.cachewaittime
retrywaittime = args.retrywaittime
timeoutsec = args.timeoutsec
interactivestartwaittime = args.interactivestartwaittime
interactiveretrywaittime = args.interactiveretrywaittime
interactive = args.interactive
quickdemo = args.quickdemo
entraId = args.entraId

cacheSetting = 'true'
if nocache:
    cacheSetting = 'false'
    cachewaittime = 0

# enforce sleep time
if sleeptimesecs < 30:
    sleeptimesecs = 30

if newruntimeoutsecs < 720:
    newruntimeoutsecs = 720

if interactive:
    cachewaittime = 0
    startwaittime = interactivestartwaittime
    retrywaittime = interactiveretrywaittime

if quickdemo:
    cachewaittime = 0
    startwaittime = 10
    retrywaittime = 10
    sleeptimesecs = 10
    wait = True

if noprompt is True:
    prompt = False
else:
    prompt = None

if enable is True or progress is True:
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
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, entraId=entraId)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if LAST_API_ERROR() != 'OK':
    out(LAST_API_ERROR(), quiet=True)
    if vip2 is None:
        if extendederrorcodes is True:
            bail(2)
        else:
            bail(1)

if apiconnected() is False and vip2 is not None:
    out('\nFailed to connect to %s. Trying %s...' % (vip, vip2))
    apiauth(vip=vip2, username=username, domain=domain, password=password, useApiKey=useApiKey)
    if jobName2 is not None:
        jobName = jobName2
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

if cachewaittime > 0:
    if debugger:
        print(':DEBUG: waiting for read replica cache...')
    sleep(cachewaittime)

sources = {}


# get object ID
def getObjectId(objectName):

    d = {'_object_id': None}

    def get_nodes(node):
        if 'name' in node:
            if node['name'].lower() == objectName.lower():
                d['_object_id'] = node['id']
                exit
        if 'protectionSource' in node:
            if node['protectionSource']['name'].lower() == objectName.lower():
                d['_object_id'] = node['protectionSource']['id']
                exit
        if 'nodes' in node:
            for node in node['nodes']:
                if d['_object_id'] is None:
                    get_nodes(node)
                else:
                    exit

    for source in sources:
        if d['_object_id'] is None:
            get_nodes(source)

    return d['_object_id']


def cancelRunningJob(job, durationMinutes, v1JobId):
    if durationMinutes > 0:
        durationUsecs = durationMinutes * 60000000
        nowUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        cancelTime = nowUsecs - durationUsecs
        runningRuns = api('get', 'protectionRuns?jobId=%s&numRuns=10&excludeTasks=true&useCachedData=%s' % (v1JobId, cacheSetting), timeout=timeoutsec)
        if runningRuns is not None and len(runningRuns) > 0:
            for run in runningRuns:
                if 'backupRun' in run and 'status' in run['backupRun']:
                    if run['backupRun']['status'] not in finishedStates and 'stats' in run['backupRun'] and 'startTimeUsecs' in run['backupRun']['stats']:
                        if run['backupRun']['stats']['startTimeUsecs'] < cancelTime:
                            result = api('post', 'protectionRuns/cancel/%s' % v1JobId, {"jobRunId": run['backupRun']['jobRunId']}, timeout=timeoutsec)
                            out('Canceling previous job run')


# find protectionJob
jobs = None
jobRetries = 0
while jobs is None:
    jobs = api('get', 'data-protect/protection-groups?names=%s&isActive=true&isDeleted=false&pruneSourceIds=true&pruneExcludedSourceIds=true&useCachedData=%s' % (jobName, cacheSetting), v=2, timeout=timeoutsec)
    if jobs is None or 'error' in jobs or 'protectionGroups' not in jobs:
        jobs = None
        jobRetries += 1
        if jobRetries == 3:
            out('Timed out getting job!')
            if extendederrorcodes is True:
                bail(7)
            else:
                bail(1)
        else:
            sleep(retrywaittime)

if jobs['protectionGroups'] is None:
    out("Job '%s' not found" % jobName)
    if extendederrorcodes is True:
        bail(3)
    else:
        bail(1)

job = [job for job in jobs['protectionGroups'] if job['name'].lower() == jobName.lower()]

if not job:
    out("Job '%s' not found" % jobName)
    if extendederrorcodes is True:
        bail(3)
    else:
        bail(1)
else:
    job = job[0]
    v2JobId = job['id']
    v1JobId = v2JobId.split(':')[2]
    jobName = job['name']
    environment = job['environment']
    if environment == 'kPhysicalFiles':
        environment = 'kPhysical'
    if environment not in ['kOracle', 'kSQL'] and backupType == 'kLog':
        out('BackupType kLog not applicable to %s jobs' % environment)
        if extendederrorcodes is True:
            bail(3)
        else:
            bail(1)
    if objectnames is not None:
        v1Job = api('get', 'protectionJobs/%s?onlyReturnBasicSummary=true&useCachedData=%s' % (v1JobId, cacheSetting), timeout=timeoutsec)
        if environment in ['kOracle', 'kSQL']:
            backupJob = api('get', '/backupjobs/%s?useCachedData=%s' % (v1JobId, cacheSetting), timeout=timeoutsec)
            backupSources = api('get', '/backupsources?allUnderHierarchy=false&entityId=%s&excludeTypes=5&useCachedData=%s' % (backupJob[0]['backupJob']['parentSource']['id'], cacheSetting), timeout=timeoutsec)
        elif environment == 'kVMware':
            sources = api('get', 'protectionSources/virtualMachines?vCenterId=%s&protected=true&useCachedData=%s' % (v1Job['parentSourceId'], cacheSetting), timeout=timeoutsec)
        elif 'kAWS' in environment:
            sources = api('get', 'protectionSources?environments=kAWS&useCachedData=%s&id=%s' % (cacheSetting, v1Job['parentSourceId']), timeout=timeoutsec)
        else:
            sources = api('get', 'protectionSources?environments=%s&useCachedData=%s&id=%s' % (environment, cacheSetting, v1Job['parentSourceId']), timeout=timeoutsec)

# purge oracle logs
if purgeoraclelogs and environment == 'kOracle' and backupType == 'kLog':
    v2Job = api('get', 'data-protect/protection-groups/%s?useCachedData=true' % v2JobId, v=2, timeout=timeoutsec)
    v2OrigJob = copy.deepcopy(v2Job)

# handle run now objects
objectIds = {}
sourceIds = []
selectedSources = []
runNowParameters = []
if objectnames is not None:
    for objectname in objectnames:
        if environment == 'kSQL' or environment == 'kOracle':
            parts = objectname.split('/')
            if environment == 'kSQL':
                if len(parts) == 3:
                    (server, instance, db) = parts
                elif len(parts) == 2:
                    (server, instance) = parts
                    db = None
                else:
                    server = parts[0]
                    instance = None
                    db = None
            else:
                if len(parts) == 2:
                    (server, instance) = parts
                else:
                    server = parts[0]
                    instance = None
                    db = None
            serverObjectId = None
            serverObject = [o for o in backupSources['entityHierarchy']['children'] if o['entity']['displayName'].lower() == server.lower()]
            if serverObject is not None and len(serverObject) > 0:
                serverObjectId = serverObject[0]['entity']['id']
            if serverObjectId is not None:
                if serverObjectId not in v1Job['sourceIds']:
                    out("%s not protected by %s" % (server, jobName))
                    if extendederrorcodes is True:
                        bail(3)
                    else:
                        bail(1)
                if len([obj for obj in runNowParameters if obj['sourceId'] == serverObjectId]) == 0:
                    objectIds[server.lower()] = serverObjectId
                    runNowParameters.append(
                        {
                            "sourceId": serverObjectId
                        }
                    )
                    selectedSources.append(serverObjectId)
                if instance is not None or db is not None:
                    if environment == 'kOracle' or environment == 'kSQL':
                        for runNowParameter in runNowParameters:
                            if runNowParameter['sourceId'] == serverObjectId:
                                if 'databaseIds' not in runNowParameter:
                                    runNowParameter['databaseIds'] = []
                        if 'backupSourceParams' in backupJob[0]['backupJob']:
                            backupJobSourceParams = [p for p in backupJob[0]['backupJob']['backupSourceParams'] if p['sourceId'] == serverObjectId]
                            if backupJobSourceParams is not None and len(backupJobSourceParams) > 0:
                                backupJobSourceParams = backupJobSourceParams[0]
                            else:
                                backupJobSourceParams = None
                        else:
                            backupJobSourceParams = None
                        serverSource = [c for c in backupSources['entityHierarchy']['children'] if c['entity']['id'] == serverObjectId][0]
                        if environment == 'kSQL':
                            instanceSource = [i for i in serverSource['auxChildren'] if i['entity']['displayName'].lower() == instance.lower()][0]
                            if db is None:
                                dbSource = [c for c in instanceSource['children']]
                            else:
                                dbSource = [c for c in instanceSource['children'] if c['entity']['displayName'].lower() == '%s/%s' % (instance.lower(), db.lower())]
                            if dbSource is not None and len(dbSource) > 0:
                                for db in dbSource:
                                    if backupJobSourceParams is None or db['entity']['id'] in backupJobSourceParams['appEntityIdVec'] or instanceSource['entity']['id'] in backupJobSourceParams['appEntityIdVec']:
                                        runNowParameter['databaseIds'].append(db['entity']['id'])
                                    else:
                                        out('%s not protected by %s' % (objectname, jobName))
                                        if extendederrorcodes is True:
                                            bail(3)
                                        else:
                                            bail(1)
                            else:
                                out('%s not protected by %s' % (objectname, jobName))
                                if extendederrorcodes is True:
                                    bail(3)
                                else:
                                    bail(1)
                        else:
                            dbSource = [c for c in serverSource['auxChildren'] if c['entity']['displayName'].lower() == instance.lower()]
                            if dbSource is not None and len(dbSource) > 0:
                                for db in dbSource:
                                    if backupJobSourceParams is None or db['entity']['id'] in backupJobSourceParams['appEntityIdVec']:
                                        runNowParameter['databaseIds'].append(db['entity']['id'])
                            else:
                                out('%s not protected by %s' % (objectname, jobName))
                                if extendederrorcodes is True:
                                    bail(3)
                                else:
                                    bail(1)
                    else:
                        out("Job is Volume based. Can not selectively backup instances/databases")
                        if extendederrorcodes is True:
                            bail(3)
                        else:
                            bail(1)
            else:
                out('Object %s not found (server name)' % server)
                if extendederrorcodes is True:
                    bail(3)
                else:
                    bail(1)
        elif environment == 'kVMware':
            sourceId = None
            thisSource = [s for s in sources if s['name'].lower() == objectname.lower()]
            if thisSource is not None and len(thisSource) > 0:
                sourceId = thisSource[0]['id']
                sourceIds.append(sourceId)
                selectedSources.append(sourceId)
            else:
                out('Object %s not found!' % objectname)
                if extendederrorcodes is True:
                    bail(3)
                else:
                    bail(1)
        else:
            sourceId = getObjectId(objectname)
            if sourceId is not None:
                sourceIds.append(sourceId)
                selectedSources.append(sourceId)
            else:
                out('Object %s not found!' % objectname)
                if extendederrorcodes is True:
                    bail(3)
                else:
                    bail(1)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning', 'kCanceling', '3', '4', '5', '6', 'Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning']

jobData = {
    "copyRunTargets": [],
    "sourceIds": [],
    "runType": backupType,
    "usePolicyDefaults": True
}

if keepLocalFor is not None:
    jobData['copyRunTargets'] = [
        {
            "type": "kLocal",
            "daysToKeep": keepLocalFor
        }
    ]

if backupType != 'kRegular':
    jobData['usePolicyDefaults'] = False

# add objects (non-DB)
usemetadatafile = False
if sourceIds is not None and len(sourceIds) > 0:
    if metadatafile is not None:
        usemetadatafile = True
        jobData['runNowParameters'] = []
        for sourceId in sourceIds:
            jobData['runNowParameters'].append({"sourceId": sourceId, "physicalParams": {"metadataFilePath": metadatafile}})
    else:
        jobData['sourceIds'] = sourceIds
else:
    if metadatafile is not None:
        out('-o, --objectname required when using -m, --metadatafile')
        if extendederrorcodes is True:
            bail(3)
        else:
            bail(1)

# add objects (DB)
if len(runNowParameters) > 0:
    jobData['runNowParameters'] = runNowParameters

# use base retention and copy targets from policy
policy = api('get', 'protectionPolicies/%s' % job['policyId'], timeout=timeoutsec)

if localonly is True or noarchive is True or noreplica is True:
    jobData['usePolicyDefaults'] = False

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
if localonly is not True and noarchive is not True and (backupType != 'kLog' or environment != 'kSQL'):
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
    vault = [vault for vault in api('get', 'vaults?includeFortKnoxVault=true', timeout=timeoutsec) if vault['name'].lower() == archiveTo.lower()]
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

if purgeoraclelogs and environment == 'kOracle' and backupType == 'kLog':
    for obj in job['oracleParams']['objects']:
        for dbparam in obj['dbParams']:
            if objectnames is not None:
                for objectname in objectnames:
                    if len(parts) == 2:
                        (server, instance) = parts
                    else:
                        server = parts[0]
                        instance = None
                        db = None
                    
                    # if server.lower() == obj['sourceName'].lower():
                    if server.lower() in objectIds:
                        if instance is None or instance.lower() == dbparam['dbChannels'][0]['databaseUniqueName'].lower():
                            for channel in dbparam['dbChannels']:
                                if 'archiveLogRetentionDays' in channel:
                                    channel['archiveLogRetentionDays'] = 0
            else:
                for channel in dbparam['dbChannels']:
                    if 'archiveLogRetentionDays' in channel:
                        channel['archiveLogRetentionDays'] = 0
    updatejob = api('put', 'data-protect/protection-groups/%s' % v2JobId, job, v=2, timeout=timeoutsec)
    out('setting job to purge oracle logs...')
    sleep(cachewaittime + startwaittime)
    wait = True

# run protectionJob
now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
startUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
waitUntil = nowUsecs + (waitminutesifrunning * 60000000)
reportWaiting = True
if debugger:
    display(jobData)
    print(':DEBUG: waiting for new run to be accepted')
runNow = api('post', "protectionJobs/run/%s" % v1JobId, jobData, quiet=True, timeout=timeoutsec)
while runNow != "" and runNow is not None:
    runError = LAST_API_ERROR()
    if 'Protection Group already has a run' not in runError and 'Protection group can only have one active backup run at a time' not in runError and 'Backup job has an existing active backup run' not in runError:
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
        if cancelpreviousrunminutes > 0:
            cancelRunningJob(job, cancelpreviousrunminutes, v1JobId)
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
                runs = [r for r in runs['runs'] if selectedSources[0] in [o['object']['id'] for o in r['objects']] or len(r['objects']) == 0]
        else:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=1&includeObjectDetails=false&useCachedData=%s' % (v2JobId, cacheSetting), v=2, timeout=timeoutsec)
            if runs is not None and 'runs' in runs and len(runs['runs']) > 0:
                runs = runs['runs']
        if runs is not None and 'runs' not in runs and len(runs) > 0:
            runs = [r for r in runs if r['protectionGroupInstanceId'] > lastRunId]
        if runs is not None and 'runs' not in runs and len(runs) > 0 and usemetadatafile is True:
            for run in runs:
                runDetail = api('get', '/backupjobruns?exactMatchStartTimeUsecs=%s&id=%s&useCachedData=%s' % (run['localBackupInfo']['startTimeUsecs'], v1JobId, cacheSetting), timeout=timeoutsec)
                try:
                    metadataFilePath = runDetail[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['additionalParamVec'][0]['physicalParams']['metadataFilePath']
                    if metadataFilePath == metadatafile:
                        newRunId = run['protectionGroupInstanceId']
                        v2RunId = run['id']
                        break
                except Exception:
                    print('error getting metadata')
                    pass
        elif runs is not None and 'runs' not in runs and len(runs) > 0:
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
        # sleep(retrywaittime)
    out("New Job Run ID: %s" % v2RunId)

# wait for job run to finish and report completion
if wait is True:
    status = 'unknown'
    lastProgress = -1
    statusRetryCount = 0
    while status not in finishedStates:
        sleep(sleeptimesecs)
        x = 0
        s = 0
        try:
            status = run['localBackupInfo']['status']
            if debugger:
                print(':DEBUG: status = %s (%s)' % (status, statusRetryCount))
            if exitstring:
                run = api('get', 'data-protect/protection-groups/%s/runs/%s?includeObjectDetails=true&useCachedData=%s' % (v2JobId, v2RunId, cacheSetting), v=2, timeout=timeoutsec)
                while x < len(run['objects']) and s < exitstringtimeoutsecs:
                    sleep(15)
                    s += 15
                    if s > exitstringtimeoutsecs:
                        break
                    x = 0
                    try:
                        progressPath = run['localBackupInfo']['progressTaskId']
                        taskMon = api('get', '/progressMonitors?taskPathVec=%s&useCachedData=%s' % (progressPath, cacheSetting), timeout=timeoutsec)
                        sources = taskMon['resultGroupVec'][0]['taskVec'][0]['subTaskVec']
                        for source in sources:
                            if source['taskPath'] != 'post_processing':
                                # get pulse log messages
                                eventmsgs = source['progress']['eventVec']
                                foundkeystring = False
                                # check for key string in event messages
                                for eventmsg in eventmsgs:
                                    if exitstring in eventmsg['eventMsg']:
                                        foundkeystring = True
                                if foundkeystring is True:
                                    x += 1
                                else:
                                    preprocessFinished = False
                    except Exception:
                        pass
                    if x >= len(run['objects']):
                        print('*** SUCCESSFUL STRING MATCH')
                        exit(0)
                if x < len(run['objects']):
                    print('*** TIMED OUT WAITING FOR STRING MATCH')
                    exit(1)
            if status in finishedStates:
                break
            if progress:
                try:
                    progressPath = run['localBackupInfo']['progressTaskId']
                    progressMonitor = api('get', '/progressMonitors?taskPathVec=%s&excludeSubTasks=false&includeFinishedTasks=false&useCachedData=%s' % (progressPath, cacheSetting), timeout=timeoutsec)
                    progressTotal = progressMonitor['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                    percentComplete = int(round(progressTotal))
                    if percentComplete > lastProgress:
                        out('%s%% completed' % percentComplete)
                    lastProgress = percentComplete
                except Exception:
                    pass
            run = api('get', 'data-protect/protection-groups/%s/runs/%s?includeObjectDetails=false&useCachedData=%s' % (v2JobId, v2RunId, cacheSetting), v=2, timeout=timeoutsec)
            statusRetryCount = 0
        except Exception as e:
            statusRetryCount += 1
            if debugger:
                print(e)
                print(':DEBUG: error getting updated status')
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

if purgeoraclelogs and environment == 'kOracle' and backupType == 'kLog':
    updatejob = api('put', 'data-protect/protection-groups/%s' % v2JobId, v2OrigJob, v=2, timeout=timeoutsec)

# return exit code
if wait is True:
    if logfile is not None:
        try:
            log.write('Backup ended %s\n' % usecsToDate(run['localBackupInfo']['endTimeUsecs']))
        except Exception:
            log.write('Backup ended')
    if run['localBackupInfo']['status'] == 'Succeeded':
        bail(0)
    elif run['localBackupInfo']['status'] == 'SucceededWithWarning':
        if extendederrorcodes is True:
            bail(9)
        else:
            bail(0)
    else:
        bail(1)
else:
    bail(0)
