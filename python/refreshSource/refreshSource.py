#!/usr/bin/env python
"""Create basic protectionPolicy in python"""

# version 2020-10-12

### usage: ./createPolicy.py --vip mycluster \
#                            --username myuser \
#                            --domain mydomain.net \
#                            --useApiKey \
#                            --password abdce

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

sources = api('get', 'protectionSources')


### get object ID
def getObjectId(objectName):

    d = {'_object_id': None}

    def get_nodes(node):
        if 'name' in node:
            if node['name'].lower() == objectName.lower():
                d['_object_id'] = node['id']
                exit
        if 'protectionSource' in node:
            if node['protectionSource']['name'].lower() == objectName.lower():
                d['_object_id'] = node['protectionSource']['id']
                exit
        if 'nodes' in node:
            for node in node['nodes']:
                if d['_object_id'] is None:
                    get_nodes(node)
                else:
                    exit

    for source in sources:
        if d['_object_id'] is None:
            get_nodes(source)

    return d['_object_id']


for sourcename in sourceNames:
    objectId = getObjectId(sourcename)
    if objectId is not None:
        print('refreshing %s...' % sourcename)
        result = api('post', 'protectionSources/refresh/%s' % objectId)
        print(result)
    else:
        print('%s not found' % sourcename)
        exit(1)
