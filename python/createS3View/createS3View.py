#!/usr/bin/env python
"""Create a Cohesity S3 View Using python"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-n', '--viewname', type=str, required=True)  # name view to create
parser.add_argument('-s', '--storagedomain', type=str, default='DefaultStorageDomain')  # name of storage domain to use
parser.add_argument('-q', '--qospolicy', type=str, choices=['Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low'], default='Backup Target Low')  # qos policy
parser.add_argument('-i', '--whitelist', action='append', default=[])  # ip to whitelist

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
viewName = args.viewname
storageDomain = args.storagedomain
qosPolicy = args.qospolicy
whitelist = args.whitelist

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
    "protocolAccess": "kS3Only",
    "subnetWhitelist": [],
    "qos": {
        "principalName": qosPolicy
    },
    "viewBoxId": sdid,
    "caseInsensitiveNamesEnabled": True,
    "storagePolicyOverride": {
        "disableInlineDedupAndCompression": False
    },
    "name": viewName
}

if len(whitelist) > 0:
    newView['subnetWhitelist'] = []
    for ip in whitelist:
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
