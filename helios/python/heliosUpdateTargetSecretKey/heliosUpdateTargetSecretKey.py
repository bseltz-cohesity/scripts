#!/usr/bin/env python
"""Helios Update Secret Key for External Targets"""

from pyhesity import *
from datetime import datetime
import getpass

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-pwd', '--password', type=str)
parser.add_argument('-a', '--accesskey', type=str, required=True)
parser.add_argument('-s', '--secretkey', type=str, default='')
args = parser.parse_args()

username = args.username
password = args.password
accesskey = args.accesskey
secretkey = args.secretkey

while secretkey is None or len(secretkey) < 2:
    secretkey = getpass.getpass("Please enter the secretkey: ")

### authenticate
apiauth(vip='helios.cohesity.com', username=username, domain='local', password=password)

now = datetime.now()
dateString = now.strftime("%Y-%m-%d")

f = open('vaults-updated-%s.txt' % dateString, 'w')

for hcluster in heliosClusters():
    heliosCluster(hcluster['name'])
    cluster = api('get', 'cluster')
    if cluster:
        print('%s' % hcluster['name'])
        f.write('%s\n' % hcluster['name'])
        vaults = api('get', 'vaults')
        if len(vaults) > 0:
            vaults = [v for v in vaults if 'amazon' in v['config'] and v['config']['amazon']['accessKeyId'] == accesskey]
            for vault in vaults:
                print('    updating key for target: %s...' % vault['name'])
                f.write('    updating key for target: %s...\n' % vault['name'])
                vault['config']['amazon']['secretAccessKey'] = secretkey
                result = api('put', 'vaults/%s' % vault['id'], vault)
    else:
        print('%s (trouble accessing cluster)' % hcluster['name'])
        f.write('%s (trouble accessing cluster)\n' % hcluster['name'])
f.close()
