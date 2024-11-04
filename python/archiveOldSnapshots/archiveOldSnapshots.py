#!/usr/bin/env python
"""Archive Now for python - version 2021.09.20"""

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

if retentionstrings is None:
    retentionstrings = []

nowUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
outfileName = '%s/archiveLog-%s-%s.txt' % (outfolder, vip, datetime.now().strftime("%Y-%m"))
log = codecs.open(outfileName, 'a', 'utf-8')

log.write('\n----------------\nArchiver started: %s\n----------------\n' % datetime.now().strftime("%m/%d/%Y %H:%M:%S"))
log.write('\nCommand line options used: \n%s\n\n' % json.dumps([a for a in vars(args) if a not in ['domain', 'username', 'password']], sort_keys=True, indent=4, separators=(', ', ': ')))

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)
if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    log.write('\nError: Failed to connect to Cohesity cluster\n')
    log.close()
    exit(1)

if force is False:
    print('\nRunning in test mode - will not archive\n')
    log.write('Running in test mode - will not archive\n\n')

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
    foundjobnames = [j['name'].lower() for j in jobs]
    missingjobs = [j for j in jobnames if j.lower() not in foundjobnames]
    if missingjobs is not None and len(missingjobs) > 0:
        for j in missingjobs:
            print('Warning: job "%s" not found. Skipping...\n' % j)
            log.write('Warning: job "%s" not found. Skipping...\n' % j)

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
    log.write('\nError: external target %s not found\n' % target)
    log.close()
    exit(1)

startTimeUsecs = timeAgo(daysback, 'days')

busystates = ['kAccepted', 'kRunning', 'kCanceling']
completedstates = ['kSuccess']

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    runs = api('get', 'protectionRuns?jobId=%s&startTimeUsecs=%s&excludeTasks=true&numRuns=10000' % (job['id'], startTimeUsecs))
    runs = [r for r in runs if r['backupRun']['snapshotsDeleted'] is not True]
    runs = [r for r in runs if 'endTimeUsecs' in r['backupRun']['stats']]

    if excludelogs is True:
        runs = [r for r in runs if r['backupRun']['runType'] != 'kLog']
    for run in sorted(runs, key=lambda run: run['backupRun']['stats']['startTimeUsecs']):
        daysToKeep = keepfor

        if 'expiryTimeUsecs' in run['copyRun'][0]:
            expiryTimeUsecs = run['copyRun'][0]['expiryTimeUsecs']

            archiveThisRun = True

            # busy copyRuns
            busyCopyRuns = [c for c in run['copyRun'] if c['status'] in busystates]
            if busyCopyRuns is not None and len(busyCopyRuns) > 0:
                archiveThisRun = False

            # this run already archived to our target
            successfulArchives = [c for c in run['copyRun'] if c['target']['type'] == 'kArchival' and c['target']['archivalTarget']['vaultName'].lower() == target['vaultName'].lower() and c['status'] in completedstates]
            if successfulArchives is not None and len(successfulArchives) > 0:
                archiveThisRun = False

            if archiveThisRun is True:
                thisrun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&excludeTasks=true&id=%s' % (run['backupRun']['stats']['startTimeUsecs'], run['jobId']))
                jobUid = thisrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']

                # see if we need to extend the local snapshot due to failing archive attempts
                unsuccessfulArchives = [c for c in run['copyRun'] if c['target']['type'] == 'kArchival' and c['target']['archivalTarget']['vaultName'].lower() == target['vaultName'].lower() and c['status'] not in completedstates]
                if unsuccessfulArchives is not None and len(unsuccessfulArchives) > 0:
                    log.write('Warning: %s (%s) -> %s previously ended with status: %s\n' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], unsuccessfulArchives[0]['status']))
                    # extend retention of local snapshot for one day
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

                # calculate days to keep
                thisDaysToKeep = daysToKeep
                for retentionString in retentionstrings:
                    if retentionString.lower() in job['name'].lower():
                        retentionString = ''.join([i for i in retentionString if i.isdigit()])
                        if retentionString.isdigit():
                            thisDaysToKeep = int(retentionString)

                thisDaysToKeep = thisDaysToKeep - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])
                archiveTask['jobRuns'][0]['copyRunTargets'][0]['daysToKeep'] = int(thisDaysToKeep)

                # perform archive
                if force and int(thisDaysToKeep) > 0:
                    print('archiving %s (%s) -> %s for %s days' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
                    log.write('archiving %s (%s) -> %s for %s days\n' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
                    result = api('put', 'protectionRuns', archiveTask)
                else:
                    print('%s (%s) -> %s for %s days' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
                    log.write('would archive %s (%s) -> %s for %s days\n' % (job['name'], usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), target['vaultName'], thisDaysToKeep))
log.write('\n')
log.close()
