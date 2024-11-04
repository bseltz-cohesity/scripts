#!/usr/bin/env python
"""Upload SSL Certificate Using Python"""

### usage: uploadSSLCertificate.py -v mycluster -u myusername -d mydomain.net -c ./mycluster_cert.pem -k ./mycluster_key.pem

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--certfile', type=str, required=True)
parser.add_argument('-k', '--keyfile', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
certfile = args.certfile
keyfile = args.keyfile

### authenticate
apiauth(vip, username, domain)

### read text from cert and key files
certfilehandle = open(certfile, 'r')
certdata = certfilehandle.read()

keyfilehandle = open(keyfile, 'r')
keydata = keyfilehandle.read()

### json for cert api call
sslparams = {
    "certificate": certdata,
    "lastUpdateTimeMsecs": 0,
    "privateKey": keydata
}

### put certificate
result = api('put', 'certificates/webServer', sslparams)  # /public/certificates/webServer

### get cluster ID for service restart call
cluster = api('get', 'cluster')  # /public/cluster

### JSON for iris service restart call
restartParams = {
    "clusterId": cluster['id'],
    "services": ["iris"]
}

### service restart call
restart = api('post', '/nexus/cluster/restart', restartParams)  # /nexus/cluster/restart
