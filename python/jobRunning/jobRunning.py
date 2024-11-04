#!/usr/bin/env python
"""is job running?"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', type=str, required=True)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobname = args.jobname

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

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
