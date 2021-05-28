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
parser.add_argument('-n', '--viewname', type=str, required=True)  # name view to create
parser.add_argument('-a', '--aliasname', type=str, required=True)  # name of alias to create
parser.add_argument('-p', '--folderpath', type=str, default='/')  # folder path of alias

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
viewName = args.viewname
aliasName = args.aliasname
folderPath = args.folderpath

# authenticate
apiauth(vip, username, domain)

view = api('get', 'views/%s' % viewName)
if view is None:
    print('view %s not found')
    exit()

newAlias = {
    "viewName": view['name'],
    "viewPath": folderPath,
    "aliasName": aliasName,
    "sharePermissions": view.get('sharePermissions', []),
    "subnetWhitelist": view.get('subnetWhitelist', [])
}

print('Creating view alias %s -> %s%s' % (aliasName, viewName, folderPath))
result = api('post', 'viewAliases', newAlias)
