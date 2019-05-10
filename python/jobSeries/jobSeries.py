#!/usr/bin/env python
"""Run a Series of Disabled Jobs"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep

### settings
vip = 'mycluster'
username = 'myuser'
domain = 'mydomain.net'
keepLocalFor = 5
replicateTo = None
keepReplicaFor = 5
archiveTo = None
keepArchiveFor = 5
jobs = ['Exchange1', 'Exchange2', 'Exchange3']

### authenticate
apiauth(vip, username, domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

### open log
f = open('log-jobSeries.txt', 'w')
f.write('started at %s\n' % datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

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
        f.write("Remote Cluster %s not found!\n" % replicateTo)
        f.close()
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
        f.write("Archive target %s not found!\n" % archiveTo)
        f.close()
        exit()

runNowTask = {
    "copyRunTargets": copyRunTargets,
    "sourceIds": [],
    "runType": "kRegular"
}

# wait for any of the jobs are currently running
for jobName in jobs:

    print("checking if %s is already running..." % jobName)

    # find job
    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
        f.write("Job '%s' not found\n" % jobName)
    else:
        runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
        newRunId = lastRunId = runs[0]['backupRun']['jobRunId']
        if (runs[0]['backupRun']['status'] not in finishedStates):
            print("%s already running" % jobName)
            f.write("%s already running\n" % jobName)
            print("Existing Job Run ID: %s" % newRunId)
            f.write("Existing Job Run ID: %s\n" % newRunId)

            # wait for job run to finish
            while(runs[0]['backupRun']['status'] not in finishedStates):
                sleep(5)
                runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])

            # disable job
            while (api('get', 'protectionJobs/%s' % job[0]['id'])['isPaused'] is False):
                disable = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': True})
                sleep(3)
    del job  # this is just for PEP8 compliance

for jobName in jobs:

    # find job
    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
        f.write("Job '%s' not found\n" % jobName)
    else:

        # enable job
        while (api('get', 'protectionJobs/%s' % job[0]['id'])['isPaused'] is True):
            enable = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': False})
            sleep(3)

        # run job
        runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
        newRunId = lastRunId = runs[0]['backupRun']['jobRunId']

        if (runs[0]['backupRun']['status'] in finishedStates):
            print("Running %s..." % jobName)
            f.write("Running %s...\n" % jobName)
            api('post', "protectionJobs/run/%s" % job[0]['id'], runNowTask)

            # wait for new job run to appear
            while(newRunId == lastRunId):
                sleep(3)
                runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
                newRunId = runs[0]['backupRun']['jobRunId']
            print("New Job Run ID: %s" % newRunId)
            f.write("New Job Run ID: %s\n" % newRunId)

        else:
            print("%s already running" % jobName)
            f.write("%s already running\n" % jobName)
            print("Existing Job Run ID: %s" % newRunId)
            f.write("Existing Job Run ID: %s\n" % newRunId)

        # wait for job run to finish
        while(runs[0]['backupRun']['status'] not in finishedStates):
            sleep(5)
            runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])

        # disable job
        while (api('get', 'protectionJobs/%s' % job[0]['id'])['isPaused'] is False):
            disable = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': True})
            sleep(3)
f.close()
