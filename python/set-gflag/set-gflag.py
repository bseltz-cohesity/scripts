#!/usr/bin/env python
"""Set a gflag with python"""

### import pyhesity wrapper module
from pyhesity import *
import requests

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

### constants
port = {
    'magneto': '20000',
    'bridge': '11111',
    'iris': '443'
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
    nodes = api('get', 'nodes')
    for node in nodes:
        response = requests.get('http://%s:%s/flagz?%s=%s' % (node['ip'], port[servicename], flagname, flagvalue), verify=False)
