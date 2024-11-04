#!/usr/bin/env python
"""exclude MongoDB collection"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-n', '--collectionname', action='append', type=str)
parser.add_argument('-c', '--collectionlist', type=str)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
jobnames = args.jobname
joblist = args.joblist
collectionnames = args.collectionname
collectionlist = args.collectionlist


# gather server list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


jobnames = gatherList(jobnames, joblist, name='jobs', required=False)
collections = gatherList(collectionnames, collectionlist, name='collections', required=True)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kMongoDB', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

sources = api('get', 'protectionSources?environments=kMongoDB')

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        modified = False
        source = [s for s in sources if s['protectionSource']['id'] == job['mongodbParams']['sourceId']][0]
        for db in source['nodes']:
            for collection in db['nodes']:
                if collection['protectionSource']['name'].lower() in [c.lower() for c in collections]:
                    if 'excludeObjectIds' not in job['mongodbParams'] or job['mongodbParams']['excludeObjectIds'] is None:
                        job['mongodbParams']['excludeObjectIds'] = []
                    if collection['protectionSource']['id'] not in job['mongodbParams']['excludeObjectIds']:
                        job['mongodbParams']['excludeObjectIds'].append(collection['protectionSource']['id'])
                        modified = True
        if modified is True:
            print('Updating %s' % job['name'])
            result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
        else:
            print('No changes to %s' % job['name'])
