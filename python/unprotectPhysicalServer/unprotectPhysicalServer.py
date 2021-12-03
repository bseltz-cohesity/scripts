#!/usr/bin/env python
"""unprotect physical servers"""

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
parser.add_argument('-n', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
servernames = args.servername
serverlist = args.serverlist

paramPaths = {'kFile': 'fileProtectionTypeParams', 'kVolume': 'volumeProtectionTypeParams'}

# gather server list
if servernames is None:
    servernames = []
if serverlist is not None:
    f = open(serverlist, 'r')
    servernames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
if len(servernames) == 0:
    print('no servers specified')
    exit()

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

serverfound = {}
for server in servernames:
    serverfound[server] = False

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&environments=kPhysical', v=2)

if 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
    for job in jobs['protectionGroups']:
        saveJob = False
        paramPath = paramPaths[job['physicalParams']['protectionType']]

        for server in servernames:
            protectedObjectCount = len(job['physicalParams'][paramPath]['objects'])
            job['physicalParams'][paramPath]['objects'] = [o for o in job['physicalParams'][paramPath]['objects'] if o['name'].lower() != server.lower()]
            if len(job['physicalParams'][paramPath]['objects']) < protectedObjectCount:
                print('%s removed from from group: %s' % (server, job['name']))
                serverfound[server] = True
                saveJob = True

        if saveJob is True:
            if len(job['physicalParams'][paramPath]['objects']) == 0:
                print('0 objects left in %s. Deleting...' % job['name'])
                result = api('delete', 'data-protect/protection-groups/%s' % job['id'], v=2)
            else:
                pass
                result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)

for server in servernames:
    if serverfound[server] is False:
        print('%s not found in any physical protection group. * * * * * *' % server)
