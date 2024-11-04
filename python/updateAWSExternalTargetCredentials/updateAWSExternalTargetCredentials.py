#!/usr/bin/env python

from pyhesity import *
import getpass
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
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--targetname', type=str, required=True)
parser.add_argument('-a', '--accesskey', type=str, required=True)
parser.add_argument('-s', '--secretkey', type=str, default=None)

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
emailmfacode = args.emailmfacode
targetname = args.targetname
accesskey = args.accesskey
secretkey = args.secretkey

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

while secretkey is None or len(secretkey) < 2:
    secretkey = getpass.getpass("Please enter the secretkey: ")

vaults = api('get', 'vaults')
if len(vaults) > 0:
    vaults = [v for v in vaults if 'amazon' in v['config'] and v['name'].lower() == targetname.lower()]
    if len(vaults) > 0:
        print('updating credentials for target: %s...' % vaults[0]['name'])
        vaults[0]['config']['amazon']['accessKeyId'] = accesskey
        vaults[0]['config']['amazon']['secretAccessKey'] = secretkey
        result = api('put', 'vaults/%s' % vaults[0]['id'], vaults[0])
        exit(0)
print('target %s not found' % targetname)
