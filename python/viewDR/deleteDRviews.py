#!/usr/bin/env python
"""delete views after disaster recovery"""

### import pyhesity wrapper module
from pyhesity import *
import sys

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-n', '--viewName', type=str, action='append', default=None)
parser.add_argument('-l', '--viewList', type=str, default='clonedViews.txt')
parser.add_argument('-x', '--deleteSnapshots', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
viewNames = args.viewName
viewList = args.viewList
deleteSnapshots = args.deleteSnapshots

# gather view names from command line and file
if viewNames is None:
    viewNames = []
if viewList is not None:
    f = open(viewList, 'r')
    viewNames += [s.strip().lower() for s in f.readlines() if s.strip() != '']
    f.close()
if len(viewNames) == 0:
    print("No views selected")
    exit(1)

viewNames = list(set(viewNames))

# identify python version
if sys.version_info[0] < 3:
    pyversion = 2
else:
    pyversion = 3

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# get cluster info
cluster = api('get', 'cluster')

# get view protection jobs
jobs = api('get', 'protectionJobs?environments=kView')

# get existing views
views = api('get', 'views')

confirmed = False

# process selected views
for viewName in viewNames:
    view = [v for v in views['views'] if v['name'].lower() == viewName.lower()]
    if view is None or len(view) == 0:
        print('view %s not found' % viewName)
    else:
        view = view[0]
        if confirmed is False:
            print("\n***********************************************")
            print("*** Warning: you are about to delete views! ***")
            print("***********************************************")
            # prompt user to confirm deletion
            result = 'no answer'
            while result.lower() != 'yes':
                if pyversion == 2:
                    result = raw_input('\nAre you sure? Yes(No) ')
                else:
                    result = input('\nAre you sure? Yes(No) ')
                if result.lower() == 'no':
                    exit(0)
            confirmed = True
            print('')

        if confirmed is True:
            if 'viewProtection' in view:
                if deleteSnapshots is True:
                    result = api('delete', 'protectionJobs/%s' % view['viewProtection']['protectionJobs'][0]['jobId'], {'deleteSnapshots': True})
                else:
                    result = api('delete', 'protectionJobs/%s' % view['viewProtection']['protectionJobs'][0]['jobId'])
            print('Deleting %s' % viewName)
            result = api('delete', 'views/%s' % viewName)
