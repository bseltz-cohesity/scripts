#!/usr/bin/env python
"""Protect Generic Nas Mountpoints"""

# usage:

# ./registerGenericNas.ps1 -v mycluster \
#                          -u myuser \
#                          -d mydomain.net \
#                          -m \\myserver\myshare \
#                          -s 'mydomain.net\myuser'

# import pyhesity wrapper module
from pyhesity import *
import getpass

### command line arguments
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
parser.add_argument('-e', '--emailmfacode', action='store_true'),
parser.add_argument('-p', '--mountpath', action='append', type=str)  # mount path
parser.add_argument('-l', '--mountlist', type=str)               # mount paths in text file
parser.add_argument('-s', '--smbusername', type=str)                 # smb username
parser.add_argument('-sp', '--smbpassword', type=str)
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
mountpaths = args.mountpath
mountlist = args.mountlist
smbusername = args.smbusername
smbpassword = args.smbpassword

# get smb password
if smbusername is not None and smbpassword is None:
    smbpassword = getpass.getpass("Enter the password for %s: " % smbusername)

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


mountpaths = gatherList(mountpaths, mountlist, name='mount paths', required=True)

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

smbdomain = None
for mountpath in mountpaths:

    # smb credentials
    if '\\' in mountpath:
        protocol = 2  # smb
        if smbusername is None:
            print('smbusername parameter is required for smb mount paths')
            exit(1)
        if '\\' in smbusername:
            (smbdomain, smbusername) = smbusername.split('\\')
        credentials = {
            'username': '',
            'password': '',
            'nasMountCredentials': {
                'protocol': protocol,
                'username': smbusername,
                'password': smbpassword
            }
        }
        if smbdomain is not None:
            credentials['nasMountCredentials']['domainName'] = smbdomain
    else:
        protocol = 1  # nfs

    # new source parameters
    newSourceParams = {
        'entity': {
            'type': 11,
            'genericNasEntity': {
                'protocol': protocol,
                'type': 1,
                'path': mountpath
            }
        },
        'entityInfo': {
            'endpoint': mountpath,
            'type': 11
        },
        'registeredEntityParams': {
            'genericNasParams': {
                'skipValidation': True
            }
        }
    }

    # add smb credentials
    if protocol == 2:
        newSourceParams['entityInfo']['credentials'] = credentials

    # register new source
    if mountpath != '':
        print("Registering %s" % mountpath)
        result = api('post', '/backupsources', newSourceParams)
