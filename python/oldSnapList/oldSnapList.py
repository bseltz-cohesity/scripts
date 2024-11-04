#!/usr/bin/env python
"""list old snapshots"""

# usage: ./oldSnapshotList.py -v mycluster -u admin -k 30

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-k', '--olderthan', type=int, default=0)  # number of days of snapshots to retain
parser.add_argument('-j', '--jobname', type=str, default=None)
parser.add_argument('-n', '--numruns', type=int, default=100)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
olderthan = args.olderthan
jobname = args.jobname
numruns = args.numruns

# authenticate
apiauth(vip, username, domain)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

for job in sorted(api('get', 'protectionJobs'), key=lambda job: job['name'].lower()):
    if jobname is None or jobname.lower() == job['name'].lower():
        endUsecs = nowUsecs
        while(1):
            runs = [r for r in api('get', 'protectionRuns?jobId=%s&numRuns=%s&endTimeUsecs=%s&excludeTasks=true&excludeNonRestoreableRuns=true' % (job['id'], numruns, endUsecs)) if r['backupRun']['stats']['endTimeUsecs'] < endUsecs]
            if len(runs) > 0:
                endUsecs = runs[-1]['backupRun']['stats']['startTimeUsecs']
            else:
                break
            for run in runs:
                startdate = usecsToDate(run['copyRun'][0]['runStartTimeUsecs'])
                startdateusecs = run['copyRun'][0]['runStartTimeUsecs']
                if startdateusecs < timeAgo(olderthan, 'days') and run['backupRun']['snapshotsDeleted'] is False:
                    print("%s: %s (%s)" % (startdate, job['name'], run['backupRun']['runType'][1:]))
