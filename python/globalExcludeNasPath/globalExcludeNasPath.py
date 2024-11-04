#!/usr/bin/env /usr/bin/python3
"""Add Global Exclude Paths to all Generic NAS"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-e', '--excludepath', type=str, required=True)
parser.add_argument('-r', '--remove', action='store_true')

args = parser.parse_args()

vip = args.vip                  # cluster name/ip
username = args.username        # username to connect to cluster
domain = args.domain            # domain of username (e.g. local, or AD domain)
excludepath = args.excludepath  # exclude path
remove = args.remove

# authenticate to Cohesity
apiauth(vip, username, domain)

protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&environments=kGenericNas', v=2)

for protectionGroup in protectionGroups['protectionGroups']:

    print('Updating %s' % protectionGroup['name'])
    globalExcludePaths = protectionGroup['genericNasParams']['fileFilters']['excludeList']

    if remove is True:
        if excludepath in globalExcludePaths:
            globalExcludePaths.remove(excludepath)
    else:
        globalExcludePaths.append(excludepath)

    globalExcludePaths = list(set(globalExcludePaths))

    protectionGroup['genericNasParams']['fileFilters']['excludeList'] = globalExcludePaths
    result = api('put', 'data-protect/protection-groups/%s' % protectionGroup['id'], protectionGroup, v=2)
