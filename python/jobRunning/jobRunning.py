#!/usr/bin/env python
"""is job running?"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-j', '--jobname', type=str, required=True)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
jobname = args.jobname

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

jobs = api('get', 'data-protect/protection-groups', v=2)
job = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
if job is None or len(job) == 0:
    print('*** job %s not found' % jobname)
    exit(1)
else:
    job = job[0]

finishedStates = ['Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning']

runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=1&includeTenants=true' % job['id'], v=2)
if runs is None or 'runs' not in runs or len(runs['runs']) == 0:
    exit(0)
else:
    status = runs['runs'][0]['localBackupInfo']['status']
    if status in finishedStates:
        print('*** %s is not running' % jobname)
        exit(0)
    else:
        print('*** %s is already running' % jobname)
        exit(1)
