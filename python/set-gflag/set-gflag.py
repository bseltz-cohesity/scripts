#!/usr/bin/env python
"""Set a gflag with python"""

### import pyhesity wrapper module
from pyhesity import *
import requests
from urllib import quote_plus
import urllib3
import requests.packages.urllib3

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-c', '--cluster', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--servicename', type=str, required=True)
parser.add_argument('-f', '--flagname', type=str, required=True)
parser.add_argument('-v', '--flagvalue', type=str, required=True)
parser.add_argument('-r', '--reason', type=str, required=True)
parser.add_argument('-e', '--effectivenow', action='store_true')

args = parser.parse_args()

vip = args.cluster
username = args.username
domain = args.domain
servicename = args.servicename
flagname = args.flagname
flagvalue = args.flagvalue
reason = args.reason
effectivenow = args.effectivenow

requests.packages.urllib3.disable_warnings()

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

### constants
port = {
    "nexus": "23456",
    "iris": "443",
    "stats": "25566",
    "eagle_agent": "23460",
    "vault_proxy": "11115",
    "athena": "25681",
    "iris_proxy": "24567",
    "atom": "20005",
    "smb2_proxy": "20007",
    "bifrost_broker": "29992",
    "alerts": "21111",
    "bridge": "11111",
    "keychain": "22000",
    "smb_proxy": "20003",
    "bridge_proxy": "11116",
    "groot": "26999",
    "apollo": "24680",
    "tricorder": "23458",
    "magneto": "20000",
    "rtclient": "12321",
    "nexus_proxy": "23457",
    "gandalf": "22222",
    "patch": "30000",
    "librarian": "26000",
    "yoda": "25999",
    "storage_proxy": "20001",
    "statscollector": "25680",
    "newscribe": "12222"
}

### authenticate
apiauth(vip, username, domain)

### get nodes
cluster = api('get', 'cluster')
clusterid = cluster['id']

### save flags
gflag = {
    'clusterId': clusterid,
    'serviceName': servicename,
    'gflags': [
        {
            'name': flagname,
            'value': flagvalue,
            'reason': reason
        }
    ]
}

print('setting flag %s to %s' % (flagname, flagvalue))

response = api('post', '/nexus/cluster/update_gflags', gflag)

### make effective now
if effectivenow is True:
    print('    making effective now on all nodes')
    context = getContext()
    nodes = api('get', 'nodes')
    for node in nodes:
        print('        %s' % node['ip'])
        if servicename == 'iris':
            response = requests.get('https://%s:%s/flagz?%s=%s' % (node['ip'], port[servicename], flagname, flagvalue), verify=False, headers=context['HEADER'])
        else:
            response = requests.get('https://%s/siren/v1/remote?relPath=&remoteUrl=http' % vip + quote_plus('://') + node['ip'] + quote_plus(':') + port[servicename] + quote_plus('/flagz?') + '%s=%s' % (flagname, flagvalue), verify=False, headers=context['HEADER'])
