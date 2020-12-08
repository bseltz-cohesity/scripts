#!/usr/bin/env python
"""Upgrade Cluster for python"""

### usage: ./upgradeCluster.py -v mycluster -u myuser -domain mydomain.net -r '6.5.1c_release-20201119_ec194046' -url 'http://10.19.0.67:5000/6.5.1c_release-20201119_ec194046'

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-r', '--release', type=str, required=True)
parser.add_argument('-url', '--url', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
version = args.release
url = args.url

### authenticate
apiauth(vip, username, domain)

clusterId = api('get', 'cluster')['id']

### Configure upgrade parameters
upgradeParams = {
    "clusterId": clusterId,
    "targetSwVersion": version,
    "url": "%s" % url
}

### execute upgrade
result = api('post', '/nexus/cluster/upgrade', upgradeParams)
if 'message' in result:
    print(result['message'])
