#!/usr/bin/env python
"""Ping Cluster Nodes"""

### import pyhesity wrapper module
from pyhesity import *
import codecs

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

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant, quiet=True)

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

# outfile
cluster = api('get', 'cluster')
outfile = '%s-IPAddresses.csv' % (cluster['name'])
f = codecs.open(outfile, 'w')

# headings
f.write('"Address Class","IP Address"\n')

nodes = api('get', 'nodes')
ipmi = api('get', '/nexus/ipmi/cluster_get_lan_info', quiet=True)
nodeIds = [n['id'] for n in nodes]

addresses = []

interfaces = api('get', 'interface')

for nodeId in nodeIds:
    node = [n for n in nodes if n['id'] == nodeId][0]
    nodeIp = node['ip'].split(':')[-1]
    # print('Node: %s' % nodeIp)
    # addresses.append('"%s","%s"\n' % ('NODE', nodeIp))
    ipmiIp = None
    if ipmi is not None and 'nodesIpmiInfo' in ipmi:
        nodeipmi = [i for i in ipmi['nodesIpmiInfo'] if i['nodeIp'] == node['ip'].split(':')[-1]]
        if len(nodeipmi) > 0:
            ipmiIp = nodeipmi[0].get('nodeIpmiIp', None)
    else:
        ipmiIp = None
    if ipmiIp is not None:
        # print('IPMI: %s' % ipmiIp)
        addresses.append('"%s","%s"\n' % ('IPMI', ipmiIp))
    intf = [i for i in interfaces if i['nodeId'] == node['id']]
    bonds = [i for i in intf[0]['interfaces'] if 'bondingMode' in i and i['bondingMode'] > 0]
    for bond in bonds:
        if 'staticIp' in bond:  # and bond['staticIp'] != nodeIp:
            if bond['staticIp'] == nodeIp:
                addresses.append('"%s","%s"\n' % ('%s (NODE IP)' % bond['name'], bond['staticIp']))
            else:
                addresses.append('"%s","%s"\n' % ('%s' % bond['name'], bond['staticIp']))
vlans = api('get', 'vlans?_includeTenantInfo=true&allUnderHierarchy=true')
for vlan in vlans:
    if 'ips' in vlan:
        for ip in vlan['ips']:
            addresses.append('"%s","%s"\n' % ('VIP', ip))
for address in sorted(addresses):
    print(address.split(',')[1].replace('"', '').replace('\n', ''))
    f.write(address)
f.close()
# print('\nOutput saved to %s\n' % outfile)
