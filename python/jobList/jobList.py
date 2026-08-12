#!/usr/bin/env python
"""List Protection Jobs for python"""

# usage: ./jobList.py -v mycluster -u myuser -d mydomain.net [ -s defaultStorageDomain ] [ -e vmware ]

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
parser.add_argument('--emailmfacode', action='store_true')
parser.add_argument('-s', '--storagedomain', type=str, default=None)
parser.add_argument('-e', '--environment', type=str, default=None)
parser.add_argument('-p', '--paused', action='store_true')

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
storagedomain = args.storagedomain
environment = args.environment
paused = args.paused

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

sd = []
if storagedomain is not None:
    sd = [s for s in api('get', 'viewBoxes') if s['name'].lower() == storagedomain.lower()]
    if len(sd) > 0:
        sd = sd[0]
    else:
        print('Storage Domain %s not found' % storagedomain)
        exit(1)

# find protection job
jobs = sorted(api('get', 'protectionJobs'), key=lambda j: j['name'])
for job in jobs:
    if storagedomain is None or sd['id'] == job['viewBoxId']:
        if environment is None or job['environment'][1:].lower() == environment.lower():
            if not paused or ('isPaused' in job and job['isPaused'] is True):
                print('%s (%s)' % (job['name'], job['environment'][1:]))