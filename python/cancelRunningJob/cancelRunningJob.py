#!/usr/bin/env python
"""Cancel a running protection job"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)

args = parser.parse_args()

vip = args.vip                  # cluster name/ip
username = args.username        # username to connect to cluster
domain = args.domain            # domain of username (e.g. local, or AD domain)
jobname = args.jobname          # name of protection job to csncel
password = args.password
useApiKey = args.useApiKey

# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning']

jobs = api('get', 'protectionJobs')
jobs = [j for j in jobs if j['name'].lower() == jobname.lower()]

if len(jobs) == 0:
    print('Job %s now found' % jobname)
    exit()

for job in jobs:
    run = api('get', 'protectionRuns?numRuns=1&excludeTasks=true&jobId=%s' % job['id'])
    run = run[0]
    if run['backupRun']['status'] not in finishedStates:
        print('Cancelling %s: %s...' % (job['name'], (usecsToDate(run['backupRun']['stats']['startTimeUsecs']))))
        result = api('post', 'protectionRuns/cancel/%s' % job['id'], {"jobRunId": run['backupRun']['jobRunId']})
    else:
        print("%s not running" % job['name'])
