#!/usr/bin/env python
"""Clone a View Directory Using python"""

### usage: ./cloneDirectory.py -s mycluster -u admin -d local -sp /MyView/folder1 -dp /MyView -nd folder2
### the above example copies /MyView/folder1 to /MyView/folder2
 
### import pyhesity wrapper module
from pyhesity import *
import sys

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s','--server', type=str, required=True)
parser.add_argument('-u','--username', type=str, required=True)
parser.add_argument('-d','--domain',type=str,default='local')
parser.add_argument('-sp','--sourcepath', type=str, required=True)
parser.add_argument('-dp','--destinationpath', type=str, required=True)
parser.add_argument('-nd','--newdirectory', type=str, required=True)

args = parser.parse_args()
    
vip = args.server
username = args.username
domain = args.domain
sourceDirectoryPath = args.sourcepath
destinationParentDirectoryPath = args.destinationpath
destinationDirectoryName = args.newdirectory

### authenticate
apiauth(vip, username, domain)

### clone directory params
CloneDirectoryParams = {
    'destinationDirectoryName': destinationDirectoryName,
    'destinationParentDirectoryPath': destinationParentDirectoryPath,
    'sourceDirectoryPath': sourceDirectoryPath
}

### clone directory
print "Cloning directory %s to %s/%s..." % (sourceDirectoryPath, destinationParentDirectoryPath, destinationDirectoryName)
result = api('post','views/cloneDirectory',CloneDirectoryParams)
if result is not None:
    if 'errorCode' in result:
        sys.exit(1)
