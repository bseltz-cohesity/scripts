#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-nu', '--nameofuser', type=str, required=True)
parser.add_argument('-du', '--domainofuser', type=str, default='local')
parser.add_argument('-x', '--deactivate', action='store_true')
parser.add_argument('-a', '--activate', action='store_true')
parser.add_argument('-k', '--keyname', type=str, default=None)
parser.add_argument('-r', '--rotate', action='store_true')
parser.add_argument('-c', '--create', action='store_true')
parser.add_argument('-z', '--delete', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
nameofuser = args.nameofuser
domainofuser = args.domainofuser
deactivate = args.deactivate
activate = args.activate
keyname = args.keyname
rotate = args.rotate
create = args.create
delete = args.delete

# authentication =========================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant, quiet=True)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

users = api('get', 'users')
thisuser = [u for u in users if u['username'].lower() == nameofuser.lower() and u['domain'].lower() == domainofuser.lower()]
if thisuser is None or len(thisuser) == 0:
    print('user %s/%s not found' % (domainofuser, nameofuser))
    exit(1)
else:
    thisuser = thisuser[0]
    if create:
        if keyname is None:
            print('-k, --keyname required')
            exit()
        params = {
            'isActive': True,
            'user': thisuser,
            'name': keyname
        }
        result = api('post', 'users/%s/apiKeys' % thisuser['sid'], params)
        if result is not None and 'key' in result:
            print(result['key'])
            exit()
    apiKeys = api('get', 'users/%s/apiKeys' % thisuser['sid'])
    if apiKeys is None or len(apiKeys) == 0:
        print('No API Keys found for user')
    else:
        foundkey = True
        if keyname is not None:
            foundkey = False
        for apiKey in apiKeys:
            if keyname is None or keyname.lower() == apiKey['name'].lower():
                foundkey = True
                if deactivate:
                    print('  deactivating %s' % apiKey['name'])
                    apiKey['isActive'] = False
                    api('put', 'users/%s/apiKeys/%s' % (thisuser['sid'], apiKey['id']), apiKey)
                elif activate:
                    print('  activating %s' % apiKey['name'])
                    apiKey['isActive'] = True
                    api('put', 'users/%s/apiKeys/%s' % (thisuser['sid'], apiKey['id']), apiKey)
                elif rotate:
                    result = api('post', 'users/%s/apiKeys/%s/rotate' % (thisuser['sid'], apiKey['id']))
                    if result is not None and 'key' in result:
                        print(result['key'])
                elif delete:
                    result = api('delete', 'users/%s/apiKeys/%s' % (thisuser['sid'], apiKey['id']))
                    print('  %s (DELETED)' % apiKey['name'])
                else:
                    print('  %s (isActive = %s)' % (apiKey['name'], apiKey['isActive']))
    if foundkey is False:
        print('API key %s not found' % keyname)
