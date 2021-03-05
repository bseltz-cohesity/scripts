#!/usr/bin/env python
"""refresh protection source"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)            # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')    # username
parser.add_argument('-d', '--domain', type=str, default='local')       # domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')          # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)      # optional password
parser.add_argument('-n', '--sourcename', type=str, action='append')   # optional name of vcenter

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
sourceNames = args.sourcename

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if sourceNames is None:
    print('No sources specified')
    exit()

sources = api('get', 'protectionSources/registrationInfo?allUnderHierarchy=false')
if 'rootNodes' not in sources:
    print('No sources found')
    exit()


def getObjectId(sourcename):
    for source in sources['rootNodes']:
        if source['rootNode']['name'].lower() == sourcename.lower():
            return source['rootNode']['id']
    return None


for sourcename in sourceNames:
    objectId = getObjectId(sourcename)
    if objectId is not None:
        print('refreshing %s...' % sourcename)
        result = api('post', 'protectionSources/refresh/%s' % objectId)
    else:
        print('%s not found' % sourcename)
