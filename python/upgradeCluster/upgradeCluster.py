#!/usr/bin/env python
"""Upgrade Cluster for python"""

### usage: ./upgradeCluster.py -v bseltzve01 -u admin -r '6.1.0b_release-20181211_b2d1609d' -url 'http://192.168.1.195:5000/6.1.0b_release-20181211_b2d1609d'

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
