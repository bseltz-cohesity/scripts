#!/usr/bin/env python
"""Archive Now for python"""

# usage: ./archiveNow.py -v mycluster -u myuser -d mydomain.net -j MyJob -r '2019-03-26 14:47:00'

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-r', '--rundate', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobname = args.jobname
rundate = args.rundate

rundateusecs = dateToUsecs(rundate)

# authenticate
apiauth(vip, username, domain)

# find protection job
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobname.lower()]
if not job:
    print("Job '%s' not found" % jobName)
    exit()
else:
    job = job[0]

# get archive policy
policyId = job['policyId']
policy = api('get', 'protectionPolicies/%s' % policyId)
target = policy['snapshotArchivalCopyPolicies'][0]['target']
daysToKeep = policy['snapshotArchivalCopyPolicies'][0]['daysToKeep']

# find requested run
runs = api('get', 'protectionRuns?jobId=%s' % job['id'])

for run in runs:
    existingarchive = False

    # zero out seconds for rundate match
    thisrundate = datetime.strptime(usecsToDate(run['copyRun'][0]['runStartTimeUsecs']), "%Y-%m-%d %H:%M:%S")
    thisrundatebase = (thisrundate - timedelta(seconds=thisrundate.second)).strftime("%Y-%m-%d %H:%M:%S")

    if rundate == thisrundatebase:
        print('archiving snapshot from %s...' % usecsToDate(run['copyRun'][0]['runStartTimeUsecs']))
        for copyRun in run['copyRun']:

            # resync existing archive run
            if copyRun['target']['type'] == 'kArchival':
                target = copyRun['target']['archivalTarget']
                existingarchive = True

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
                        "jobUid": run['jobUid']
                    }
                ]
            }

            # set retention on new run
            if existingarchive is False:
                daysToKeep = daysToKeep - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])
                archiveTask['jobRuns'][0]['copyRunTargets'][0]['daysToKeep'] = int(daysToKeep)

            # update run
            if(daysToKeep > 0):
                result = api('put', 'protectionRuns', archiveTask)
