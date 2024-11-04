#!/usr/bin/env python
"""generate new agent certificate"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

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
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-country', '--country', type=str, default='US')
parser.add_argument('-state', '--state', type=str, default='CA')
parser.add_argument('-city', '--city', type=str, default='SN')
parser.add_argument('-org', '--organization', type=str, default='Cohesity')
parser.add_argument('-ou', '--organizationUnit', type=str, default='IT')
parser.add_argument('-x', '--expirydays', type=int, default=365)

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
servernames = args.servername
country = args.country
state = args.state
city = args.city
org = args.organization
ou = args.organizationUnit
expirydays = args.expirydays

if 'api_version' not in globals() or api_version < '2024.08.10':
    print('this script requires pyhesity.py version 2024.08.10 or later')
    exit()

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


servernames = gatherList(param=servernames, name='server names', required=True)

outfile = 'server_cert-%s' % servernames[0]
f = codecs.open(outfile, 'w')

certreq = {
    "commonName": "Agent (gRPC server)",
    "keyType": "RSA_4096",
    "organizationUnit": ou,
    "organization": org,
    "sanList": [
        "Agent (gRPC server)"
    ],
    "duration": "%sh" % int(expirydays * 24),
    "countryCode": country,
    "state": state,
    "city": city
}

for server in servernames:
    certreq['sanList'].append(server)
print('Requesting new certificate')
display(certreq)
newcert = api('post', 'cert-manager/binary-cert', certreq, v=2)
f.write(newcert)
f.close()
print('\nNew certificate saved to %s\n' % outfile)
