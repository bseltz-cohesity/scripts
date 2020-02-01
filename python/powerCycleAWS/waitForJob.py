#!/usr/bin/env python
"""Wait for protection jobs to finish"""

### usage: ./waitForJob.py -v mycluster -u myuser -d mydomain.net

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain

### authenticate
apiauth(vip, username, domain, quiet=True)

jobs = api('get', 'protectionJobs')

# wait for existing job runs to finish
finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
finished = False
print("waiting for existing job runs to finish...")
while finished is False:
    finished = True
    for job in jobs:
        runs = sorted(api('get', 'protectionRuns?jobId=%s&startTimeUsecs=%s&excludeTasks=true' % (job['id'], timeAgo(31, 'days'))), key=lambda result: result['backupRun']['stats']['startTimeUsecs'], reverse=True)
        for run in runs:
            for copyRun in run['copyRun']:
                if (copyRun['status'] not in finishedStates and copyRun['target']['type'] != 'kArchival'):
                    finished = False
    if finished is False:
        sleep(5)

exit(0)
