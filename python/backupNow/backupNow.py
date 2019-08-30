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

if enable is True:
    wait = True

### authenticate
apiauth(vip, username, domain)

### find protectionJob
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
if not job:
    print("Job '%s' not found" % jobName)
    exit(1)
else:
    environment = job[0]['environment']
    if environment not in ['kOracle', 'kSQL'] and backupType == 'kLog':
        print('BackupType kLog not applicable to %s jobs' % environment)
        exit(1)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
if len(runs) > 0:
    newRunId = lastRunId = runs[0]['backupRun']['jobRunId']

    # wait for existing job run to finish
    if (runs[0]['backupRun']['status'] not in finishedStates):
        print("waiting for existing job run to finish...")
        while (runs[0]['backupRun']['status'] not in finishedStates):
            sleep(5)
            runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
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
    enabled = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': False})

### run protectionJob
print("Running %s..." % jobName)

runNow = api('post', "protectionJobs/run/%s" % job[0]['id'], jobData)

# wait for new job run to appear
if wait is True:
    while(newRunId == lastRunId):
        sleep(1)
        runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
        newRunId = runs[0]['backupRun']['jobRunId']
    print("New Job Run ID: %s" % newRunId)

# wait for job run to finish and report completion
if wait is True:
    while(runs[0]['backupRun']['status'] not in finishedStates):
        sleep(5)
        runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
    print("Job finished with status: %s" % runs[0]['backupRun']['status'])
    runURL = "https://%s/protection/job/%s/run/%s/%s/protection" % \
        (vip, runs[0]['jobId'], runs[0]['backupRun']['jobRunId'], runs[0]['copyRun'][0]['runStartTimeUsecs'])
    print("Run URL: %s" % runURL)

# disable job
if enable:
    disabled = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': True})

# return exit code
if wait is True:
    if runs[0]['backupRun']['status'] == 'kSuccess':
        exit(0)
    else:
        exit(1)
else:
    exit(0)
