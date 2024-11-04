#!/usr/bin/env python

### import Cohesity python module
from pyhesity import *
from datetime import datetime
import codecs

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain

### authenticate
apiauth(vip, username, domain)


cluster = api('get', 'cluster')

now = datetime.now()
dateString = now.strftime("%Y-%m-%d")

outfileName = 'licenseReport-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfileName, 'w', 'utf-8')
f.write('featureName,currentUsageGiB,numVm\n')

print('\nGathering license usage...\n')

lic = api('get', 'licenseUsage')
currentUsage = lic['usage'][str(cluster['id'])]

for sku in currentUsage:
    f.write('%s,%s,%s\n' % (sku['featureName'], sku['currentUsageGiB'], sku['numVm']))
    print('  %s:  %s GiB' % (sku['featureName'], sku['currentUsageGiB']))

f.close()
print("\noutput saved to %s\n" % outfileName)
