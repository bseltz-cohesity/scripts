#!/usr/bin/env python
"""Archive Now for python"""

# usage: ./archiveNow.py -v mycluster -u myuser -d mydomain.net -j MyJob -r '2019-03-26 14:47:00' [ -k 5 ] [ -t S3 ] [ -f ]

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-j', '--jobname', type=str, required=True)   # job name
parser.add_argument('-r', '--rundate', type=str, default=None)   # run date to archive in military format with 00 seconds
parser.add_argument('-k', '--keepfor', type=int, required=True)    # (optional) will use policy retention if omitted
parser.add_argument('-t', '--target', type=str, required=True)  # (optional) will use policy target if omitted
parser.add_argument('-f', '--fromtoday', action='store_true')     # (optional) keepfor x days from today instead of from snapshot date
parser.add_argument('-l', '--listruns', action='store_true')
parser.add_argument('-n', '--newestrun', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobname = args.jobname
rundate = args.rundate
keepfor = args.keepfor
target = args.target
fromtoday = args.fromtoday
listruns = args.listruns
newestrun = args.newestrun

# authenticate
apiauth(vip, username, domain)

# find protection job
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobname.lower()]
if not job:
    print("Job '%s' not found" % jobname)
    exit()
else:
    job = job[0]

daysToKeep = None


vault = [vault for vault in api('get', 'vaults') if vault['name'].lower() == target.lower()]
if len(vault) > 0:
    vault = vault[0]
    target = {
        "vaultId": vault['id'],
        "vaultName": vault['name'],
        "vaultType": "kCloud"
    }
else:
    print('No archive target named %s' % target)
    exit()

if keepfor:
    daysToKeep = keepfor

# find requested run

runs = api('get', 'protectionRuns?jobId=%s' % job['id'])

foundRun = False
for run in runs:

    # zero out seconds for rundate match
    thisrundate = datetime.strptime(usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), "%Y-%m-%d %H:%M:%S")
    thisrundatebase = (thisrundate - timedelta(seconds=thisrundate.second)).strftime("%Y-%m-%d %H:%M:%S")
    if listruns is True:
        print(thisrundatebase)
    else:
        if rundate == thisrundatebase or newestrun:
            thisrun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&excludeTasks=true&id=%s' % (run['backupRun']['stats']['startTimeUsecs'], run['jobId']))
            jobUid = thisrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']
            foundRun = True
            currentExpiry = None
            for copyRun in run['copyRun']:

                # resync existing archive run
                if copyRun['target']['type'] == 'kArchival':
                    target = copyRun['target']['archivalTarget']
                    currentExpiry = copyRun.get('expiryTimeUsecs', 0)

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

            # if fromtoday is not set, calculate days to keep from snapshot date
            if fromtoday is False:
                daysToKeep = daysToKeep - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])

            # if there's an existing archive and keepfor is specified adjust the retention
            if keepfor is not None and currentExpiry != 0 and currentExpiry is not None:
                if currentExpiry != 0 and currentExpiry is not None:
                    daysToKeep = daysToKeep + (dayDiff(run['copyRun'][0]['runStartTimeUsecs'], currentExpiry))
                archiveTask['jobRuns'][0]['copyRunTargets'][0]['daysToKeep'] = int(daysToKeep)

            # if the current archive was deleted, resync it
            if currentExpiry == 0:
                archiveTask['jobRuns'][0]['copyRunTargets'][0]['daysToKeep'] = int(daysToKeep)

            # update run
            if((daysToKeep > 0 and currentExpiry is None) or (daysToKeep != 0 and currentExpiry is not None)):
                print('archiving snapshot from %s...' % usecsToDate(run['copyRun'][0]['runStartTimeUsecs']))
                result = api('put', 'protectionRuns', archiveTask)
                exit()
            else:
                print('Not archiving because expiry time would be in the past or unchanged')

# report if no run was found
if foundRun is False and listruns is not True:
    print('Could not find a run with the date %s' % rundate)
