#!/usr/bin/env python
"""Backup Now and Copy for python"""

### usage: ./backupNowAndCopy.py -v mycluster -u admin -j 'Generic NAS' [-r mycluster2] [-a S3] [-kr 5] [-ka 10] [-e]

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
parser.add_argument('-r', '--replicateTo', type=str, default=None)
parser.add_argument('-kr', '--keepReplicaFor', type=int, default=5)
parser.add_argument('-a', '--archiveTo', type=str, default=None)
parser.add_argument('-ka', '--keepArchiveFor', type=int, default=5)
parser.add_argument('-e', '--enable', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobName = args.jobName
replicateTo = args.replicateTo
keepReplicaFor = args.keepReplicaFor
archiveTo = args.archiveTo
keepArchiveFor = args.keepArchiveFor
enable = args.enable

### authenticate
apiauth(vip, username, domain)

### find protectionJob
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
if not job:
    print("Job '%s' not found" % jobName)
    exit()

copyRunTargets = []

if replicateTo is not None:
    remote = [remote for remote in api('get', 'remoteClusters') if remote['name'].lower() == replicateTo.lower()]
    if len(remote) > 0:
        remote = remote[0]
        copyRunTargets.append({
            "type": "kRemote",
            "daysToKeep": keepReplicaFor,
            "replicationTarget": {
                "clusterId": remote['clusterId'],
                "clusterName": remote['name']
            }
        })
    else:
        print("Remote Cluster %s not found!" % replicateTo)
        exit()

if archiveTo is not None:
    vault = [vault for vault in api('get', 'vaults') if vault['name'].lower() == archiveTo.lower()]
    if len(vault) > 0:
        vault = vault[0]
        copyRunTargets.append({
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
        exit()

### enable the job
if enable:
    enabled = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': False})

### run protectionJob
print("Running %s..." % jobName)

runNowTask = {
    "copyRunTargets": copyRunTargets,
    "sourceIds": [],
    "runType": "kRegular"
}

runNow = api('post', "protectionJobs/run/%s" % job[0]['id'], runNowTask)

if enable:
    sleep(2)
    disabled = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': True})
