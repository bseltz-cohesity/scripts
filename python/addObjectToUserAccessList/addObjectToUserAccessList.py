#!/usr/bin/env python
"""add objects to user restricted objects list"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-on', '--objectname', action='append', type=str)
parser.add_argument('-ol', '--objectlist', type=str, default=None)
parser.add_argument('-vn', '--viewname', action='append', type=str)
parser.add_argument('-vl', '--viewlist', type=str, default=None)
parser.add_argument('-pn', '--principalname', action='append', type=str)
parser.add_argument('-pl', '--principallist', type=str, default=None)
parser.add_argument('-r', '--remove', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
objectnames = args.objectname
objectlist = args.objectlist
viewnames = args.viewname
viewlist = args.viewlist
principalnames = args.principalname
principallist = args.principallist
remove = args.remove

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)


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
        if d['_object_id'] is None and source['protectionSource']['name'] != 'Registered Agents':
            get_nodes(source)

    return d['_object_id']


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


principalnames = gatherList(principalnames, principallist, name='principals', required=True)
viewnames = gatherList(viewnames, viewlist, name='views', required=False)
objectnames = gatherList(objectnames, objectlist, name='objects', required=False)

if len(objectnames) == 0 and len(viewnames) == 0:
    print('no objects/views specified')
    exit(0)

views = api('get', 'views')
sources = api('get', 'protectionSources')
users = api('get', 'users')
groups = api('get', 'groups')

for p in principalnames:
    if '/' in p:
        (d, p) = p.split('/')
    elif '\\' in p:
        (d, p) = p.split('\\')
    else:
        d = 'local'
    ptype = 'user'
    thisPrincipal = [u for u in users if u['username'].lower() == p.lower() and u['domain'].lower() == d.lower()]
    if thisPrincipal is None or len(thisPrincipal) == 0:
        ptype = 'group'
        thisPrincipal = [g for g in groups if g['name'].lower() == p.lower() and g['domain'].lower() == d.lower()]
    if thisPrincipal is None or len(thisPrincipal) == 0:
        print('Principal %s/%s not found' % (d, p))
        continue
    else:
        thisPrincipal = thisPrincipal[0]
        print('%s/%s' % (d, p))
    access = api('get', 'principals/protectionSources?sids=%s' % thisPrincipal['sid'])
    access = access[0]
    protectionSourceIds = []
    if 'protectionSources' in access:
        protectionSourceIds = [p['id'] for p in access['protectionSources']]
    theseviewnames = []
    if 'views' in access:
        theseviewnames = [v['name'] for v in access['views']]
    newAccess = {
        "sourcesForPrincipals": [
            {
                "sid": thisPrincipal['sid'],
                "protectionSourceIds": protectionSourceIds,
                "viewNames": theseviewnames
            }
        ]
    }

    for o in objectnames:
        objectId = getObjectId(o)
        if objectId is None:
            print('    Object %s not found!' % o)
            continue
        if remove:
            print('    Removing %s' % o)
            newAccess['sourcesForPrincipals'][0]['protectionSourceIds'] = [i for i in newAccess['sourcesForPrincipals'][0]['protectionSourceIds'] if i != objectId]
        else:
            print('    Adding %s' % o)
            newAccess['sourcesForPrincipals'][0]['protectionSourceIds'].append(objectId)

    for v in viewnames:
        view = [w for w in views['views'] if w['name'].lower() == v.lower()]
        if view is None or len(view) == 0:
            print('    View %s not found' % v)
            continue
        else:
            view = view[0]
        if remove:
            print('    Removing %s' % v)
            newAccess['sourcesForPrincipals'][0]['viewNames'] = [i for i in newAccess['sourcesForPrincipals'][0]['viewNames'] if i != view['name']]
        else:
            print('    Adding %s' % v)
            newAccess['sourcesForPrincipals'][0]['viewNames'].append(view['name'])

    newAccess['sourcesForPrincipals'][0]['protectionSourceIds'] = list(set(newAccess['sourcesForPrincipals'][0]['protectionSourceIds']))
    newAccess['sourcesForPrincipals'][0]['viewNames'] = list(set(newAccess['sourcesForPrincipals'][0]['viewNames']))

    thisPrincipal['restricted'] = True
    if ptype == 'user':
        result = api('put', 'users', thisPrincipal)
    else:
        result = api('put', 'groups', thisPrincipal)
    result = api('put', 'principals/protectionSources', newAccess)
