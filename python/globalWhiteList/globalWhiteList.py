#!/usr/bin/env python
"""List Exported Views using Python"""

# usage: ./exportedViews.py -v mycluster -u myusername -d mydomain.net

### import Cohesity python module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-z', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-c', '--cidr', type=str, default=None)
parser.add_argument('-a', '--addentry', action='store_true')
parser.add_argument('-r', '--removeentry', action='store_true')
parser.add_argument('-x', '--squash', type=str, choices=['all', 'root', 'none'], default='none')
parser.add_argument('-n', '--nfsaccess', type=str, choices=['readwrite', 'readonly', 'none'], default='readwrite')
parser.add_argument('-s', '--smbaccess', type=str, choices=['readwrite', 'readonly', 'none'], default='readwrite')
parser.add_argument('-i', '--description', type=str, default='')

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
cidr = args.cidr
addentry = args.addentry
removeentry = args.removeentry
squash = args.squash
nfsaccess = args.nfsaccess
smbaccess = args.smbaccess
description = args.description

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

accessString = {'kReadOnly': 'Read Only ', 'kReadWrite': 'Read/Write', 'kDisabled': 'Disabled  '}
accessEnum = {'readonly': 'kReadOnly', 'readwrite': 'kReadWrite', 'none': 'kDisabled'}

### get global whitelist
globalWhitelist = api('get', 'externalClientSubnets')

if removeentry is True and 'clientSubnets' in globalWhitelist:
    if '/' not in cidr:
        ip = cidr
        netmaskBits = '32'
    else:
        (ip, netmaskBits) = cidr.split('/')
    globalWhitelist['clientSubnets'] = [e for e in globalWhitelist['clientSubnets'] if e['ip'] != ip or ('netmaskBits' in e and str(e['netmaskBits']) != netmaskBits)]
    globaLWhitelist = api('put', 'externalClientSubnets', globalWhitelist)
elif addentry is True:
    if '/' not in cidr:
        ip = cidr
        netmaskBits = '32'
    else:
        (ip, netmaskBits) = cidr.split('/')
    if 'clientSubnets' not in globalWhitelist:
        globalWhitelist['clientSubnets'] = []
    globalWhitelist['clientSubnets'] = [e for e in globalWhitelist['clientSubnets'] if e['ip'] != ip or ('netmaskBits' in e and str(e['netmaskBits']) != netmaskBits)]
    newEntry = {
        'ip': ip,
        'desciption': description,
        'nfsAccess': accessEnum[nfsaccess],
        'smbAccess': accessEnum[smbaccess],
        'description': description
    }
    if ip != '0.0.0.0':
        newEntry['netmaskBits'] = int(netmaskBits)
    else:
        newEntry['netmaskIp4'] = '0.0.0.0'
    if squash == 'all':
        newEntry['nfsAllSquash'] = True
    elif squash == 'root':
        newEntry['nfsRootSquash'] = True
    globalWhitelist['clientSubnets'].append(newEntry)
    globalWhitelist = api('put', 'externalClientSubnets', globalWhitelist)

# display whitelist
if 'clientSubnets' in globalWhitelist:
    for entry in globalWhitelist['clientSubnets']:
        squashString = 'None'
        descriptionString = ''
        ip = entry.get('ip')
        netmaskBits = entry.get('netmaskBits', '0.0.0.0')
        description = entry.get('description', '')
        nfsAccess = entry.get('nfsAccess')
        nfsAccessString = accessString[nfsAccess]
        smbAccess = entry.get('smbAccess')
        smbAccessString = accessString[smbAccess]
        nfsAllSquash = entry.get('nfsAllSquash', False)
        nfsRootSquash = entry.get('nfsRootSquash', False)
        if nfsAllSquash is True:
            squashString = 'All '
        elif nfsRootSquash is True:
            squashString = 'Root'
        if description != '':
            descriptionString = 'Description: %s' % description
        cidr = '%s/%s' % (ip, netmaskBits)
        print('%-18s SMB: %s   NFS: %s   Squash: %s   %s' % (cidr, smbAccessString, nfsAccessString, squashString, descriptionString))
