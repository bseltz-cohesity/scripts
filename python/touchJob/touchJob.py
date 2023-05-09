#!/usr/bin/env python
"""base V2 example"""

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
parser.add_argument('-j', '--jobname', required=True, type=str)
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
jobname = args.jobname

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&names=%s' % jobname, v=2)
if jobs['protectionGroups'] is not None and len(jobs['protectionGroups']) > 0:
    job = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if job is not None and len(job) > 0:
        print('updating job %s' % jobname)
        result = api('put', 'data-protect/protection-groups/%s' % job[0]['id'], job[0], v=2)
    else:
        print('job %s not found' % jobname)
else:
    print('job %s not found' % jobname)
