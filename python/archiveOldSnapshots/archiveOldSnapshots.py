#!/usr/bin/env python
"""Archive Now for python - version 2021.05.27"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-k', '--keepfor', type=int, required=True)
parser.add_argument('-t', '--target', type=str, required=True)
parser.add_argument('-r', '--replicasonly', action='store_true')  # only archive replicated jobs
parser.add_argument('-l', '--localonly', action='store_true')     # only archive local jobs
parser.add_argument('-f', '--force', action='store_true')         # perform the archive operation (otherwise show only)
parser.add_argument('-e', '--excludelogs', action='store_true')   # exclude log backups
parser.add_argument('-n', '--daysback', type=int, default=31)     # number of days back to search for snapshots to archive
parser.add_argument('-j', '--joblist', type=str, default=None)    # text file of job names to include (default is all jobs)
parser.add_argument('-x', '--excludelist', type=str, default=None)  # text file of job names (and strings) to exclude
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
keepfor = args.keepfor
target = args.target
replicasonly = args.replicasonly
localonly = args.localonly
force = args.force
excludelogs = args.excludelogs
daysback = args.daysback
joblist = args.joblist
excludelist = args.excludelist

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)
if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    exit(1)

jobnames = []
excludejobnames = []

jobs = api('get', 'protectionJobs')

if localonly:
    jobs = [j for j in jobs if 'isActive' not in j or j['isActive'] is True]

if replicasonly:
    jobs = [j for j in jobs if 'isActive' in j and j['isActive'] is False]

if joblist is not None:
    f = open(joblist, 'r')
    jobnames += [s.strip().lower() for s in f.readlines() if s.strip() != '']
    f.close()
    jobs = [j for j in jobs if j['name'].lower() in jobnames]

if excludelist is not None:
    f = open(excludelist, 'r')
    excludejobnames += [s.strip().lower() for s in f.readlines() if s.strip() != '']
    f.close()
    jobs = [j for j in jobs if j['name'].lower() not in excludejobnames]
    for exclude in excludejobnames:
        jobs = [j for j in jobs if exclude.lower() not in j['name'].lower()]

vault = [vault for vault in api('get', 'vaults') if vault['name'].lower() == target.lower()]
if len(vault) > 0:
    vault = vault[0]
    target = {
        "vaultId": vault['id'],
        "vaultName": vault['name'],
        "vaultType": "kCloud"
    }
else:
    print('external target %s not found' % target)
    exit(1)

startTimeUsecs = timeAgo(daysback, 'days')

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    runs = api('get', 'protectionRuns?jobId=%s&startTimeUsecs=%s&excludeTasks=true&numRuns=10000' % (job['id'], startTimeUsecs))
    runs = [r for r in runs if r['backupRun']['snapshotsDeleted'] is not True]
    runs = [r for r in runs if 'endTimeUsecs' in r['backupRun']['stats']]

    if excludelogs is True:
        runs = [r for r in runs if r['backupRun']['runType'] != 'kLog']
    for run in sorted(runs, key=lambda run: run['backupRun']['stats']['startTimeUsecs']):
        daysToKeep = keepfor
        thisrun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&excludeTasks=true&id=%s' % (run['backupRun']['stats']['startTimeUsecs'], run['jobId']))
        jobUid = thisrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']

        thisRunArchived = False
        for copyRun in run['copyRun']:

            # resync existing archive run
            if copyRun['target']['type'] == 'kArchival':
                thistarget = copyRun['target']['archivalTarget']
                thisstatus = copyRun['status']
                if thistarget['vaultName'].lower() == target['vaultName'].lower() and thisstatus == 'kSuccess':
                    thisRunArchived = True

        if thisRunArchived is False:
            # configure archive task
            archiveTask = {
                "jobRuns": [
                    {
                        "copyRunTargets": [
                            {
                                "archivalTarget": target,
                                "type": "kArchival"
                            }
                        ],
                        "runStartTimeUsecs": run['copyRun'][0]['runStartTimeUsecs'],
                        "jobUid": {
                            "clusterId": jobUid['clusterId'],
                            "clusterIncarnationId": jobUid['clusterIncarnationId'],
                            "id": jobUid['objectId']
                        }
                    }
                ]
            }

            daysToKeep = daysToKeep - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])
            archiveTask['jobRuns'][0]['copyRunTargets'][0]['daysToKeep'] = int(daysToKeep)

            # perform archive
            if force:
                print('archiving %s (%s) -> %s...' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName']))
                result = api('put', 'protectionRuns', archiveTask)
            else:
                print('%s (%s) -> %s' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName']))
