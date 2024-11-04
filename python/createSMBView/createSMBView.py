#!/usr/bin/env python
"""Create a Cohesity SMB View Using python"""

# usage: ./createSMBView.py -v mycluster \
#                           -u myusername \
#                           -d mydomain.net \
#                           -n newview1 \
#                           -w mydomain.net\server1 \
#                           -f mydomain.net\admingroup1
#                           -f mydomain.net\admingroup2 \
#                           -r mydomain.net\auditors \
#                           -q 'TestAndDev High' \
#                           -s mystoragedomain \
#                           -a 192.168.1.97

# import pyhesity wrapper module
from pyhesity import *

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
parser.add_argument('-n', '--viewname', type=str, required=True)  # name view to create
parser.add_argument('-s', '--storagedomain', type=str, default='DefaultStorageDomain')  # name of storage domain to use
parser.add_argument('-f', '--fullcontrol', action='append', default=[])  # user/group to grant fullControl
parser.add_argument('-w', '--readwrite', action='append', default=[])  # user/group to grant readWrite
parser.add_argument('-r', '--readonly', action='append', default=[])  # user/group to grant readOnly
parser.add_argument('-q', '--qospolicy', type=str, choices=['Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low'], default='TestAndDev High')  # qos policy
parser.add_argument('-a', '--allowlist', action='append', default=[])  # ip to add to allowlist

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
viewName = args.viewname
storageDomain = args.storagedomain
fullControl = args.fullcontrol
readWrite = args.readwrite
reeadOnly = args.readonly
qosPolicy = args.qospolicy
allowlist = args.allowlist

# authenticate
apiauth(vip, username, domain)

# find storage domain
sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storageDomain.lower()]

if len(sd) != 1:
    print("Storage domain %s not found!" % storageDomain)
    exit()

sdid = sd[0]['id']

# new view parameters
newView = {
    "enableSmbAccessBasedEnumeration": True,
    "enableSmbViewDiscovery": True,
    "fileDataLock": {
        "lockingProtocol": "kSetReadOnly"
    },
    "fileExtensionFilter": {
        "isEnabled": False,
        "mode": "kBlacklist",
        "fileExtensionsList": []
    },
    "securityMode": "kNativeMode",
    "smbPermissionsInfo": {
        "ownerSid": "S-1-5-32-544",
        "permissions": []
    },
    "protocolAccess": "kSMBOnly",
    "subnetWhitelist": [],
    "qos": {
        "principalName": qosPolicy
    },
    "viewBoxId": sdid,
    "caseInsensitiveNamesEnabled": True,
    "storagePolicyOverride": {
        "disableInlineDedupAndCompression": False
    },
    "name": viewName,
    "sharePermissions": [
        {
            "sid": "S-1-1-0",
            "access": "kFullControl",
            "mode": "kFolderSubFoldersAndFiles",
            "type": "kAllow"
        }
    ],
}


# function to add permissions
def addPermission(user, perms):
    (domain, domainuser) = user.split('\\')
    principal = [principal for principal in api('get', 'activeDirectory/principals?domain=%s&includeComputers=true&search=%s' % (domain, domainuser)) if principal['fullName'].lower() == domainuser.lower()]
    if len(principal) == 1:
        permission = {
            "sid": principal[0]['sid'],
            "type": "kAllow",
            "mode": "kFolderSubFoldersAndFiles",
            "access": perms
        }
        newView['smbPermissionsInfo']['permissions'].append(permission)
    else:
        print("User %s not found" % user)
        exit(1)


for user in reeadOnly:
    addPermission(user, 'kReadOnly')

for user in readWrite:
    addPermission(user, 'kReadWrite')

for user in fullControl:
    addPermission(user, 'kFullControl')

if len(newView['smbPermissionsInfo']['permissions']) == 0:
    newView['smbPermissionsInfo']['permissions'].append({
        "sid": "S-1-1-0",
        "type": "kAllow",
        "mode": "kFolderSubFoldersAndFiles",
        "access": "kFullControl"
    })

if len(allowlist) > 0:
    newView['subnetWhitelist'] = []
    for ip in allowlist:
        if ',' in ip:
            (thisip, description) = ip.split(',')
            description = description.lstrip()
        else:
            thisip = ip
            description = ''
        newView['subnetWhitelist'].append(
            {
                "description": description,
                "nfsAccess": "kReadWrite",
                "smbAccess": "kReadWrite",
                "nfsRootSquash": False,
                "ip": thisip,
                "netmaskIp4": "255.255.255.255"
            }
        )
# create the view
print("Creating view %s..." % viewName)
result = api('post', 'views', newView)
