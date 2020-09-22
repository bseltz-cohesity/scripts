#!/usr/bin/env python
"""Backup Now and Copy for python"""

# version 2020.09.22

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
parser.add_argument('-k', '--keepLocalFor', type=int, default=5)
parser.add_argument('-r', '--replicateTo', type=str, default=None)
parser.add_argument('-kr', '--keepReplicaFor', type=int, default=5)
parser.add_argument('-a', '--archiveTo', type=str, default=None)
parser.add_argument('-ka', '--keepArchiveFor', type=int, default=5)
parser.add_argument('-e', '--enable', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-t', '--backupType', type=str, choices=['kLog', 'kRegular', 'kFull'], default='kRegular')
parser.add_argument('-o', '--objectname', action='append', type=str)
parser.add_argument('-m', '--metadatafile', type=str, default=None)

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
metadatafile = args.metadatafile

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

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
runs = api('get', 'protectionRuns?jobId=%s&excludeTasks=true&numRuns=10' % job['id'])

if len(runs) > 0 and metadatafile is None:
    newRunId = lastRunId = runs[0]['backupRun']['jobRunId']

    # wait for existing job run to finish
    status = 'unknown'
    reportedwaiting = False
    while status not in finishedStates:
        try:
            runs = api('get', 'protectionRuns?jobId=%s&excludeTasks=true&numRuns=10' % job['id'])
            status = runs[0]['backupRun']['status']
            if status not in finishedStates:
                if reportedwaiting is False:
                    print('Waiting for existing job run to finish...')
                    reportedwaiting = True
                sleep(5)
        except Exception:
            print("got an error...")
            sleep(2)
            try:
                apiauth(vip, username, domain, quiet=True)
            except Exception:
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
if usepolicy:
    policy = api('get', 'protectionPolicies/%s' % job['policyId'])
    jobData['copyRunTargets'][0]['daysToKeep'] = policy['daysToKeep']
    if 'snapshotReplicationCopyPolicies' in policy:
        for replica in policy['snapshotReplicationCopyPolicies']:
            if replica['target'] not in [p.get('replicationTarget', None) for p in jobData['copyRunTargets']]:
                jobData['copyRunTargets'].append({
                    "daysToKeep": replica['daysToKeep'],
                    "replicationTarget": replica['target'],
                    "type": "kRemote"
                })
    if 'snapshotArchivalCopyPolicies' in policy:
        for archive in policy['snapshotArchivalCopyPolicies']:
            if archive['target'] not in [p.get('archivalTarget', None) for p in jobData['copyRunTargets']]:
                jobData['copyRunTargets'].append({
                    "archivalTarget": archive['target'],
                    "daysToKeep": archive['daysToKeep'],
                    "type": "kArchival"
                })
else:
    # or use retention and copy targets specified at the command line
    if replicateTo is not None:
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
    while status not in finishedStates:
        try:
            runs = api('get', 'protectionRuns?jobId=%s&excludeTasks=true&numRuns=10' % job['id'])
            status = runs[0]['backupRun']['status']
            if status not in finishedStates:
                sleep(5)
        except Exception:
            print("got an error...")
            sleep(5)
            try:
                apiauth(vip, username, domain, quiet=True)
            except Exception:
                sleep(2)
    print("Job finished with status: %s" % runs[0]['backupRun']['status'])
    runURL = "https://%s/protection/job/%s/run/%s/%s/protection" % \
        (vip, runs[0]['jobId'], runs[0]['backupRun']['jobRunId'], runs[0]['backupRun']['stats']['startTimeUsecs'])
    print("Run URL: %s" % runURL)

# disable job
if enable:
    disabled = api('post', 'protectionJobState/%s' % job['id'], {'pause': True})

# return exit code
if wait is True:
    if runs[0]['backupRun']['status'] == 'kSuccess':
        exit(0)
    else:
        exit(1)
else:
    exit(0)
