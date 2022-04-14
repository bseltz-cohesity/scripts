#!/usr/bin/env python
"""List Protected Objects for python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if apiconnected() is False:
    print('authentication failed')
    exit(1)

print('\ngathering registered sources...\n')
cluster = api('get', 'cluster')
now = datetime.now()
dateString = now.strftime("%Y-%m-%d")
outfile = 'registeredSources-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

sources = api('get', 'protectionSources/registrationInfo?includeApplicationsTreeInfo=false')

f.write('Source,Environment,Protected Count,Unprotected Count\n')

for source in sorted(sources['rootNodes'], key=lambda node: node['rootNode']['name']):
    sourcename = source['rootNode']['name']
    environment = source['rootNode']['environment'][1:]
    protected = source['stats']['protectedCount']
    unprotected = source['stats']['unprotectedCount']
    if 'environments' in source['registrationInfo']:
        for env in source['registrationInfo']['environments']:
            environment = '%s/%s' % (environment, env[1:])
    print('    %s (%s)' % (sourcename, environment))
    f.write('%s,%s,%s,%s\n' % (sourcename, environment, protected, unprotected))

f.close()
print('\nOutput saved to %s\n' % outfile)
