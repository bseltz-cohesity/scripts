#!/usr/bin/env python
"""Clone a View Directory Using python"""

# usage: ./cloneDirectory.py -s mycluster -u admin -d local -sp /MyView/folder1 -dp /MyView -nd folder2
# the above example copies /MyView/folder1 to /MyView/folder2

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--sourcepath', type=str, required=True)
parser.add_argument('-t', '--targetpath', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
sourcepath = args.sourcepath
targetpath = args.targetpath

sourcepath = sourcepath.replace('\\', '/').replace('//', '/')
targetpath = targetpath.replace('\\', '/').replace('//', '/')

if sourcepath[0] == '/':
    sourcepath = sourcepath[1:]

if targetpath[0] == '/':
    targetpath = targetpath[1:]

if '/' not in targetpath:
    print('targetPath must be a new folder name')
    exit()
# print(targetpath.split('/',2))
(targetview, targetpath) = targetpath.rsplit('/', 1)

if targetpath == '':
    print('targetPath must be a new folder name')
    exit()

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# clone directory params
CloneDirectoryParams = {
    'destinationDirectoryName': targetpath,
    'destinationParentDirectoryPath': '/%s' % targetview,
    'sourceDirectoryPath': '/%s' % sourcepath
}

# clone directory
print("Cloning %s to %s/%s..." % (sourcepath, targetview, targetpath))
result = api('post', 'views/cloneDirectory', CloneDirectoryParams)
