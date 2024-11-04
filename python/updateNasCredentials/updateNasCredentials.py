#!/usr/bin/env python
"""Update NAS Credentials"""

# usage: ./updateNasCredentials.py -v mycluster \
#                                  -u myuser \
#                                  -d mydomain.net \
#                                  -s mynetapp \
#                                  -su mysmbusername \
#                                  -sp mysmbpassword \
#                                  -sd mysmbdomain.net \
#                                  -au myapiusername \
#                                  -ap myapipassword

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-au', '--apiuser', type=str, default=None)
parser.add_argument('-ap', '--apipassword', type=str, default=None)
parser.add_argument('-su', '--smbuser', type=str, default=None)
parser.add_argument('-sp', '--smbpassword', type=str, default=None)
parser.add_argument('-sd', '--smbdomain', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
sourcename = args.sourcename
apiuser = args.apiuser
apipassword = args.apipassword
smbuser = args.smbuser
smbpassword = args.smbpassword
smbdomain = args.smbdomain

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

sources = api('get', 'protectionSources/registrationInfo?includeEntityPermissionInfo=true')

mySource = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == sourcename.lower()]

if len(mySource) == 0:
    print("NAS source $sourceName not found!")
    exit(1)

mySource = mySource[0]

sourceInfo = api('get', '/backupsources?allUnderHierarchy=true&entityId=%s&onlyReturnOneLevel=true' % mySource['rootNode']['id'])

updateParams = {
    "entity": sourceInfo['entityHierarchy']['entity'],
    "entityInfo": sourceInfo['entityHierarchy']['registeredEntityInfo']['connectorParams']
}

if smbuser is not None:
    updateParams['entityInfo']['credentials']['nasMountCredentials']['username'] = smbuser

if smbdomain is not None:
    updateParams['entityInfo']['credentials']['nasMountCredentials']['domainName'] = smbdomain

if smbpassword is not None:
    updateParams['entityInfo']['credentials']['nasMountCredentials']['password'] = smbpassword

if apiuser is not None:
    updateParams['entityInfo']['credentials']['username'] = apiuser

if apipassword is not None:
    updateParams['entityInfo']['credentials']['password'] = apipassword

print('Updating %s...' % sourcename)
response = api('put', '/backupsources/%s' % mySource['rootNode']['id'], updateParams)
