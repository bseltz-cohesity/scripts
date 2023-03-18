#!/usr/bin/env python
"""base V2 example"""

# import pyhesity wrapper module
from pyhesity import *
import re

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
parser.add_argument('-o', '--oldnode', type=str, required=True)
parser.add_argument('-n', '--newnode', type=str, required=True)
parser.add_argument('-r', '--newjobname', type=str, default=None)

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
oldnode = args.oldnode
newnode = args.newnode
newjobname = args.newjobname

recompiled = re.compile(re.escape(oldnode), re.IGNORECASE)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode, tenantId=tenant)

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

sources = api('get', 'protectionSources/registrationInfo?environments=kPhysical')
if 'rootNodes' in sources and len(sources['rootNodes']) > 0:
    newSource = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == newnode.lower()]
    if len(newSource) == 0:
        print('%s not found')
        exit()
    else:
        newSource = newSource[0]
else:
    print('%s not found' % newnode)
    exit()

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kPhysical', v=2)

if jobs is None or 'protectionGroups' not in jobs or jobs['protectionGroups'] is None or len(jobs['protectionGroups']) == 0:
    print('%s not found' % jobname)
    exit()
else:
    job = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if job is None or len(job) == 0:
        print('%s not found' % jobname)
        exit()
    else:
        job = job[0]

if job['physicalParams']['protectionType'] == 'kFile':
    foundOldNode = False
    for o in job['physicalParams']['fileProtectionTypeParams']['objects']:
        if o['name'].lower() == oldnode.lower():
            foundOldNode = True
            o['name'] = newSource['rootNode']['name']
            o['id'] = newSource['rootNode']['id']
            for filePath in o['filePaths']:
                if oldnode.lower() in filePath['includedPath'].lower():
                    filePath['includedPath'] = str(recompiled.sub(newSource['rootNode']['name'], filePath['includedPath']))
                    for excludedPath in filePath['excludedPaths']:
                        if oldnode.lower() in excludedPath.lower():
                            excludedPath = str(recompiled.sub(newSource['rootNode']['name'], excludedPath))
                            filePath['excludedPaths'].append(excludedPath)
                    filePath['excludedPaths'] = [e for e in filePath['excludedPaths'] if oldnode.lower() not in e.lower()]
    if foundOldNode is True:
        if newjobname:
            print('Renaming %s -> %s' % (job['name'], newjobname))
            job['name'] = newjobname
        else:
            print('Updating %s' % job['name'])
        print('Swapping %s -> %s' % (oldnode, newnode))
        result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
    else:
        print('%s not found in %s' % (oldnode, jobname))
else:
    print('%s is not a file-based protection group' % jobname)
    exit()
