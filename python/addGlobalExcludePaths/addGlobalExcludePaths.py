#!/usr/bin/env python
"""Add Global Exclude Paths to File-based Protection Job Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludefile', type=str)
parser.add_argument('-o', '--overwrite', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobnames = args.jobname          # name of protection job to add server to
joblist = args.joblist
excludes = args.exclude         # exclude path
excludefile = args.excludefile  # file with exclude paths
overwrite = args.overwrite

# read server file
if jobnames is None:
    jobnames = []
if joblist is not None:
    f = open(joblist, 'r')
    jobnames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
jobnames = [j.lower() for j in jobnames]

# read exclude file
if excludes is None:
    excludes = []
if excludefile is not None:
    f = open(excludefile, 'r')
    excludes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    if emailmfacode:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, emailMfaCode=True)
    else:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, mfaCode=mfacode)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if apiconnected() is False:
    print('authentication failed')
    exit(1)

# get jobs
jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&environments=kPhysical&includeTenants=true', v=2)
if jobs['protectionGroups'] is not None and len(jobs['protectionGroups']) > 0:
    jobs = [j for j in jobs['protectionGroups'] if j['physicalParams']['protectionType'] == 'kFile' and j['name'].lower() in jobnames]

    missingjobs = [n for n in jobnames if n not in [j['name'].lower() for j in jobs]]
    if missingjobs is not None and len(missingjobs) > 0:
        for n in missingjobs:
            print('job %s not found' % n)
        exit(1)

for job in jobs:
    globalExcludePaths = job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths']
    if globalExcludePaths is None or overwrite is True:
        globalExcludePaths = []
    globalExcludePaths += excludes
    job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths'] = list(set(globalExcludePaths))
    print('Updating job %s' % job['name'])
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
