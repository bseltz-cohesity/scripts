#!/usr/bin/env python
"""Archive Now for python - version 2021.06.19"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs
import json

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')     # use api key for authentication
parser.add_argument('-p', '--password', type=str, default=None)   # password or api key to use
parser.add_argument('-k', '--keepfor', type=int, required=True)   # keep archives for X days
parser.add_argument('-t', '--target', type=str, required=True)    # name of external target to archive to
parser.add_argument('-r', '--replicasonly', action='store_true')  # only archive replicated jobs
parser.add_argument('-l', '--localonly', action='store_true')     # only archive local jobs
parser.add_argument('-f', '--force', action='store_true')         # perform the archive operation (otherwise show only)
parser.add_argument('-e', '--excludelogs', action='store_true')   # exclude log backups
parser.add_argument('-n', '--daysback', type=int, default=31)     # number of days back to search for snapshots to archive
parser.add_argument('-j', '--joblist', type=str, default=None)    # text file of job names to include (default is all jobs)
parser.add_argument('-x', '--excludelist', type=str, default=None)  # text file of job names (and strings) to exclude
parser.add_argument('-o', '--outfolder', type=str, default='.')   # output folder for log file
parser.add_argument('-s', '--retentionstring', action='append', type=str)  # strings for special retention
parser.add_argument('-m', '--onlymatches', action='store_true')   # perform the archive operation (otherwise show only)

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
outfolder = args.outfolder
retentionstrings = args.retentionstring
onlymatches = args.onlymatches

nowUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
outfileName = '%s/archiveLog-%s-%s.txt' % (outfolder, vip, datetime.now().strftime("%Y-%m"))
f = codecs.open(outfileName, 'a', 'utf-8')

f.write('\n----------------\nArchiver started: %s\n----------------\n' % datetime.now().strftime("%m/%d/%Y %H:%M:%S"))
f.write('\nCommand line options used: \n%s\n\n' % json.dumps(vars(args), sort_keys=True, indent=4, separators=(', ', ': ')))

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)
if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    f.write('\nError: Failed to connect to Cohesity cluster\n')
    f.close()
    exit(1)

if force is False:
    print('\nRunning in test mode - will not archive\n')
    f.write('Running in test mode - will not archive\n\n')

jobnames = []
excludejobnames = []

jobs = [j for j in api('get', 'protectionJobs') if 'isDirectArchiveEnabled' not in j]

if onlymatches:
    matchedjobs = []
    for job in jobs:
        for retentionString in retentionstrings:
            if retentionString.lower() in job['name'].lower():
                matchedjobs.append(job)
    jobs = matchedjobs

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
    f.write('\nError: external target %s not found\n' % target)
    f.close()
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
        expiryTimeUsecs = run['copyRun'][0]['expiryTimeUsecs']

        thisRunArchived = False
        for copyRun in run['copyRun']:

            # resync existing archive run
            if copyRun['target']['type'] == 'kArchival':
                thistarget = copyRun['target']['archivalTarget']
                thisstatus = copyRun['status']
                if thistarget['vaultName'].lower() == target['vaultName'].lower():
                    if thisstatus == 'kSuccess':
                        thisRunArchived = True
                    else:
                        f.write('Warning: %s (%s) -> %s previously ended with status: %s\n' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisstatus))
                        if (expiryTimeUsecs - nowUsecs) < 86400000000:
                            # update retention of job run
                            f.write('         extending local snapshot retention\n')
                            runParameters = {
                                "jobRuns": [
                                    {
                                        "jobUid": {
                                            "clusterId": jobUid['clusterId'],
                                            "clusterIncarnationId": jobUid['clusterIncarnationId'],
                                            "id": jobUid['objectId']
                                        },
                                        "runStartTimeUsecs": run['copyRun'][0]['runStartTimeUsecs'],
                                        "copyRunTargets": [
                                            {
                                                "daysToKeep": 1,
                                                "type": "kLocal"
                                            }
                                        ]
                                    }
                                ]
                            }
                            api('put', 'protectionRuns', runParameters)

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

            thisDaysToKeep = daysToKeep
            for retentionString in retentionstrings:
                if retentionString.lower() in job['name'].lower():
                    retentionString = ''.join([i for i in retentionString if i.isdigit()])
                    if retentionString.isdigit():
                        thisDaysToKeep = int(retentionString)

            thisDaysToKeep = thisDaysToKeep - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])
            archiveTask['jobRuns'][0]['copyRunTargets'][0]['daysToKeep'] = int(thisDaysToKeep)

            # perform archive
            if force:
                print('archiving %s (%s) -> %s for %s days' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
                f.write('archiving %s (%s) -> %s for %s days\n' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
                result = api('put', 'protectionRuns', archiveTask)
            else:
                print('%s (%s) -> %s for %s days' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
                f.write('would archive %s (%s) -> %s for %s days\n' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
f.write('\n')
f.close()
