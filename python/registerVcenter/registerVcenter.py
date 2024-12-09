#!/usr/bin/env python
"""Register vCenter"""

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
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-vn', '--vcentername', type=str, required=True)       # vcenter name or IP
parser.add_argument('-vu', '--vcenterusername', type=str, required=True)  # vcenter username
parser.add_argument('-vp', '--vcenterpassword', type=str, default=None)   # vcenter password
parser.add_argument('-nn', '--networkname', action='append', type=str)
parser.add_argument('-nl', '--networklist', type=str, default=None)
parser.add_argument('-nc', '--clearnetworks', action='store_true')
parser.add_argument('-nr', '--removenetworks', action='store_true')
parser.add_argument('-tu', '--trackuuid', action='store_true')
parser.add_argument('-ldp', '--lowdiskpercent', type=int, default=-1)

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
vcentername = args.vcentername
vcenterusername = args.vcenterusername
vcenterpassword = args.vcenterpassword
networkname = args.networkname
networklist = args.networklist
clearnetworks = args.clearnetworks
removenetworks = args.removenetworks
trackuuid = args.trackuuid
lowdiskpercent = args.lowdiskpercent

# gather list function
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
        exit(1)
    return items

# get list of ip/cidr to process
networks = gatherList(networkname, networklist, name='networks', required=False)

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

# get vcenterpassword
if vcenterpassword is None:
    vcenterpassword = getpass.getpass("Enter the password for %s: " % vcenterusername)

sources = api('get', 'protectionSources/registrationInfo?includeEntityPermissionInfo=true&environments=kVMware')
if 'rootNodes' in sources and sources['rootNodes'] is not None:
    sources = [source for source in sources['rootNodes'] if source['rootNode']['name'].lower() == vcentername.lower()]
else:
    sources = []

existingVcenter = False
if len(sources) == 0:
    vCenterParams = {
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
else:
    existingVcenter = True
    sourceid = sources[0]['rootNode']['id']
    thissource = api('get', '/backupsources?allUnderHierarchy=true&entityId=%s&onlyReturnOneLevel=true' % sourceid)
    vCenterParams = {
        "entity": thissource['entityHierarchy']['entity'],
        "entityInfo": thissource['entityHierarchy']['registeredEntityInfo']['connectorParams'],
        "registeredEntityParams": thissource['entityHierarchy']['registeredEntityInfo']['registeredEntityParams']
    }
    vCenterParams['entityInfo']['credentials']['username'] = vcenterusername
    vCenterParams['entityInfo']['credentials']['password'] = vcenterpassword

if 'vmwareParams' not in vCenterParams['registeredEntityParams']:
    vCenterParams['registeredEntityParams']['vmwareParams'] = {}

# preferred subnets
if clearnetworks is True and 'preferredSubnetVec' in vCenterParams['registeredEntityParams']['vmwareParams']:
    vCenterParams['registeredEntityParams']['vmwareParams']['preferredSubnetVec'] = []

if len(networks) > 0:
    if 'preferredSubnetVec' not in vCenterParams['registeredEntityParams']['vmwareParams']:
        vCenterParams['registeredEntityParams']['vmwareParams']['preferredSubnetVec'] = []
    for network in networks:
        if '/' not in network:
            print('Invalid CIDR %s should be in the form x.x.x.x/y')
            exit(1)
        else:
            (net, mask) = network.split('/')
            vCenterParams['registeredEntityParams']['vmwareParams']['preferredSubnetVec'] = [n for n in vCenterParams['registeredEntityParams']['vmwareParams']['preferredSubnetVec'] if n['ip'] != net and n['netmaskBits'] != mask]
            if removenetworks is not True:
                vCenterParams['registeredEntityParams']['vmwareParams']['preferredSubnetVec'].append({
                    "ip": net,
                    "netmaskBits": int(mask)
                })

if trackuuid is True:
    if existingVcenter is False:
        vCenterParams['registeredEntityParams']['vmwareParams']['useVmBiosUuid'] = True
    else:
        print('track by uuid can not be changed after initial registration'
)

if lowdiskpercent == 0:
        vCenterParams['registeredEntityParams']['isSpaceThresholdEnabled'] = False
        del vCenterParams['registeredEntityParams']['spaceUsagePolicy']
if lowdiskpercent > 0:
    vCenterParams['registeredEntityParams']['isSpaceThresholdEnabled'] = True
    vCenterParams['registeredEntityParams']['spaceUsagePolicy'] = {
        "minFreeDatastoreSpaceForBackupGb": None,
        "minFreeDatastoreSpaceForBackupPercentage": lowdiskpercent
    }

print("Registering %s" % vcentername)
if existingVcenter is False:
    result = api('post', '/backupsources', vCenterParams)
else:
    result = api('put', '/backupsources/%s' % sourceid, vCenterParams)
