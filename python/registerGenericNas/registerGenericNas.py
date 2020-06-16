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
parser.add_argument('-v', '--vip', type=str, required=True)       # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-m', '--mountpath', action='append', type=str)  # mount path
parser.add_argument('-f', '--mountpathfile', type=str)               # mount paths in text file
parser.add_argument('-s', '--smbusername', type=str)                 # smb username

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
mountpaths = args.mountpath
mountpathfile = args.mountpathfile
smbusername = args.smbusername

# get smb password
smbpwd = None
if smbusername is not None:
    smbpwd = getpass.getpass("Enter the password for %s: " % smbusername)

# gather mountpaths
if mountpaths is None:
    mountpaths = []
if mountpathfile is not None:
    f = open(mountpathfile, 'r')
    mountpaths += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()
if len(mountpaths) == 0:
    print('No mount paths specified!')
    exit(1)

# authenticate
apiauth(vip, username, domain)

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
                'password': smbpwd
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
