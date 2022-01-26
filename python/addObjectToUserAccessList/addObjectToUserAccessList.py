#!/usr/bin/env python
"""get cluster vips by least busy CPU"""

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
parser.add_argument('-o', '--objectname', action='append', type=str)
parser.add_argument('-vn', '--viewname', action='append', type=str)
parser.add_argument('-n', '--aduser', type=str, required=True)       # AD user to onboard
parser.add_argument('-a', '--addomain', type=str, default='local')     # AD user to onboard

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
objectnames = args.objectname
viewnames = args.viewname
aduser = args.aduser
addomain = args.addomain

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True, quiet=True)

views = api('get', 'views')
sources = api('get', 'protectionSources')
users = api('get', 'users')
user = [u for u in users if u['username'].lower() == aduser.lower() and u['domain'].lower() == addomain.lower()]
if user is None or len(user) == 0:
    print('user %s\\%s not found' % (addomain, aduser))
    exit(1)
user = user[0]
access = api('get', 'principals/protectionSources?sids=%s' % user['sid'])
access = access[0]

protectionSourceIds = []
if 'protectionSources' in access:
    protectionSourceIds = [p['id'] for p in access['protectionSources']]
theseviewnames = []
if 'views' in access:
    theseviewnames = [v['name'] for v in access['views']]


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


newAccess = {
    "sourcesForPrincipals": [
        {
            "sid": user['sid'],
            "protectionSourceIds": protectionSourceIds,
            "viewNames": theseviewnames
        }
    ]
}

for objectname in objectnames:
    objectid = getObjectId(objectname)
    if objectid is None:
        print('Object %s not found' % objectname)
        exit(1)
    print('Granting %s\\%s rights to %s' % (addomain, aduser, objectname))
    newAccess['sourcesForPrincipals'][0]['protectionSourceIds'].append(objectid)

for viewname in viewnames:
    thisviewname = [v['name'] for v in views['views'] if v['name'].lower() == viewname.lower()]
    if thisviewname is None or len(thisviewname) == 0:
        print('View %s not found' % viewname)
        exit(1)
    print('Granting %s\\%s rights to %s' % (addomain, aduser, thisviewname[0]))
    newAccess['sourcesForPrincipals'][0]['viewNames'].append(thisviewname[0])

newAccess['sourcesForPrincipals'][0]['protectionSourceIds'] = list(set(newAccess['sourcesForPrincipals'][0]['protectionSourceIds']))
newAccess['sourcesForPrincipals'][0]['viewNames'] = list(set(newAccess['sourcesForPrincipals'][0]['viewNames']))

if user['restricted'] is False:
    user['restricted'] = True
    result = api('put', 'users', user)

result = api('put', 'principals/protectionSources', newAccess)
exit(0)
