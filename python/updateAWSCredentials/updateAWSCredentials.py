#!/usr/bin/env python
"""Update VMware Credentials"""

# usage: ./updateVMwarePassword.py -v mycluster \
#                                  -u myuser \
#                                  -d mydomain.net
#                                  -sn vcenter1.mydomain.net \
#                                  -su administrator@vsphere.local \
#                                  -sp mypassword

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
parser.add_argument('-sn', '--sourcename', type=str, required=True)
parser.add_argument('-ak', '--accesskey', type=str, required=True)
parser.add_argument('-sk', '--secretkey', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
sourcename = args.sourcename
accesskey = args.accesskey
secretkey = args.secretkey

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# find requested VMware source
sources = api('get', 'protectionSources/registrationInfo?includeEntityPermissionInfo=true&environments=kAWS')
sources = [source for source in sources['rootNodes'] if source['rootNode']['name'].lower() == sourcename.lower()]
if len(sources) == 0:
    print('Source %s not found!' % sourcename)
    exit(1)

sourceid = sources[0]['rootNode']['id']
thissource = api('get', '/backupsources?allUnderHierarchy=true&entityId=%s&onlyReturnOneLevel=true' % sourceid)

# define update parameters
updateParams = {
    "entity": thissource['entityHierarchy']['entity'],
    "entityInfo": thissource['entityHierarchy']['registeredEntityInfo']['connectorParams'],
    "registeredEntityParams": thissource['entityHierarchy']['registeredEntityInfo']['registeredEntityParams']
}

updateParams['entityInfo']['credentials']['cloudCredentials']['awsCredentials']['accessKeyId'] = accesskey
updateParams['entityInfo']['credentials']['cloudCredentials']['awsCredentials']['secretAccessKey'] = secretkey

# perform update
print('updating username and password for %s...' % sourcename)
api('put', '/backupsources/%s' % sourceid, updateParams)
