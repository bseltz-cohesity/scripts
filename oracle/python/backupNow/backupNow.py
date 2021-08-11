#!/usr/bin/env python
"""Backup Now and Copy for python"""

# version 2021.08.11

### usage: ./backupNow.py -v mycluster -u admin -j 'Generic NAS' [-r mycluster2] [-a S3] [-kr 5] [-ka 10] [-e] [-w] [-t kLog]

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-v2', '--vip2', type=str, default=None)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
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
parser.add_argument('-t', '--backupType', type=str, choices=['kLog', 'kRegular', 'kFull'], default='kRegular')
parser.add_argument('-o', '--objectname', action='append', type=str)
parser.add_argument('-m', '--metadatafile', type=str, default=None)
parser.add_argument('-x', '--abortifrunning', action='store_true')

args = parser.parse_args()

vip = args.vip
vip2 = args.vip2
username = args.username
domain = args.domain
password = args.password
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
useApiKey = args.useApiKey
usepolicy = args.usepolicy
localonly = args.localonly
noreplica = args.noreplica
noarchive = args.noarchive
metadatafile = args.metadatafile
abortIfRunning = args.abortifrunning

if enable is True:
    wait = True

### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)
if apiconnected() is False and vip2 is not None:
    print('\nFailed to connect to %s. Trying %s...' % (vip, vip2))
    apiauth(vip=vip2, username=username, domain=domain, password=password, useApiKey=useApiKey)
    if jobName2 is not None:
        jobName = jobName2

if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    exit(1)

sources = {}


### get object ID
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


### find protectionJob
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
if not job:
    print("Job '%s' not found" % jobName)
    exit(1)
else:
    job = job[0]
    environment = job['environment']
    if environment == 'kPhysicalFiles':
        environment = 'kPhysical'
    if environment not in ['kOracle', 'kSQL'] and backupType == 'kLog':
        print('BackupType kLog not applicable to %s jobs' % environment)
        exit(1)
    if objectnames is not None:
        if 'kAWS' in environment:
            sources = api('get', 'protectionSources?environments=kAWS')
        else:
            sources = api('get', 'protectionSources?environments=%s' % environment)

# handle run now objects
sourceIds = []
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

            serverObjectId = getObjectId(server)
            if serverObjectId is not None:
                if serverObjectId not in job['sourceIds']:
                    print("%s not protected by %s" % (server, jobName))
                    exit(1)
                if len([obj for obj in runNowParameters if obj['sourceId'] == serverObjectId]) == 0:
                    runNowParameters.append(
                        {
                            "sourceId": serverObjectId
                        }
                    )
                if instance is not None or db is not None:
                    if environment == 'kOracle' or (environment == 'kSQL' and job['environmentParameters']['sqlParameters']['backupType'] == 'kSqlVSSFile'):
                        for runNowParameter in runNowParameters:
                            if runNowParameter['sourceId'] == serverObjectId:
                                if 'databaseIds' not in runNowParameter:
                                    runNowParameter['databaseIds'] = []
                        protectedDbList = api('get', 'protectionSources/protectedObjects?environment=%s&id=%s' % (environment, serverObjectId))
                        protectedDbList = [d for d in protectedDbList if jobName.lower() in [j['name'].lower() for j in d['protectionJobs']]]
                        if environment == 'kSQL':
                            if db is None:
                                protectedDbList = [d for d in protectedDbList if d['protectionSource']['name'].lower().split('/')[0] == instance.lower()]
                            else:
                                protectedDbList = [d for d in protectedDbList if d['protectionSource']['name'].lower() == '%s/%s' % (instance.lower(), db.lower())]
                        else:
                            protectedDbList = [d for d in protectedDbList if d['protectionSource']['name'].lower() == '%s' % instance.lower()]
                        if len(protectedDbList) > 0:
                            for runNowParameter in runNowParameters:
                                if runNowParameter['sourceId'] == serverObjectId:
                                    for protectedDb in protectedDbList:
                                        runNowParameter['databaseIds'].append(protectedDb['protectionSource']['id'])
                        else:
                            print('%s not protected by %s' % (objectname, jobName))
                            exit(1)
                    else:
                        print("Job is Volume based. Can not selectively backup instances/databases")
                        exit(1)
            else:
                print('Object %s not found (server name)' % server)
                exit(1)
        else:
            sourceId = getObjectId(objectname)
            if sourceId is not None:
                sourceIds.append(sourceId)
            else:
                print('Object %s not found!' % objectname)
                exit(1)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning']
runs = api('get', 'protectionRuns?jobId=%s&excludeTasks=true&numRuns=10' % job['id'])

