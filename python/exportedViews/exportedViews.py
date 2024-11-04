#!/usr/bin/env python
"""List Exported Views using Python"""

# usage: ./exportedViews.py -v mycluster -u myusername -d mydomain.net

### import Cohesity python module
from pyhesity import *

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

### get global whitelist
globalWhitelist = api('get', '/clientSubnetWhitelist')

### get list of views
views = api('get', 'views?includeInternalViews=true&allUnderHierarchy=true')

### internal views to be ignored
ignore = ['madrox:', 'magneto_', 'icebox_', 'AUDIT_', 'yoda_', 'cohesity_download_']

### display list of views
print('\nListing Exported Views...\n')

for view in views['views']:
    skip = False
    for item in ignore:
        if item in view['name']:
            skip = True
    if skip is False:
        print("    View Name: %s" % view['name'])
        print("  Description: %s" % view['description'])
        print("Logical Bytes: %s" % view['logicalUsageBytes'])
        print("      Created: %s" % (usecsToDate(view['createTimeMsecs'] * 1000)))
        print("    Whitelist:")
        if 'subnetWhitelist' in view:
            whitelist = view['subnetWhitelist']
        else:
            whitelist = globalWhitelist['clientSubnetWhitelist']
        for entity in whitelist:
            print("               %s" % entity['ip'])
        print("-------\n")
