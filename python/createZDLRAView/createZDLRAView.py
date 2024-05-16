#!/usr/bin/env python
"""Create a Cohesity NFS View Using python"""

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
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--viewname', type=str, required=True)  # name view to create
parser.add_argument('-s', '--storagedomain', type=str, default='DefaultStorageDomain')  # name of storage domain to use
parser.add_argument('-q', '--qospolicy', type=str, choices=['Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low', None], default=None)  # qos policy
parser.add_argument('-w', '--whitelist', action='append', default=[])  # ip to whitelist
parser.add_argument('-l', '--quotalimit', type=int, default=None)  # quota limit
parser.add_argument('-a', '--quotaalert', type=int, default=None)  # quota alert threshold
parser.add_argument('-cw', '--clearwhitelist', action='store_true')  # erase existing whitelist
parser.add_argument('-r', '--removewhitelistentries', action='store_true')  # remove whitelist entries specified with -w
parser.add_argument('-x', '--updateexistingview', action='store_true')  # allow update of existing view (otherwise exit if view exists)
parser.add_argument('-lm', '--lockmode', type=str, choices=['Compliance', 'Enterprise', 'None', 'compliance', 'enterprise', 'none'], default='None')  # datalock mode
parser.add_argument('-dl', '--defaultlockperiod', type=int, default=1)  # default lock period
parser.add_argument('-al', '--autolockminutes', type=int, default=0)  # autolock after idle minutes
parser.add_argument('-ml', '--minimumlockperiod', type=int, default=0)  # minimum manual lock period
parser.add_argument('-xl', '--maximumlockperiod', type=int, default=1)  # maximum manual lock period
parser.add_argument('-lt', '--manuallockmode', type=str, choices=['ReadOnly', 'FutureATime', 'readonly', 'futureatim'], default='ReadOnly')  # manual locking type
parser.add_argument('-lu', '--lockunit', type=str, choices=['minute', 'hour', 'day', 'minutes', 'hours', 'days'], default='minute')  # lock period units
parser.add_argument('-show', '--show', action='store_true')
parser.add_argument('-i', '--caseinsensitive', action='store_true')

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
qosPolicy = args.qospolicy
whitelist = args.whitelist
quotalimit = args.quotalimit
quotaalert = args.quotaalert
removewhitelistentries = args.removewhitelistentries
clearwhitelist = args.clearwhitelist
updateexistingview = args.updateexistingview
lockmode = args.lockmode
defaultlockperiod = args.defaultlockperiod
autolockminutes = args.autolockminutes
minimumlockperiod = args.minimumlockperiod
maximumlockperiod = args.maximumlockperiod
manuallockmode = args.manuallockmode
lockunit = args.lockunit
show = args.show
caseinsensitive = args.caseinsensitive

lockunitmap = {'minute': 60000, 'minutes': 60000, 'hour': 3600000, 'hours': 3600000, 'day': 86400000, 'days': 86400000}
lockunitmultiplier = lockunitmap[lockunit]


# netmask2cidr
def netmask2cidr(netmask):
    bin = ''.join(["{0:b}".format(int(o)) for o in netmask.split('.')])
    if '0' in bin:
        cidr = bin.index('0')
    else:
        cidr = 32
    return cidr


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

existingview = None
views = api('get', 'file-services/views', v=2)
if views['count'] > 0:
    existingviews = [v for v in views['views'] if v['name'].lower() == viewName.lower()]
    if len(existingviews) > 0:
        existingview = existingviews[0]

if existingview is not None and updateexistingview is not True and show is not True:
    print('view %s already exists' % viewName)
    exit(0)

