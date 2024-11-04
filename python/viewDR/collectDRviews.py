#!/usr/bin/env python
"""Collect View Metadata for DR"""

from pyhesity import *
import os
import json

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # the Cohesity cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # the Cohesity username to use
parser.add_argument('-d', '--domain', type=str, default='local')  # the Cohesity domain to use
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-p', '--outpath', type=str, required=True)  # local path to download file to

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
outpath = args.outpath

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

cluster = api('get', 'cluster')

metadataPath = os.path.join(outpath, cluster['name'])
if os.path.isdir(metadataPath) is False:
    try:
        os.mkdir(metadataPath)
    except Exception:
        pass

views = api('get', 'views')

print('\nGathering view settings...\n')

for view in views['views']:
    print('    %s' % view['name'])
    filepath = os.path.join(metadataPath, view['name'])
    f = open(filepath, 'w')
    json.dump(view, f)
    f.close()

print('\nDone\n')
