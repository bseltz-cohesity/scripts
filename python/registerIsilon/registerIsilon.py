#!/usr/bin/env python

from pyhesity import *
import getpass
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # admin user to do the work
parser.add_argument('-d', '--domain', type=str, default='local')      # domain of admin user
parser.add_argument('-n', '--name', type=str, required=True)          # name of isilon to register
parser.add_argument('-au', '--apiuser', type=str, required=True)  # api username
parser.add_argument('-ap', '--apipassword', type=str, default=None)   # api password
parser.add_argument('-su', '--smbuser', type=str, default=None)  # smb username
parser.add_argument('-sp', '--smbpassword', type=str, default=None)   # smb password
parser.add_argument('-b', '--blacklistip', action='append', type=str)  # ip to blacklist
parser.add_argument('-l', '--blacklist', type=str, default=None)     # text list of ips to blacklist

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
name = args.name
apiuser = args.apiuser
apipassword = args.apipassword
smbuser = args.smbuser
smbpassword = args.smbpassword
blacklistips = args.blacklistip
blacklist = args.blacklist

# read server file
if blacklistips is None:
    blacklistips = []
if blacklist is not None:
    f = open(blacklist, 'r')
    blacklistips += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

if smbuser is not None:
    if '\\' not in smbuser:
        print('smb user must be in the format MYDOMAIN.NET\\MYUSER')
        exit(1)

if apipassword is None:
    apipassword = getpass.getpass("Enter the password for API user %s: " % apiuser)

if smbuser is not None:
    (smbdomain, smbusername) = smbuser.split('\\')
    if smbpassword is None:
        smbpassword = getpass.getpass("Enter the password for SMB user %s: " % smbuser)

# authenticate
apiauth(vip, username, domain)

newSourceParams = {
    "entity": {
        "type": 14,
        "isilonEntity": {
            "type": 0
        }
    },
    "entityInfo": {
        "endpoint": name,
        "credentials": {
            "username": apiuser,
            "password": apipassword
        },
        "type": 14
    },
    "registeredEntityParams": {}
}

if smbuser is not None:
    newSourceParams["entityInfo"]["credentials"]["nasMountCredentials"] = {
        "protocol": 2,
        "username": smbusername,
        "password": smbpassword,
        "domainName": smbdomain
    }

if len(blacklistips) > 0:
    newSourceParams["registeredEntityParams"]["blacklistedIpAddrs"] = blacklistips

result = api('post', '/backupsources', newSourceParams)
if result is not None:
    print("%s Registered" % name)
