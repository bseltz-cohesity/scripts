#!/usr/bin/env python
"""Run a Series of Disabled Jobs"""

### import pyhesity wrapper module
from pyhesity import *
from time import sleep
import os

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-g', '--groupname', type=str, required=True)
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
keepLocalFor = args.keepLocalFor
replicateTo = args.replicateTo
keepReplicaFor = args.keepReplicaFor
archiveTo = args.archiveTo
keepArchiveFor = args.keepArchiveFor
backupType = args.backupType
groupname = args.groupname

### authenticate
apiauth(vip, username, domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

### read group files
scriptdir = os.path.dirname(os.path.realpath(__file__))
grouppath = os.path.join(scriptdir, groupname)
jobs = [f for f in os.listdir(grouppath) if os.path.isfile(os.path.join(grouppath, f))]

### configure job run task
copyRunTargets = [
    {
        "type": "kLocal",
        "daysToKeep": keepLocalFor
    }
]

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

runNowTask = {
    "copyRunTargets": copyRunTargets,
    "sourceIds": [],
    "runType": "kRegular"
}

# wait for any of the jobs are currently running
print("Checking for running jobs...")
jobRunning = False

for jobName in jobs:

    # find job
    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
    else:
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=10' % job[0]['id'])
        newRunId = lastRunId = runs[0]['backupRun']['jobRunId']
        if (runs[0]['backupRun']['status'] not in finishedStates):
            # mark job as running
            jobRunning = True
            print("%s already running" % jobName)
            print("Existing Job Run ID: %s" % newRunId)
            triggerfilepath = os.path.join(grouppath, jobName)
            f = open(triggerfilepath, 'w')
            f.write('started')
            f.close()
        else:
            # disable all stopped jobs
            while (api('get', 'protectionJobs/%s' % job[0]['id'])['isPaused'] is False):
                disable = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': True})
                sleep(1)

del job

# if no jobs running, run oldest job
jobdate = {}

if jobRunning is False:
    for jobName in jobs:
        triggerfilepath = os.path.join(grouppath, jobName.lower())
        f = open(triggerfilepath, 'r')
        jobstate = f.read()
        if jobstate == 'not started':
            job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
            if not job:
                print("Job '%s' not found" % jobName)
            else:
                runs = api('get', 'protectionRuns?jobId=%s&numRuns=10' % job[0]['id'])
                jobdate[jobName.lower()] = runs[0]['copyRun'][0]['runStartTimeUsecs']
            del job

    # oldest job
    joblist = sorted(jobdate.items(), key=lambda x: x[1])
    if len(joblist) > 0:
        jobName = joblist[0][0]
    else:
        print('nothing to run')
        exit()

    # find job
    job = [thisjob for thisjob in api('get', 'protectionJobs') if thisjob['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
    else:

        # enable job
        jobDisabled = True
        while (jobDisabled is True):

            thisjob = api('get', 'protectionJobs/%s' % job[0]['id'])
            if thisjob:
                jobDisabled = thisjob['isPaused']
                enable = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': False})
                sleep(1)

        # run job
        print("Running %s..." % jobName)
        newrun = api('post', "protectionJobs/run/%s" % thisjob['id'], runNowTask)

        # mark job running and exit
        triggerfilepath = os.path.join(grouppath, jobName)
        f = open(triggerfilepath, 'w')
        f.write('started')
        f.close()
