#!/usr/bin/env python
"""Backup Now and Copy for python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-j', '--jobName', action='append', type=str)
parser.add_argument('-l', '--jobList', type=str)
parser.add_argument('-y', '--usepolicy', action='store_true')
parser.add_argument('-k', '--keepLocalFor', type=int, default=5)
parser.add_argument('-r', '--replicateTo', type=str, default=None)
parser.add_argument('-kr', '--keepReplicaFor', type=int, default=5)
parser.add_argument('-a', '--archiveTo', type=str, default=None)
parser.add_argument('-ka', '--keepArchiveFor', type=int, default=5)
parser.add_argument('-t', '--backupType', type=str, choices=['kLog', 'kRegular', 'kFull'], default='kRegular')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
jobNames = args.jobName
jobList = args.jobList
keepLocalFor = args.keepLocalFor
replicateTo = args.replicateTo
keepReplicaFor = args.keepReplicaFor
archiveTo = args.archiveTo
keepArchiveFor = args.keepArchiveFor
backupType = args.backupType
useApiKey = args.useApiKey
usepolicy = args.usepolicy

# gather job names
if jobNames is None:
    jobNames = []
if jobList is not None:
    f = open(jobList, 'r')
    jobNames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()


### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    exit(1)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning']

for jobName in jobNames:

    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
    else:
        runJob = True
        job = job[0]
        environment = job['environment']
        if environment == 'kPhysicalFiles':
            environment = 'kPhysical'
        if environment not in ['kOracle', 'kSQL'] and backupType == 'kLog':
            print('BackupType kLog not applicable to %s jobs' % environment)
            runJob = False
        else:
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
                        runJob = False

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
                        runJob = False

            ### run protectionJob
            if runJob is True:
                print("Running %s..." % jobName)
                runNow = api('post', "protectionJobs/run/%s" % job['id'], jobData)
