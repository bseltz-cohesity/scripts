#!/usr/bin/env python
"""Backup Now and Copy for python"""

### usage: ./backupNow.py -v mycluster -u admin -j 'Generic NAS' [-r mycluster2] [-a S3] [-kr 5] [-ka 10] [-e] [-w] [-t kLog]

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobName', type=str, required=True)
parser.add_argument('-k', '--keepLocalFor', type=int, default=5)
parser.add_argument('-r', '--replicateTo', type=str, default=None)
parser.add_argument('-kr', '--keepReplicaFor', type=int, default=5)
parser.add_argument('-a', '--archiveTo', type=str, default=None)
parser.add_argument('-ka', '--keepArchiveFor', type=int, default=5)
parser.add_argument('-e', '--enable', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-t', '--backupType', type=str, choices=['kLog', 'kRegular', 'kFull'], default='kRegular')
parser.add_argument('-o', '--objectname', action='append', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobName = args.jobName
keepLocalFor = args.keepLocalFor
replicateTo = args.replicateTo
keepReplicaFor = args.keepReplicaFor
archiveTo = args.archiveTo
keepArchiveFor = args.keepArchiveFor
enable = args.enable
wait = args.wait
backupType = args.backupType
objectnames = args.objectname

if enable is True:
    wait = True

### authenticate
apiauth(vip, username, domain)

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
    if environment not in ['kOracle', 'kSQL'] and backupType == 'kLog':
        print('BackupType kLog not applicable to %s jobs' % environment)
        exit(1)
    if objectnames is not None:
        sources = api('get', 'protectionSources/objects?objectIds=%s' % ','.join(str(x) for x in job['sourceIds']))

# handle run now objects
sourceIds = None
runNowParameters = []
if environment == 'kOracle' or (environment == 'kSQL' and job['environmentParameters']['sqlParameters']['backupType'] == 'kSqlVSSFile'):
    if objectnames is not None:
        for objectname in objectnames:
            if environment == 'kSQL':
                (server, instance, db) = objectname.split('/')
            else:
                (server, instance) = objectname.split('/', 1)
            serverObjectId = getObjectId(server)
            if serverObjectId is not None:
                if len([obj for obj in runNowParameters if obj['sourceId'] == serverObjectId]) == 0:
                    runNowParameters.append(
                        {
                            "sourceId": serverObjectId,
                            "databaseIds": []
                        }
                    )
                serverSource = api('get', 'protectionSources?id=%s' % serverObjectId)[0]
                instanceNodes = [node for node in serverSource['applicationNodes'] if node['protectionSource']['name'].lower() == instance.lower()]
                if len(instanceNodes) > 0:
                    if environment == 'kSQL':
                        dbNodes = [dbNode for dbNode in instanceNodes[0]['nodes'] if dbNode['protectionSource']['name'].lower() == '%s/%s' % (instance.lower(), db.lower())]
                    else:
                        dbNodes = instanceNodes
                    if len(dbNodes) > 0:
                        dbId = dbNodes[0]['protectionSource']['id']
                        for runNowParameter in runNowParameters:
                            if runNowParameter['sourceId'] == serverObjectId:
                                runNowParameter['databaseIds'].append(dbId)
                    else:
                        print('Object %s not found (db name)' % db)
                        exit(1)
                else:
                    if environment == 'kSQL':
                        print('Object %s not found (instance name)' % instance)
                    else:
                        print('Object %s not found (db name)' % instance)
                    exit(1)
            else:
                print('Object %s not found (server name)' % server)
                exit(1)
else:
    if objectnames is not None:
        sourceIds = []
        for objectName in objectnames:
            sourceId = getObjectId(objectName)
            if sourceId is not None:
                sourceIds.append(sourceId)
            else:
                print('Object %s not found!' % objectName)
                exit(1)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
runs = api('get', 'protectionRuns?jobId=%s' % job['id'])
if len(runs) > 0:
    newRunId = lastRunId = runs[0]['backupRun']['jobRunId']

    # wait for existing job run to finish
    if (runs[0]['backupRun']['status'] not in finishedStates):
        print("waiting for existing job run to finish...")
        while (runs[0]['backupRun']['status'] not in finishedStates):
            sleep(5)
            runs = api('get', 'protectionRuns?jobId=%s' % job['id'])
else:
    newRunId = lastRunId = 1

# job data
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

if sourceIds is not None:
    jobData['sourceIds'] = sourceIds
if len(runNowParameters) > 0:
    jobData['runNowParameters'] = runNowParameters

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
    while(runs[0]['backupRun']['status'] not in finishedStates):
        sleep(5)
        runs = api('get', 'protectionRuns?jobId=%s' % job['id'])
    print("Job finished with status: %s" % runs[0]['backupRun']['status'])
    runURL = "https://%s/protection/job/%s/run/%s/%s/protection" % \
        (vip, runs[0]['jobId'], runs[0]['backupRun']['jobRunId'], runs[0]['copyRun'][0]['runStartTimeUsecs'])
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
