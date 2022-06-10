#!/usr/bin/env python
"""unprotect physical sources"""

# version 2021-12-03

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-n', '--sourcename', action='append', type=str)
parser.add_argument('-l', '--sourcelist', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
sourcenames = args.sourcename
sourcelist = args.sourcelist

paramPaths = {'kFile': 'fileProtectionTypeParams', 'kVolume': 'volumeProtectionTypeParams'}

# gather source list
if sourcenames is None:
    sourcenames = []
if sourcelist is not None:
    f = open(sourcelist, 'r')
    sourcenames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
if len(sourcenames) == 0:
    print('no sources specified')
    exit()

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

sourcefound = {}
for source in sourcenames:
    sourcefound[source] = False

sources = api('get', 'protectionSources/registrationInfo?includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false')

for source in sourcenames:
    thissource = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == source.lower()]
    if thissource is not None and len(thissource) > 0:
        thissource = thissource[0]
        thissourcename = thissource['rootNode']['name']
        thissourceid = thissource['rootNode']['id']
        if thissourcename.lower() == source.lower():
            sourcefound[source] = True
            print('Unregistering %s' % thissourcename)
            result = api('delete', 'protectionSources/%s' % thissourceid)

for source in sourcenames:
    if sourcefound[source] is False:
        print('%s not found' % source)
