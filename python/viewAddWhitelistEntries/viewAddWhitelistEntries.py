#!/usr/bin/env python
"""Add subnet whitelist entries to one or more Cohesity views using python"""

# import pyhesity wrapper module
from pyhesity import *
import os

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
parser.add_argument('-n', '--viewname', action='append', default=[])  # name(s) of views to modify (comma separated, or repeat -n)
parser.add_argument('-vl', '--viewlist', type=str, default=None)  # optional textfile of views to modify
parser.add_argument('-i', '--ip', action='append', default=[])  # cidr(s) to add to whitelist (comma separated, or repeat -i)
parser.add_argument('-il', '--iplist', type=str, default=None)  # optional textfile of cidrs to add
parser.add_argument('-rs', '--rootsquash', action='store_true')  # whitelist entries use root squash
parser.add_argument('-as', '--allsquash', action='store_true')  # whitelist entries use all squash
parser.add_argument('-ro', '--readonly', action='store_true')  # grant only read access

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
viewnames = args.viewname
viewlist = args.viewlist
ips = args.ip
iplist = args.iplist
rootsquash = args.rootsquash
allsquash = args.allsquash
readonly = args.readonly


# gather list from command line params and/or file
def gatherList(param=None, filepath=None, name='items', required=True):
    items = []
    if param:
        for p in param:
            items.extend([i.strip() for i in str(p).split(',') if i.strip() != ''])
    if filepath:
        if os.path.isfile(filepath):
            with open(filepath, 'r') as f:
                items.extend([line.strip() for line in f.readlines() if line.strip() != ''])
        else:
            print('Text file %s not found!' % filepath)
            exit(1)
    if required is True and len(items) == 0:
        print('No %s specified' % name)
        exit(1)
    return sorted(set(items))


ipsToAdd = gatherList(param=ips, filepath=iplist, name='IPs', required=True)
viewsToModify = gatherList(param=viewnames, filepath=viewlist, name='views', required=True)

perm = 'kReadWrite'
if readonly:
    perm = 'kReadOnly'


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


def newWhiteListEntry(cidr, perm):
    parts = cidr.split('/')
    ip = parts[0]
    netbits = parts[1] if len(parts) > 1 else '32'

    whitelistEntry = {
        'nfsAccess': perm,
        'smbAccess': perm,
        's3Access': perm,
        'ip': ip,
        'netmaskBits': int(netbits),
        'description': ''
    }
    if allsquash:
        whitelistEntry['nfsAllSquash'] = True
    if rootsquash:
        whitelistEntry['nfsRootSquash'] = True
    return whitelistEntry


views = api('get', 'file-services/views', v=2)['views']

for viewName in viewsToModify:
    matchingViews = [v for v in views if v['name'].lower() == viewName.lower()]
    if len(matchingViews) == 0:
        print('View %s not found' % viewName)
    else:
        view = matchingViews[0]
        print(view['name'])

        if 'subnetWhitelist' not in view:
            view['subnetWhitelist'] = []

        for cidr in ipsToAdd:
            print('    %s' % cidr)
            ip = cidr.split('/')[0]
            view['subnetWhitelist'] = [e for e in view['subnetWhitelist'] if e['ip'] != ip]
            view['subnetWhitelist'].append(newWhiteListEntry(cidr, perm))

        view['subnetWhitelist'] = [e for e in view['subnetWhitelist'] if e is not None]
        result = api('put', 'file-services/views/%s' % view['viewId'], view, v=2)

