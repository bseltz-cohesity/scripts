#!/usr/bin/env python

from pyhesity import *
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
parser.add_argument('-n', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str, default=None)
parser.add_argument('-t', '--authtype', type=str, choices=['NONE', 'SCRAM', 'LDAP', 'KERBEROS'], default='NONE')
parser.add_argument('-au', '--authusername', type=str, default=None)
parser.add_argument('-ap', '--authpassword', type=str, default=None)
parser.add_argument('-ad', '--authdatabase', type=str, default=None)
parser.add_argument('-kp', '--krbprincipal', type=str, default=None)
parser.add_argument('-st', '--secondarytag', type=str, default=None)
parser.add_argument('-ssl', '--usessl', action='store_true')
parser.add_argument('-sec', '--usesecondary', action='store_true')

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
servername = args.servername
serverlist = args.serverlist
authtype = args.authtype
authusername = args.authusername
authpassword = args.authpassword
authdatabase = args.authdatabase
krbprincipal = args.krbprincipal
secondarytag = args.secondarytag
usessl = args.usessl
usesecondary = args.usesecondary

if noprompt is True:
    prompt = False
else:
    prompt = None


# gather list function
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


# get list of views to protect
servers = gatherList(servername, serverlist, name='servers', required=True)

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True, prompt=prompt)
else:
    if emailmfacode:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, emailMfaCode=True, prompt=prompt)
    else:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, mfaCode=mfacode, prompt=prompt)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if apiconnected() is False:
    print('authentication failed')
    exit(1)

for server in servers:
    server = server.replace(' ', '')
    seeds = server.split(',')
    registeredSource = [r for r in (api('get', 'protectionSources/registrationInfo?environments=kMongoDB'))['rootNodes'] if r['rootNode']['name'].lower() == seeds[0].lower()]
    if registeredSource is not None and len(registeredSource) > 0:
        print('%s is already registered' % server)
    else:
        newSource = {
            "environment": "kMongoDB",
            "mongodbParams": {
                "hosts": seeds,
                "authType": authtype.upper(),
                "username": authusername,
                "password": authpassword,
                "authenticatingDatabase": authdatabase,
                "principal": krbprincipal,
                "isSslRequired": False,
                "useSecondaryForBackup": False,
                "secondaryNodeTag": secondarytag
            }
        }
        if usessl:
            newSource['mongodbParams']['isSslRequired'] = True
        if usesecondary:
            newSource['mongodbParams']['useSecondaryForBackup'] = True

        result = api('post', 'data-protect/sources/registrations', newSource, v=2)
        if 'id' in result:
            print('Registering %s' % server)
