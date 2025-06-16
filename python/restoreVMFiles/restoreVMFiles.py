#!/usr/bin/env python
"""restore files using python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta
from time import sleep
import sys
import getpass
import argparse

from pyhesity import COHESITY_API

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')  # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # username
parser.add_argument('-d', '--domain', type=str, default='local')      # domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')         # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)       # optional password
parser.add_argument('-c', '--clustername', type=str, default=None)   # name of helios cluster to connect to
parser.add_argument('-s', '--sourcevm', type=str, required=True)  # name of source server
parser.add_argument('-t', '--targetvm', type=str, default=None)   # name of target server
parser.add_argument('-n', '--filename', type=str, action='append')    # file name to restore
parser.add_argument('-f', '--filelist', type=str, default=None)       # text file list of files to restore
parser.add_argument('-p', '--restorepath', type=str, default=None)    # destination path
parser.add_argument('-l', '--showversions', action='store_true')      # show available snapshots
parser.add_argument('-r', '--runid', type=int, default=None)          # job run id to restore from
parser.add_argument('-y', '--daysago', type=int, default=0)          # job run id to restore from
parser.add_argument('-o', '--olderthan', type=str, default=None)          # show snapshots after date
parser.add_argument('-w', '--wait', action='store_true')              # wait for completion and report result
parser.add_argument('-m', '--restoremethod', type=str, choices=['ExistingAgent', 'AutoDeploy', 'VMTools'], default='AutoDeploy')
parser.add_argument('-vu', '--vmuser', type=str, default=None)    # destination path
parser.add_argument('-vp', '--vmpwd', type=str, default=None)    # destination path
parser.add_argument('-x', '--noindex', action='store_true')
parser.add_argument('-k', '--taskname', type=str, default=None)       # recoverytask name
parser.add_argument('-j', '--jobname', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
clustername = args.clustername
sourcevm = args.sourcevm
targetvm = args.targetvm
files = args.filename
filelist = args.filelist
restorepath = args.restorepath
vmuser = args.vmuser
vmpwd = args.vmpwd
runid = args.runid
wait = args.wait
showversions = args.showversions
olderthan = args.olderthan
daysago = args.daysago
restoremethod = args.restoremethod
noindex = args.noindex
taskname = args.taskname
jobname = args.jobname

if sys.version_info > (3,):
    long = int

# gather file list
if files is None:
    files = []
if filelist is not None:
    f = open(filelist, 'r')
    files += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
if len(files) == 0:
    print("No files selected for restore")
    exit(1)

# convert to UNIX style paths
files = [('/' + item).replace('\\', '/').replace(':', '').replace('//', '/') for item in files]
if restorepath is not None:
    restorepath = ('/' + restorepath).replace('\\', '/').replace(':', '').replace('//', '/')

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)
if apiconnected() is False:
    print('authentication failed')
    exit(1)

if vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
        if 'accessClusterId' not in COHESITY_API['HEADER']:
            exit()
    else:
        print('--clustername is required when connecting to Helios')
        exit()

restoreMethods = {
    'ExistingAgent': 'UseExistingAgent',
    'AutoDeploy': 'AutoDeploy',
    'VMTools': 'UseHypervisorApis'
}

# find source object
objects = api('get', "data-protect/search/protected-objects?snapshotActions=RecoverFiles&searchString=%s&environments=kVMware" % sourcevm, v=2)
if objects:
    obj = [o for o in objects['objects'] if o['name'].lower() == sourcevm.lower()]
    if len(obj) == 0:
        print("VM %s not found" % sourcevm)
        exit(1)
obj = obj[0]

# get snapshots
objectId = obj['id']
if jobname:
    obj['latestSnapshotsInfo'] = [s for s in obj['latestSnapshotsInfo'] if s['protectionGroupName'].lower() == jobname.lower()]
    if len(obj['latestSnapshotsInfo']) == 0:
        print("No backups for VM %s in protection group %s" % (sourcevm, jobname))
        exit(1)
groupId = obj['latestSnapshotsInfo'][0]['protectionGroupId']
snapshots = api('get', "data-protect/objects/%s/snapshots?protectionGroupIds=%s" % (objectId, groupId), v=2)
if showversions:
    print('%10s  %s' % ('runId', 'runDate'))
    print('%10s  %s' % ('-----', '-------'))
    for snapshot in snapshots['snapshots']:
        print('%10d  %s' % (snapshot['runInstanceId'], usecsToDate(snapshot['runStartTimeUsecs'])))
    exit(0)


# version selection
today = datetime.now()
midnight = datetime.combine(today, datetime.min.time())

if daysago > 0:
    olderthan = datetime.strftime((midnight - timedelta(days=(daysago - 1))), "%Y-%m-%d %H:%M:%S")
if runid:
    # select specific run ID
    snapshot = [s for s in snapshots['snapshots'] if s['runInstanceId'] == runid]
    if len(snapshot) == 0:
        print("runId %s not found")
        exit(1)
    snapshotId = snapshot[0]['id']
elif olderthan:
    olderthanusecs = dateToUsecs(olderthan)
    olderSnapshots = [s for s in snapshots['snapshots'] if olderthanusecs > s['runStartTimeUsecs']]
    if len(olderSnapshots) > 0:
        snapshotId = olderSnapshots[-1]['id']
    else:
        print("Oldest snapshot is %s" % usecsToDate(snapshots['snapshots'][0]['runStartTimeUsecs']))
        exit(1)
else:
    snapshotId = snapshots['snapshots'][-1]['id']

if taskname is not None:
    restoreTaskName = taskname
else:
    restoreTaskName = "Recover-Files_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

restoreParams = {
    "vmwareParams": {
        "objects": [
            {
                "snapshotId": snapshotId
            }
        ],
        "recoverFileAndFolderParams": {
            "vmwareTargetParams": {
                "encryptionEnabled": False,
                "recoverToOriginalTarget": True,
                "preserveAttributes": True,
                "continueOnError": True,
                "overwriteExisting": True
            },
            "targetEnvironment": "kVMware",
            "filesAndFolders": []
        },
        "recoveryAction": "RecoverFiles"
    },
    "snapshotEnvironment": "kVMware",
    "name": restoreTaskName
}

# set VM credentials
if restoremethod != 'ExistingAgent':
    if vmuser is None:
        print("VM credentials required for 'AutoDeploy' and 'VMTools' restore methods")
        exit(1)
    if vmpwd is None:
        # prompt user for password
        vmpwd = getpass.getpass("Enter VM password: ")
    vmCredentials = {
        "username": vmuser,
        "password": vmpwd
    }

# find target object
if targetvm:
    if restorepath is None:
        print("restorePath required when restoring to alternate target VM")
        exit(1)
    vms = api('get', 'protectionSources/virtualMachines')
    targetObject = [v for v in vms if v['name'].lower() == targetvm.lower()]
    if len(targetObject) == 0:
        print("VM %s not found" % targetvm)
        exit(1)
    restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']['recoverToOriginalTarget'] = False
    restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']['newTargetConfig'] = {
        "targetVm": {
            "id": targetObject[0]['id'],
        },
        "recoverMethod": restoreMethods[restoremethod],
        "absolutePath": restorepath
    }
    if restoremethod != 'ExistingAgent':
        restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']['newTargetConfig']["targetVmCredentials"] = vmCredentials
else:
    # original target config
    restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']["originalTargetConfig"] = {
        "recoverMethod": restoreMethods[restoremethod]
    }
    if restorepath is not None:
        restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']["originalTargetConfig"]['recoverToOriginalPath'] = False
        restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']["originalTargetConfig"]["alternatePath"] = restorepath
    else:
        restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']["originalTargetConfig"]["recoverToOriginalPath"] = True
    if restoremethod != 'ExistingAgent':
        restoreParams['vmwareParams']['recoverFileAndFolderParams']['vmwareTargetParams']["originalTargetConfig"]["targetVmCredentials"] = vmCredentials

# find files for restore
for file in files:
    if noindex:
        if file[-1] == '/':
            isDirectory = True
        else:
            isDirectory = False
        restoreParams['vmwareParams']['recoverFileAndFolderParams']['filesAndFolders'].append({
            "absolutePath": file,
            "isDirectory": isDirectory
        })
    else:
        # encodedFile = quote_plus(file)
        searchParams = {
            "fileParams": {
                "searchString": file,
                "sourceEnvironments": [
                    "kVMware"
                ],
                "objectIds": [
                    objectId
                ]
            },
            "objectType": "Files"
        }
        search = api('post', "data-protect/search/indexed-objects", searchParams, v=2)

        if search is not None and 'files' in search:
            thisFile = [t for t in search['files'] if "%s/%s" % (t['path'].lower(), t['name'].lower()) == file.lower() or "%s/%s/" % (t['path'].lower(), t['name'].lower()) == file.lower()]

            if len(thisFile) == 0:
                print("file %s not found" % file)
            else:
                if file[-1] == '/':
                    isDirectory = True
                    absolutePath = "%s/%s/" % (thisFile[0]['path'], thisFile[0]['name'])
                else:
                    isDirectory = False
                    absolutePath = "%s/%s" % (thisFile[0]['path'], thisFile[0]['name'])
                restoreParams['vmwareParams']['recoverFileAndFolderParams']['filesAndFolders'].append({
                    "absolutePath": absolutePath,
                    "isDirectory": isDirectory
                })
        else:
            print("file %s not found" % file)

# perform restore
if len(restoreParams['vmwareParams']['recoverFileAndFolderParams']['filesAndFolders']) > 0:
    restoreTask = api('post', 'data-protect/recoveries', restoreParams, v=2)
    if 'id' in restoreTask:
        restoreTaskId = restoreTask['id']
        print("Restoring Files...")
        if wait:
            while restoreTask['status'] == "Running":
                sleep(5)
                restoreTask = api('get', "data-protect/recoveries/%s?includeTenants=true" % restoreTaskId, v=2)
            if restoreTask['status'] == 'Succeeded':
                print("Restore %s" % restoreTask['status'])
            else:
                print("Restore %s: %s" % (restoreTask['status'], (", ".join(restoreTask['messages']))))
    else:
        exit(1)
else:
    print("No files found for restore")
    exit(1)
