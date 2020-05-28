#!/usr/bin/env python
"""restore a folder using python"""

# usage: ./restoreFolder.py -v mycluster -u myuser -d mydomain.net -j myjobname -s server1.mydomain.net -f /home/myuser -t server2.mydomain.net -p /tmp/restore

# import pyhesity wrapper module
from pyhesity import *
from urllib import quote_plus
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # (optional) username
parser.add_argument('-d', '--domain', type=str, default='local')      # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')         # (optional) use API key for authentication
parser.add_argument('-pwd', '--password', type=str, default=None)     # optional password
parser.add_argument('-j', '--jobName', type=str, required=True)       # job name
parser.add_argument('-s', '--sourceServer', type=str, required=True)  # name of source server
parser.add_argument('-f', '--sourceFolder', type=str, required=True)  # path of folder to be recovered
parser.add_argument('-t', '--targetServer', type=str, default=None)   # name of target server
parser.add_argument('-p', '--targetPath', type=str, default=None)     # destination path

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
jobName = args.jobName
sourceServer = args.sourceServer
targetServer = args.targetServer
sourceFolder = args.sourceFolder
targetPath = args.targetPath
useApiKey = args.useApiKey

if targetServer is None:
    targetServer = sourceServer

# authenticate
apiauth(vip, username, domain, password=password, useApiKey=useApiKey)

encodedfilename = quote_plus(sourceFolder)

# find sourceServer
results = api('get', '/searchvms?entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAzure&entityTypes=kFlashBlade&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kView&entityTypes=kVMware&vmName=%s' % sourceServer)
if 'vms' not in results:
    print("sourceServer %s not found!" % sourceServer)
    exit(1)

# find sourceServer backups in jobName
sourceEntity = [result for result in results['vms'] if result['vmDocument']['jobName'].lower() == jobName.lower()]
if(len(sourceEntity)) < 1:
    print("no search results from jobName %s!" % jobName)
    exit(1)

sourceEntity = sourceEntity[0]
sourceEntityType = sourceEntity['vmDocument']['objectId']['entity']['type']

# find targetServer
results = api('get', '/backupsources?allUnderHierarchy=true&envTypes=%s' % sourceEntityType)
targetEntity = [result for result in results['entityHierarchy']['children'][0]['children'] if result['entity']['displayName'].lower() == targetServer.lower()]
if(len(targetEntity)) < 1:
    print("targetServer %s not found!" % targetServer)
    exit(1)

targetEntity = targetEntity[0]

now = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")

# restoreTask
restoreParams = {
    "filenames": [
        sourceFolder
    ],
    "sourceObjectInfo": {
        "jobId": sourceEntity['vmDocument']['objectId']['jobId'],
        "jobInstanceId": sourceEntity['vmDocument']['versions'][0]['instanceId']['jobInstanceId'],
        "startTimeUsecs": sourceEntity['vmDocument']['versions'][0]['instanceId']['jobStartTimeUsecs'],
        "entity": sourceEntity['vmDocument']['objectId']['entity'],
        "jobUid": sourceEntity['vmDocument']['objectId']['jobUid']
    },
    "params": {
        "targetEntity": targetEntity['entity'],
        "targetEntityCredentials": {
            "username": "",
            "password": ""
        },
        "restoreFilesPreferences": {
            "restoreToOriginalPaths": True,
            "overrideOriginals": True,
            "preserveTimestamps": True,
            "preserveAcls": True,
            "preserveAttributes": True,
            "continueOnError": False
        }
    },
    "name": "restorefolders-%s" % now
}

if targetPath is not None:
    restoreParams['params']['restoreFilesPreferences']['restoreToOriginalPaths'] = False
    restoreParams['params']['restoreFilesPreferences']['alternateRestoreBaseDirectory'] = targetPath

# execute restore
result = api('post', '/restoreFiles', restoreParams)
print("Restoring %s:%s to %s:%s" % (sourceServer, sourceFolder, targetServer, targetPath))
