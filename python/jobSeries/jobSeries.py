#!/usr/bin/env python
"""Run a Series of Disabled Jobs"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep

### settings
vip = 'mycluster'
username = 'myusername'
domain = 'mydomain.net'
replicateTo = 'anothercluster'
keepReplicaFor = 5
archiveTo = 'archivetarget'
keepArchiveFor = 5
jobs = ['Job1', 'Job2', 'Job3']

### authenticate
apiauth(vip, username, domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

### open log
f = open('log-jobSeries.txt', 'w')
f.write('started at %s\n' % datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

### configure job run task
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
            sleep(2)

        # run job
        runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
        newRunId = lastRunId = runs[0]['backupRun']['jobRunId']
        if (runs[0]['backupRun']['status'] in finishedStates):
            print("Running %s..." % jobName)
            f.write("Running %s...\n" % jobName)
            api('post', "protectionJobs/run/%s" % job[0]['id'], runNowTask)

            ### wait for new job run to appear
            while(newRunId == lastRunId):
                sleep(1)
                runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
                newRunId = runs[0]['backupRun']['jobRunId']
            print("New Job Run ID: %s" % newRunId)
            f.write("New Job Run ID: %s\n" % newRunId)

            ### wait for job run to finish
            while(runs[0]['backupRun']['status'] not in finishedStates):
                sleep(5)
                runs = api('get', 'protectionRuns?jobId=%s' % job[0]['id'])
        else:
            print("%s already running" % jobName)
            f.write("%s already running\n" % jobName)

        # disable job
        while (api('get', 'protectionJobs/%s' % job[0]['id'])['isPaused'] is False):
            disable = api('post', 'protectionJobState/%s' % job[0]['id'], {'pause': True})
            sleep(2)
f.close()
