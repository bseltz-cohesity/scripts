#!/usr/bin/env python
"""Create a Cohesity NFS View Using python"""

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
parser.add_argument('-q', '--qospolicy', type=str, choices=['Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low'], default='TestAndDev High')  # qos policy
parser.add_argument('-w', '--whitelist', action='append', default=[])  # ip to whitelist
parser.add_argument('-l', '--quotalimit', type=int, default=None)  # quota limit
parser.add_argument('-a', '--quotaalert', type=int, default=None)  # quota alert threshold
parser.add_argument('-c', '--clearwhitelist', action='store_true')
parser.add_argument('-r', '--removewhitelistentries', action='store_true')
parser.add_argument('-x', '--updateexistingview', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
viewName = args.viewname
storageDomain = args.storagedomain
qosPolicy = args.qospolicy
whitelist = args.whitelist
quotalimit = args.quotalimit
quotaalert = args.quotaalert
removewhitelistentries = args.removewhitelistentries
clearwhitelist = args.clearwhitelist
updateexistingview = args.updateexistingview


# netmask2cidr
def netmask2cidr(netmask):
    bin = ''.join(["{0:b}".format(int(o)) for o in netmask.split('.')])
    if '0' in bin:
        cidr = bin.index('0')
    else:
        cidr = 32
    return cidr


# authenticate
apiauth(vip, username, domain)

existingview = None
views = api('get', 'views')
if views['count'] > 0:
    existingviews = [v for v in views['views'] if v['name'].lower() == viewName.lower()]
    if(len(existingviews) > 0):
        existingview = existingviews[0]

if existingview is not None and updateexistingview is not True:
    print('view %s already exists' % viewName)
    exit(0)

if existingview is None:
    # find storage domain
    sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storageDomain.lower()]

    if len(sd) != 1:
        print("Storage domain %s not found!" % storageDomain)
        exit()

    sdid = sd[0]['id']

    # new view parameters
    newView = {
        "caseInsensitiveNamesEnabled": True,
        "enableNfsViewDiscovery": True,
        "enableSmbAccessBasedEnumeration": False,
        "enableSmbViewDiscovery": True,
        "fileExtensionFilter": {
            "isEnabled": False,
            "mode": "kBlacklist",
            "fileExtensionsList": []
        },
        "protocolAccess": "kNFSOnly",
        "securityMode": "kNativeMode",
        "subnetWhitelist": [],
        "qos": {
            "principalName": qosPolicy
        },
        "name": viewName,
        "viewBoxId": sdid
    }

else:
    newView = existingview

if clearwhitelist is True:
    newView['subnetWhitelist'] = []

if len(whitelist) > 0:

    for ip in whitelist:
        if ',' in ip:
            (thisip, netmask) = ip.split(',')
            netmask = netmask.lstrip()
            cidr = netmask2cidr(netmask)
        else:
            thisip = ip
            netmask = '255.255.255.255'
            cidr = 32

        existingEntry = []
        if 'subnetWhitelist' in newView:
            existingEntry = [e for e in newView['subnetWhitelist'] if e['ip'] == thisip and e['netmaskBits'] == cidr]

        if removewhitelistentries is not True and len(existingEntry) == 0:
            newView['subnetWhitelist'].append({
                "description": '',
                "nfsAccess": "kReadWrite",
                "smbAccess": "kReadWrite",
                "nfsRootSquash": False,
                "ip": thisip,
                "netmaskIp4": netmask
            })
        else:
            if removewhitelistentries is True:
                newView['subnetWhitelist'] = [e for e in newView['subnetWhitelist'] if not (e['ip'] == thisip and e['netmaskBits'] == cidr)]

# apply quota
if quotalimit is not None:
    if quotaalert is None:
        quotaalert = quotalimit - (quotalimit / 10)
    quotalimit = quotalimit * (1024 * 1024 * 1024)
    quotaalert = quotaalert * (1024 * 1024 * 1024)
    newView['logicalQuota'] = {
        "hardLimitBytes": quotalimit,
        "alertLimitBytes": quotaalert
    }

# update qos policy
newView['qos']['principalName'] = qosPolicy

# create the view
if existingview is None:
    print("Creating view %s..." % viewName)
    result = api('post', 'views', newView)
else:
    print("Updating view %s..." % viewName)
    result = api('put', 'views', newView)
