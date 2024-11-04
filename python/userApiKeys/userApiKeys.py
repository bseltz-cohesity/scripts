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

# authentication =========================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

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
    apiKeys = api('get', 'users/%s/apiKeys' % thisuser['sid'])
    if apiKeys is None or len(apiKeys) == 0:
        print('No API Keys found for user')
    else:
        for apiKey in apiKeys:
            if deactivate:
                print('  deactivating %s' % apiKey['name'])
                apiKey['isActive'] = False
                api('put', 'users/%s/apiKeys/%s' % (thisuser['sid'], apiKey['id']), apiKey)
            elif activate:
                print('  activating %s' % apiKey['name'])
                apiKey['isActive'] = True
                api('put', 'users/%s/apiKeys/%s' % (thisuser['sid'], apiKey['id']), apiKey)
            else:
                print('  %s (isActive = %s)' % (apiKey['name'], apiKey['isActive']))
