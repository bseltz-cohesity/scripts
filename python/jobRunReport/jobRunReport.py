#!/usr/bin/env python
"""Job Run Report"""

### usage: ./jobRunReport.py -v mycluster -u admin [-d domain]

### import pyhesity wrapper module
from pyhesity import *

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
apiauth(vip, username, domain)

### find protectionRuns for last 24 hours
runs = api('get', 'protectionRuns?startTimeUsecs=%s' % timeAgo('24', 'hours'))

seen = {}
print("{:>20} {:>10}  {:25}".format('JobName', 'Status ', 'StartTime'))
print("{:>20} {:>10}  {:25}".format('-------', '--------', '---------'))

for run in runs:
    jobName = run['jobName']
    status = run['backupRun']['status']
    startTime = usecsToDate(run['backupRun']['stats']['startTimeUsecs'])
    if jobName not in seen:
        seen[jobName] = True
        print("{:>20} {:>10}  {:25}".format(jobName, status, startTime))
