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
parser.add_argument('-lu', '--localusername', type=str, required=True)
parser.add_argument('-up', '--userpassword', type=str, default=None)

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
localusername = args.localusername
userpassword = args.userpassword

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

users = api('get', 'users?domain=LOCAL')

user = [u for u in users if u['username'].lower() == localusername.lower()]
if user is not None and len(user) > 0:
    user = user[0]
else:
    print('*** local user %s not found' % localusername)
    exit(1)

print('\nUpdating password for user: %s' % localusername)

if userpassword is None:
    while(True):
        userpassword = getpass.getpass("\nEnter the new password: ")
        confirmpassword = getpass.getpass("  Confirm new password: ")
        if userpassword == confirmpassword:
            break
        else:
            print('\nPasswords do not match')

user['password'] = userpassword
result = api('put', 'users', user)
if result is not None and 'username' in result:
    print('\nPassword updated successfully\n')
