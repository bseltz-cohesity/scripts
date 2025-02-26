#!/usr/bin/env python
"""Create a Cohesity S3 View Using python"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--viewname', type=str, required=True)  # name view to create
parser.add_argument('-s', '--storagedomain', type=str, default='DefaultStorageDomain')  # name of storage domain to use
parser.add_argument('-q', '--qospolicy', type=str, choices=['Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low'], default='TestAndDev High')  # qos policy
parser.add_argument('-a', '--allowlist', action='append', default=[])  # ip to allowlist
parser.add_argument('-su', '--s3user', action='append', default=[])
parser.add_argument('-sp', '--permissions', action='append', choices=['Read', 'Write', 'FullControl', 'ReadACP', 'WriteACP'], default=[])

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
viewName = args.viewname
storageDomain = args.storagedomain
qosPolicy = args.qospolicy
allowlist = args.allowlist
userlist = args.s3user
permissions = args.permissions

# authentication =========================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

# find storage domain
sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storageDomain.lower()]

if len(sd) != 1:
    print("Storage domain %s not found!" % storageDomain)
    exit()

sdid = sd[0]['id']

# new view parameters
newView = {
    "name": viewName,
    "category": "ObjectServices",
    "dataLockExpiryUsecs": None,
    "storageDomainId": sdid,
    "protocolAccess": [
        {
            "type": "S3",
            "mode": "ReadWrite"
        }
    ],
    "objectServicesMappingConfig": "ObjectId",
    "mostSecureSettings": False,
    "isExternallyTriggeredBackupTarget": False,
    "intent": {
        "templateId": 2077,
        "templateName": "General Object Services"
    },
    "aclConfig": {
        "grants": [
            {
                "grantee": {
                    "type": "RegisteredUser",
                    "userId": "ADMIN@LOCAL@"
                },
                "permissions": [
                    "FullControl"
                ]
            }
        ]
    },
    "caseInsensitiveNamesEnabled": False,
    "description": None,
    "enableFilerAuditLogging": None,
    "fileExtensionFilter": {
        "fileExtensionsList": [],
        "isEnabled": False,
        "mode": "Blacklist"
    },
    "fileLockConfig": None,
    "filerLifecycleManagement": None,
    "logicalQuota": {
        "hardLimitBytes": None,
        "alertLimitBytes": None
    },
    "ownerInfo": {
        "userId": "ADMIN@LOCAL@"
    },
    "s3FolderSupportEnabled": False,
    "selfServiceSnapshotConfig": None,
    "storagePolicyOverride": {
        "disableInlineDedupAndCompression": False
    },
    "enableAppAwarePrefetching": None,
    "enableAppAwareUptiering": None,
    "qos": {
        "principalName": qosPolicy
    },
    "viewPinningConfig": {
        "enabled": False,
        "pinnedTimeSecs": -1,
        "lastUpdatedTimestampSecs": None
    },
    "netgroupWhitelist": {
        "nisNetgroups": None
    },
    "nfsAllSquash": None,
    "nfsRootSquash": None,
    "overrideGlobalNetgroupWhitelist": None,
    "overrideGlobalSubnetWhitelist": True,
    "securityMode": "NativeMode",
    "subnetWhitelist": None,
    "enableFastDurableHandle": None,
    "enableOfflineCaching": None,
    "enableSmbAccessBasedEnumeration": None,
    "enableSmbEncryption": None,
    "enableSmbLeases": None,
    "enableSmbOplock": None,
    "enableSmbViewDiscovery": None,
    "enforceSmbEncryption": None,
    "sharePermissions": None,
    "smbPermissionsInfo": None,
    "enableNfsKerberosAuthentication": None,
    "enableNfsKerberosIntegrity": None,
    "enableNfsKerberosPrivacy": None,
    "enableNfsUnixAuthentication": None,
    "enableNfsViewDiscovery": None,
    "enableNfsWcc": None,
    "nfsRootPermissions": None,
    "enableAbac": None,
    "lifecycleManagement": None,
    "versioning": None
}

# acl
if len(userlist) > 0:
    users = api('get','users', v=2)
    if len(permissions) == 0:
        permissions = ['FullControl']
    for user in userlist:
        thisuser = [u for u in users['users'] if u['s3AccountParams']['s3AccountId'].lower() == user.lower()]
        if thisuser is not None and len(thisuser) > 0:
            thisuser = thisuser[0]
            newView['aclConfig']['grants'].append({
                "grantee": {
                    "type": "RegisteredUser",
                    "userId": thisuser['s3AccountParams']['s3AccountId']
                },
                "permissions": permissions
            })
        else:
            print('S3 user %s not found' % user)
            exit(1)

# subnet allow list
if len(allowlist) > 0:
    newView['subnetWhitelist'] = []
    for ip in allowlist:
        if ',' in ip:
            (thisip, description) = ip.split(',')
            description = description.lstrip()
        else:
            thisip = ip
            description = ''
        if '/' in thisip:
            (thisip, netmaskBits) = thisip.split('/')
            netmaskBits = int(netmaskBits)
        else:
            netmaskBits = 32
        newView['subnetWhitelist'].append({
            "description": description,
            "ip": thisip,
            "netmaskBits": netmaskBits,
            "nfsAccess": "kReadWrite",
            "nfsSquash": "kNone",
            "smbAccess": "kReadWrite",
            "s3Access": "kReadWrite"
        })

# create the view
print("Creating view %s..." % viewName)
result = api('post', 'file-services/views', newView, v=2)
