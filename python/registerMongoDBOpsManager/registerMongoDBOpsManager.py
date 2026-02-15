#!/usr/bin/env python

from pyhesity import *
from getpass import getpass
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
parser.add_argument('-n', '--hostname', required=True, type=str)
parser.add_argument('-p', '--port', required=True, type=int)
parser.add_argument('-certfile', '--certificatefile', type=str, default=None)
parser.add_argument('-certificate', '--certificate', type=str, default=None)
parser.add_argument('-pubkey', '--publickey',required=True, type=str)
parser.add_argument('-privkey', '--privatekey', type=str, default=None)

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

hostname = args.hostname
port = args.port

certificatefile = args.certificatefile
certificate = args.certificate
publickey = args.publickey
privatekey = args.privatekey

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

usessl = False
if certificate is not None or certificatefile is not None:
    usessl = True
    if certificatefile is not None:
        c = open(certificatefile, 'r')
        certificate = c.read()
        c.close()

if privatekey is None:
    privatekey = getpass("Please enter the private key: ")

sourcename = '%s:%s' % (hostname, port)
registeredSource = None
registeredSources = api('get', 'protectionSources/registrationInfo?environments=kMongoDBPhysical')
if registeredSources is not None and 'rootNodes' in registeredSources and registeredSources['rootNodes'] is not None and len(registeredSources['rootNodes']) > 0:
    registeredSource = [r for r in registeredSources['rootNodes'] if r['rootNode']['name'].lower() == sourcename.lower()]
if registeredSource is not None and len(registeredSource) > 0:
    print('%s already registered' % sourcename)
    exit(0)

newSource = {
    "environment": "kMongoDBPhysical",
    "mongodbOpsParams": {
        "hostname": hostname,
        "port": port,
        "isSSlRequired": usessl,
        "publicKey": publickey,
        "privateKey": privatekey
    }
}

if usessl is True:
    newSource['mongodbOpsParams']['caCertificate'] = certificate

result = api('post', 'data-protect/sources/registrations', newSource, v=2)
if result is not None and 'id' in result:
    print('Registering %s' % sourcename)
else:
    print('An error occurred')
