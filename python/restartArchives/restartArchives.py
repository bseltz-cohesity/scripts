#!/usr/bin/env python
"""restart canceled or failed archives"""

# usage: ./restartArchives.py -v mycluster -u admin [ -d local ] -j 'My Job' -t S3 -n 365 [ -x 30 ] [ -k 365 ] [ -a ]

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-j', '--jobname', type=str, required=True)   # job name
parser.add_argument('-t', '--target', type=str, required=True)    # name of archive target
parser.add_argument('-k', '--keepfor', type=int, required=True)    # (optional) will use policy retention if omitted
parser.add_argument('-n', '--newerthan', type=int, default=365)  # (optional) will use policy target if omitted
parser.add_argument('-x', '--ifexpiringafter', type=int, default=0)  # (optional) will use policy target if omitted
parser.add_argument('-a', '--archive', action='store_true')     # (optional) keepfor x days from today instead of from snapshot date

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobname = args.jobname
target = args.target
keepfor = args.keepfor
newerthan = args.newerthan
ifexpiringafter = args.ifexpiringafter
archive = args.archive

# authenticate
apiauth(vip, username, domain)

# find protection job
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobname.lower()]
if not job:
    print("Job '%s' not found" % jobname)
    exit()
else:
    job = job[0]

# get archive target info
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

# newerthan days in usecs
newerthanusecs = timeAgo(newerthan, 'days')

### find protectionRuns with old local snapshots that are not archived yet and sort oldest to newest
print("searching for cencelled archive tasks...")

runs = api('get', 'protectionRuns?jobId=%s&numRuns=999999&runTypes=kRegular&excludeTasks=true&excludeNonRestoreableRuns=true&startTimeUsecs=%s' % (job['id'], newerthanusecs))

for run in runs:

    if run['backupRun']['snapshotsDeleted'] is False:
        for copyrun in run['copyRun']:

            # find canceled or failed archive tasks
            if copyrun['target']['type'] == 'kArchival' and copyrun['status'] in ['kCanceled', 'kFailed']:
                rundate = usecsToDate(run['copyRun'][0]['runStartTimeUsecs'])
                jobname = run['jobName']

                # calculate days to keep
                if keepfor > 0:
                    expiretimeusecs = run['copyRun'][0]['runStartTimeUsecs'] + (keepfor * 86400000000)
                else:
                    expiretimeusecs = run['copyRun'][0]['expiryTimeUsecs']
                keepfor = keepfor - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])

                ### create archive task definition
                archiveTask = {
                    'jobRuns': [
                        {
                            'copyRunTargets': [
                                {
                                    'archivalTarget': target,
                                    'daysToKeep': int(keepfor),
                                    'type': 'kArchival'
                                }
                            ],
                            'runStartTimeUsecs': run['copyRun'][0]['runStartTimeUsecs'],
                            'jobUid': run['jobUid']
                        }
                    ]
                }

                ### If the Local Snapshot is not expiring soon...
                if keepfor > ifexpiringafter:
                    if archive:
                        print("Archiving %s  %s for %s days" % (rundate, jobname, keepfor))
                        ### execute archive task if arcvhive swaitch is set
                        result = api('put', 'protectionRuns', archiveTask)
                    else:
                        ### just display what we would do if archive switch is not set
                        print("%s  %s  (would archive for %s days)" % (rundate, jobname, keepfor))

                ### Otherwise tell us that we're not archiving since the snapshot is expiring soon
                else:
                    print("%s  %s  (expiring in %s days. skipping...)" % (rundate, jobname, keepfor))
