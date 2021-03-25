#!/usr/bin/env python
"""Create a Cohesity NFS View Using python"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain

# authenticate
apiauth(vip, username, domain)

views = api('get', 'views')
if views['count'] > 0:
    print('\nProto  Name')
    print('-----  ----')
    for view in sorted(views['views'], key=lambda v: v['name'].lower()):
        print(' %-4s  %s' % (view['protocolAccess'][1:].replace('Only', ''), view['name']))
