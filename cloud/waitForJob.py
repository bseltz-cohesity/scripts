#!/usr/bin/env python
"""Wait for protection job to finish"""

### usage: ./waitForJob.py -v mycluster -u myuser -d mydomain.net -j 'My Job'

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobName', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobName = args.jobName

### authenticate
apiauth(vip, username, domain, quiet=True)

### find protectionJob
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
if not job:
    print("Job '%s' not found" % jobName)
    exit(1)

# wait for existing job run to finish
finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
finished = False
print("waiting for existing job run to finish...")
while finished is False:
    finished = True
    runs = sorted(api('get', 'protectionRuns?jobId=%s&startTimeUsecs=%s' % (job[0]['id'], timeAgo(30, 'days'))), key=lambda result: result['backupRun']['stats']['startTimeUsecs'], reverse=True)
    for run in runs:
        for copyRun in run['copyRun']:
            if (copyRun['status'] not in finishedStates):
                finished = False
    if finished is False:
        sleep(5)

print("latest job run completed with status: %s" % runs[0]['backupRun']['status'])
exit(0)
