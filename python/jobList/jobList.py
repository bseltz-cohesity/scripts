#!/usr/bin/env python
"""List Protection Jobs for python"""

# usage: ./jobList.py -v mycluster -u myuser -d mydomain.net [ -s defaultStorageDomain ] [ -e vmware ]

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-s', '--storagedomain', type=str, default=None)
parser.add_argument('-e', '--environment', type=str, default=None)
parser.add_argument('-p', '--paused', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
storagedomain = args.storagedomain
environment = args.environment
paused = args.paused

# authenticate
apiauth(vip, username, domain)

sd = []
if storagedomain is not None:
    sd = [s for s in api('get', 'viewBoxes') if s['name'].lower() == storagedomain.lower()]
    if len(sd) > 0:
        sd = sd[0]
    else:
        print('Storage Domain %s not found' % storagedomain)
        exit(1)

# find protection job
jobs = sorted(api('get', 'protectionJobs'), key=lambda j: j['name'])
for job in jobs:
    if storagedomain is None or sd['id'] == job['viewBoxId']:
        if environment is None or job['environment'][1:].lower() == environment.lower():
            if not paused or ('isPaused' in job and job['isPaused'] is True):
                print('%s (%s)' % (job['name'], job['environment'][1:]))
