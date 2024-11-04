#!/usr/bin/env python
"""Add Global Exclude Paths to a file-based protection job"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-e', '--exclusions', action='append', type=str)
parser.add_argument('-x', '--excludelist', type=str)
parser.add_argument('-r', '--replacerules', action='store_true')

args = parser.parse_args()

vip = args.vip                  # cluster name/ip
username = args.username        # username to connect to cluster
domain = args.domain            # domain of username (e.g. local, or AD domain)
jobnames = args.jobname         # name of protection job to add server to
joblist = args.joblist
excludes = args.exclusions         # exclude path
excludelist = args.excludelist  # file with exclude paths
replacerules = args.replacerules

# read joblist file
if jobnames is None:
    jobnames = []
if joblist is not None:
    f = open(joblist, 'r')
    jobnames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

if len(jobnames) == 0:
    print('No jobs specified')
    exit()

# read exclude file
if excludes is None:
    excludes = []
if excludelist is not None:
    f = open(excludelist, 'r')
    excludes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

if len(excludes) == 0:
    print('No exclusions specified')
    exit()

# authenticate to Cohesity
apiauth(vip, username, domain)

protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true', v=2)

for jobname in jobnames:

    protectionGroup = [p for p in protectionGroups['protectionGroups'] if p['name'].lower() == jobname.lower()][0]
    if len(protectionGroup) == 0:
        print('Job %s not found' % jobname)
    else:
        print('Updating %s' % jobname)
        if replacerules is not True:
            globalExcludePaths = protectionGroup['physicalParams']['fileProtectionTypeParams']['globalExcludePaths']
        else:
            globalExcludePaths = []

        for exclude in excludes:
            globalExcludePaths.append(exclude)

        globalExcludePaths = list(set(globalExcludePaths))

        protectionGroup['physicalParams']['fileProtectionTypeParams']['globalExcludePaths'] = globalExcludePaths
        result = api('put', 'data-protect/protection-groups/%s' % protectionGroup['id'], protectionGroup, v=2)