if existingview is None:
    if show:
        print('view %s not found' % viewName)
        exit(0)

    # default qos policy
    if qosPolicy is None:
        qosPolicy = 'Backup Target High'

    qp = [qp for qp in api('get', 'qosPolicies') if qp['name'].lower() == qosPolicy.lower()]

    if len(qp) != 1:
        print("QOS policy %s not found!" % qosPolicy)
        exit()

    # find storage domain
    sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storageDomain.lower()]

    if len(sd) != 1:
        print("Storage domain %s not found!" % storageDomain)
        exit()

    sdid = sd[0]['id']

    newView = {
        "caseInsensitiveNamesEnabled": False,
        "category": "BackupTarget",
        "enableNfsViewDiscovery": False,
        "fileExtensionFilter": {
            "isEnabled": False,
            "mode": "Blacklist",
            "fileExtensionsList": []
        },
        "isExternallyTriggeredBackupTarget": True,
        "name": viewName,
        "overrideGlobalNetgroupWhitelist": True,
        "overrideGlobalSubnetWhitelist": True,
        "protocolAccess": [
            {
                "type": "NFS4",
                "mode": "ReadWrite",
                "hidden": False
            }
        ],
        "qos": {
            "principalId": qp[0]['id'],
            "principalName": qp[0]['name']
        },
        "s3FolderSupportEnabled": False,
        "securityMode": "NativeMode",
        "selfServiceSnapshotConfig": {
            "enabled": False,
            "nfsAccessEnabled": True,
            "snapshotDirectoryName": ".snapshot",
            "smbAccessEnabled": True,
            "alternateSnapshotDirectoryName": "~snapshot",
            "previousVersionsEnabled": True,
            "allowAccessSids": [
                "S-1-1-0"
            ],
            "denyAccessSids": []
        },
        "storageDomainId": sd[0]['id'],
        "storageDomainName": sd[0]['name'],
        "intent": {
            "templateId": 1041,
            "templateName": "ZDLRA"
        }
    }

    if caseinsensitive is True:
        newView['caseInsensitiveNamesEnabled'] = True

else:
    newView = existingview
    if show:
        display(newView)
        exit(0)
    if qosPolicy is not None:
        qp = [qp for qp in api('get', 'qosPolicies') if qp['name'].lower() == qosPolicy.lower()]

        if len(qp) != 1:
            print("QOS policy %s not found!" % storageDomain)
            exit()

        newView['qos'] = {
            "principalId": qp[0]['id'],
            "principalName": qp[0]['name']
        }

if clearwhitelist is True:
    newView['subnetWhitelist'] = []

if len(whitelist) > 0:
    if 'subnetWhitelist' not in newView:
        newView['subnetWhitelist'] = []

    for ip in whitelist:
        description = ''
        if ',' in ip:
            parts = ip.split(',')
            if len(parts) >= 3:
                description = parts[2]
            if len(parts) >= 2:
                netmask = parts[1]
                netmask = netmask.lstrip()
                cidr = netmask2cidr(netmask)
            thisip = parts[0]
        else:
            thisip = ip
            netmask = '255.255.255.255'
            cidr = 32

        existingEntry = []
        if 'subnetWhitelist' in newView:
            existingEntry = [e for e in newView['subnetWhitelist'] if e['ip'] == thisip and e['netmaskBits'] == cidr]

        if removewhitelistentries is not True and len(existingEntry) == 0:
            newView['subnetWhitelist'].append({
                "description": description,
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

# apply datalock
if lockmode.lower() != 'none':
    newView['fileLockConfig'] = {}
    if lockmode.lower() == 'enterprise':
        newView['fileLockConfig']['mode'] = "kEnterprise"
    if lockmode.lower() == 'compliance':
        newView['fileLockConfig']['mode'] = "kCompliance"
    if autolockminutes > 0:
        newView['fileLockConfig']['autoLockAfterDurationIdle'] = autolockminutes * 60000
    newView['fileLockConfig']['defaultFileRetentionDurationMsecs'] = defaultlockperiod * lockunitmultiplier
    if maximumlockperiod < defaultlockperiod:
        maximumlockperiod = defaultlockperiod
    if maximumlockperiod <= minimumlockperiod or defaultlockperiod <= minimumlockperiod:
        print("default and maximum lock periods must be greater than the minimum lock period")
        exit()
    minimumlockmsecs = minimumlockperiod * lockunitmultiplier
    if minimumlockmsecs == 0:
        minimumlockmsecs = 60000
    newView['fileLockConfig']['minRetentionDurationMsecs'] = minimumlockmsecs
    maximumlockmsecs = maximumlockperiod * lockunitmultiplier
    if maximumlockmsecs <= (minimumlockmsecs + 240000):
        maximumlockmsecs = minimumlockmsecs + 240000
    newView['fileLockConfig']['maxRetentionDurationMsecs'] = maximumlockmsecs
    if manuallockmode.lower() == 'readonly':
        newView['fileLockConfig']['lockingProtocol'] = 'kSetReadOnly'
    else:
        newView['fileLockConfig']['lockingProtocol'] = 'kSetAtime'
    newView['fileLockConfig']['expiryTimestampMsecs'] = 0

# create the view
if existingview is None:
    print("Creating view %s..." % viewName)
    result = api('post', 'file-services/views', newView, v=2)
else:
    print("Updating view %s..." % viewName)
    result = api('put', 'file-services/views', newView, v=2)