if len(runs) > 0:
    newRunId = lastRunId = runs[0]['backupRun']['jobRunId']

    # wait for existing job run to finish
    status = 'unknown'
    reportedwaiting = False
    if metadatafile is None:
        while status not in finishedStates:
            try:
                runs = api('get', 'protectionRuns?jobId=%s&excludeTasks=true&numRuns=10' % job['id'])
                status = runs[0]['backupRun']['status']
                if status not in finishedStates:
                    if reportedwaiting is False:
                        if abortIfRunning:
                            print('Job is already running')
                            exit()
                        print('Waiting for existing job run to finish...')
                        reportedwaiting = True
                    sleep(5)
            except Exception:
                print("got an error...")
                sleep(2)
else:
    newRunId = lastRunId = 1

# job parameters (base)
jobData = {
    "copyRunTargets": [
        {
            "type": "kLocal",
            "daysToKeep": keepLocalFor
        }
    ],
    "sourceIds": [],
    "runType": backupType
}

# add objects (non-DB)
if sourceIds is not None:
    if metadatafile is not None:
        jobData['runNowParameters'] = []
        for sourceId in sourceIds:
            jobData['runNowParameters'].append({"sourceId": sourceId, "physicalParams": {"metadataFilePath": metadatafile}})
    else:
        jobData['sourceIds'] = sourceIds

# add objects (DB)
if len(runNowParameters) > 0:
    jobData['runNowParameters'] = runNowParameters

# use base retention and copy targets from policy
policy = api('get', 'protectionPolicies/%s' % job['policyId'])
if keepLocalFor is None:
    jobData['copyRunTargets'][0]['daysToKeep'] = policy['daysToKeep']

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
        print("--keepReplicaFor is required")
        exit(1)
    remote = [remote for remote in api('get', 'remoteClusters') if remote['name'].lower() == replicateTo.lower()]
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
        print("Remote Cluster %s not found!" % replicateTo)
        exit(1)

if archiveTo is not None:
    if keepArchiveFor is None:
        print("--keepArchiveFor is required")
        exit(1)
    vault = [vault for vault in api('get', 'vaults') if vault['name'].lower() == archiveTo.lower()]
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
        print("Archive target %s not found!" % archiveTo)
        exit(1)

### enable the job
if enable:
    enabled = api('post', 'protectionJobState/%s' % job['id'], {'pause': False})

### run protectionJob
print("Running %s..." % jobName)

runNow = api('post', "protectionJobs/run/%s" % job['id'], jobData)
if runNow == 'error':
    exit(1)

# wait for new job run to appear
if wait is True:
    while(newRunId == lastRunId):
        sleep(1)
        runs = api('get', 'protectionRuns?jobId=%s' % job['id'])
        if len(runs) > 0:
            newRunId = runs[0]['backupRun']['jobRunId']
        else:
            newRunId = 1
    print("New Job Run ID: %s" % newRunId)

# wait for job run to finish and report completion
if wait is True:
    status = 'unknown'
    lastProgress = -1
    while status not in finishedStates:
        try:
            runs = api('get', 'protectionRuns?jobId=%s&excludeTasks=true&numRuns=10' % job['id'])
            run = [r for r in runs if r['backupRun']['jobRunId'] == newRunId]
            status = run[0]['backupRun']['status']
            progressMonitor = api('get', '/progressMonitors?taskPathVec=backup_%s_1&includeFinishedTasks=true&excludeSubTasks=false' % newRunId)
            percentComplete = int(round(progressMonitor['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']))
            if percentComplete > lastProgress:
                print('%s%% completed' % percentComplete)
                lastProgress = percentComplete
            if status not in finishedStates:
                sleep(5)
        except Exception:
            print("got an error...")
            sleep(5)
            try:
                apiauth(vip, username, domain, quiet=True)
            except Exception:
                sleep(2)
    print("Job finished with status: %s" % run[0]['backupRun']['status'])
    if run[0]['backupRun']['status'] == 'kFailure':
        print('Error: %s' % run[0]['backupRun']['error'])
    if run[0]['backupRun']['status'] == 'kWarning':
        print('Warning: %s' % run[0]['backupRun']['warnings'])
    runURL = "https://%s/protection/job/%s/run/%s/%s/protection" % \
        (vip, run[0]['jobId'], run[0]['backupRun']['jobRunId'], run[0]['backupRun']['stats']['startTimeUsecs'])
    print("Run URL: %s" % runURL)

# disable job
if enable:
    disabled = api('post', 'protectionJobState/%s' % job['id'], {'pause': True})

# return exit code
if wait is True:
    if runs[0]['backupRun']['status'] == 'kSuccess' or runs[0]['backupRun']['status'] == 'kWarning':
        exit(0)
    else:
        exit(1)
else:
    exit(0)
