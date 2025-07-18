#!/usr/bin/env python

from pyhesity import *
import argparse
import getpass

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-noprompt', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-ip', '--ipmipassword', type=str, default=None)
parser.add_argument('-iu', '--ipmiuser', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
ipmipassword = args.ipmipassword
ipmiuser = args.ipmiuser

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode)

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

if ipmipassword is None:
    while(True):
        ipmipassword = getpass.getpass("\n  Enter IPMI password: ")
        confirmpassword = getpass.getpass("Confirm IPMI password: ")
        if ipmipassword == confirmpassword:
            break
        else:
            print('\nPasswords do not match\n')

creds = {
    "clusterIpmiUser": ipmiuser,
    "ipmiPassword": ipmipassword
}

result = api('put', '/nexus/ipmi/cluster_update_users', creds)
if 'message' in result:
    print('%s' % result['message'])
else:
    print('\nAn error has occurred\n')
    exit(1)
