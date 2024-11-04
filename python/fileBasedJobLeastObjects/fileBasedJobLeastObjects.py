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
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-n', '--namematch', type=str, default=None)
parser.add_argument('-l', '--showlist', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
namematch = args.namematch
showlist = args.showlist

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, quiet=True)

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

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kPhysical', v=2)
if 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
    jobs = [job for job in jobs['protectionGroups'] if job['physicalParams']['protectionType'] == 'kFile']
    if namematch:
        jobs = [job for job in jobs if namematch.lower() in job['name'].lower()]
    if len(jobs) > 0:
        jobs = sorted(jobs, key=lambda job: len(job['physicalParams']['fileProtectionTypeParams']['objects']))
        if showlist:
            for job in jobs:
                mytuple = (job['name'], len(job['physicalParams']['fileProtectionTypeParams']['objects']))
                print(mytuple)
        else:
            print(jobs[0]['name'])
    else:
        print('None')
else:
    print('None')
