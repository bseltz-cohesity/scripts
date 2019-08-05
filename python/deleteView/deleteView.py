#!/usr/bin/env python
"""Clone a Cohesity View Using python"""

### usage: ./deleteView.py -s mycluster -u admin -d domain -v myview

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-v', '--view', type=str, required=True)  # name of view to delete

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
viewName = args.view

### authenticate
apiauth(vip, username, domain)

### delete the view
api('delete', 'views/%s' % viewName)
print('Deleting view %s' % viewName)
