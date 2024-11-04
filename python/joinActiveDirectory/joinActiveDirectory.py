#!/usr/bin/env python

from pyhesity import *
import getpass
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-ad', '--addomain', type=str, required=True)
parser.add_argument('-au', '--adusername', type=str, required=True)
parser.add_argument('-ap', '--adpassword', type=str, default=None)
parser.add_argument('-cn', '--computername', type=str, required=True)
parser.add_argument('-ou', '--container', type=str, default='Computers')
parser.add_argument('-nb', '--netbiosname', type=str, default=None)
parser.add_argument('-ex', '--useexistingaccount', action='store_true')

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
addomain = args.addomain
adusername = args.adusername
adpassword = args.adpassword
computername = args.computername
container = args.container
netbiosname = args.netbiosname
useexistingaccount = args.useexistingaccount

if adpassword is None:
    adpassword = getpass.getpass("Enter password for %s\\%s: " % (addomain, adusername))

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

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

# define parameters
adParameters = {
    "domainName": addomain,
    "userName": adusername,
    "password": adpassword,
    "preferredDomainControllers": [
        {
            "domainName": addomain
        }
    ],
    "machineAccounts": [
        computername
    ],
    "overwriteExistingAccounts": False,
    "userIdMapping": {},
    "ouName": container
}

# add optional NETBIOS name
if netbiosname is not None:
    adParameters['workgroup'] = netbiosname

# overwrite existing account
if useexistingaccount is True:
    adParameters['overwriteExistingAccounts'] = True

# join AD
print('Joining %s...' % addomain)
result = api('post', 'activeDirectory', adParameters)
