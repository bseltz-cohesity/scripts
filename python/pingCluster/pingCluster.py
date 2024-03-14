#!/usr/bin/env python
"""Ping Cluster Nodes"""

### import pyhesity wrapper module
from pyhesity import *
import platform
import subprocess

### command line arguments
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

# authentication =========================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================


def ping(host):
    param = '-n' if platform.system().lower() == 'windows' else '-c'
    command = ['ping', param, '1', host]
    return subprocess.run(args=command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


nodes = api('get', 'nodes')
ipmi = api('get', '/nexus/ipmi/cluster_get_lan_info', quiet=True)
nodeIds = [n['id'] for n in nodes]

for nodeId in nodeIds:
    node = [n for n in nodes if n['id'] == nodeId][0]
    print('\nNodeId: %s' % node['id'])
    nodeIp = node['ip'].split(':')[-1]
    print('NodeIp: %s: (pingable: %s)' % (nodeIp, ping(nodeIp)))
    ipmiIp = None
    if ipmi is not None and 'nodesIpmiInfo' in ipmi:
        nodeipmi = [i for i in ipmi['nodesIpmiInfo'] if i['nodeIp'] == node['ip'].split(':')[-1]]
        if len(nodeipmi) > 0:
            ipmiIp = nodeipmi[0].get('nodeIpmiIp', None)
    else:
        ipmiIp = None
    if ipmiIp is not None:
        print('IpmiIp: %s: (pingable: %s)' % (ipmiIp, ping(ipmiIp)))
    else:
        print('IpmiIp: None')
