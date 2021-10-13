#!/usr/bin/env python
"""Register vCenter"""

# import pyhesity wrapper module
from pyhesity import *
import getpass

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-n', '--vcentername', type=str, required=True)       # vcenter name or IP
parser.add_argument('-vu', '--vcenterusername', type=str, required=True)  # vcenter username
parser.add_argument('-vp', '--vcenterpassword', type=str, default=None)   # vcenter password

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
vcentername = args.vcentername
vcenterusername = args.vcenterusername
vcenterpassword = args.vcenterpassword

# get vcenterpassword
if vcenterpassword is None:
    vcenterpassword = getpass.getpass("Enter the password for %s: " % vcenterusername)

# authenticate
apiauth(vip, username, domain)

newVcenter = {
    "entity": {
        "type": 1,
        "vmwareEntity": {
            "type": 0
        }
    },
    "entityInfo": {
        "endpoint": vcentername,
        "type": 1,
        "credentials": {
            "username": vcenterusername,
            "password": vcenterpassword
        }
    },
    "registeredEntityParams": {
        "isSpaceThresholdEnabled": False,
        "spaceUsagePolicy": {},
        "throttlingPolicy": {
            "isThrottlingEnabled": False,
            "isDatastoreStreamsConfigEnabled": False,
            "datastoreStreamsConfig": {}
        },
        "vmwareParams": {}
    }
}

print("Registering %s" % vcentername)
result = api('post', '/backupsources', newVcenter)
