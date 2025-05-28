#!/usr/bin/env python
"""restore files using python"""

# version 2025.05.28

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep
from sys import exit
import argparse

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-org', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--sourceserver', type=str, required=True)  # name of source server
parser.add_argument('-t', '--targetserver', type=str, default=None)   # name of target server
parser.add_argument('-j', '--jobname', type=str, default=None)        # narrow search by job name
parser.add_argument('-n', '--filename', type=str, action='append')    # file name to restore
parser.add_argument('-f', '--filelist', type=str, default=None)       # text file list of files to restore
parser.add_argument('-p', '--restorepath', type=str, default=None)    # destination path
parser.add_argument('-r', '--runid', type=int, default=None)          # job run id to restore from
parser.add_argument('-o', '--olderthan', type=str, default=None)          # show snapshots after date
parser.add_argument('-w', '--wait', action='store_true')              # wait for completion and report result
parser.add_argument('-k', '--taskname', type=str, default=None)       # recoverytask name
parser.add_argument('-x', '--overwrite', action='store_true')           # force no index usage
parser.add_argument('-z', '--sleeptimeseconds', type=int, default=30)
parser.add_argument('-a', '--fromarchive', action='store_true')
parser.add_argument('-l', '--listruns', action='store_true')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
sleeptimeseconds = args.sleeptimeseconds
sourceserver = args.sourceserver
if args.targetserver is None:
    targetserver = sourceserver
else:
    targetserver = args.targetserver
jobname = args.jobname
files = args.filename
filelist = args.filelist
restorepath = args.restorepath
runid = args.runid
olderthan = args.olderthan
wait = args.wait
taskname = args.taskname
overwrite = args.overwrite
fromarchive = args.fromarchive
listruns = args.listruns

# gather server list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items

files = gatherList(files, filelist, name='files', required=True)

files = [('/' + item).replace(':\\', '/').replace('\\', '/').replace('//', '/') for item in files]
if restorepath is not None:
    restorepath = ('/' + restorepath).replace(':\\', '/').replace('\\', '/').replace('//', '/')

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

# find target server
targetservers = api('get', 'protectionSources/registrationInfo?allUnderHierarchy=false&environments=kPhysical')
if targetservers is not None and 'rootNodes' in targetservers and targetservers['rootNodes'] is not None and len(targetservers['rootNodes']) > 0:
    thistargetserver = [t for t in targetservers['rootNodes'] if t['rootNode']['name'].lower() == targetserver.lower()]
    if len(thistargetserver) > 0:
        thistargetserver = thistargetserver[0]
    else:
        print('target server %s not found' % targetserver)
        exit(1)
else:
    print('target server %s not found' % targetserver)
    exit(1)

# find backups for source server
searchResults = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverFiles&searchString=%s&environments=kPhysical,kPhysicalFiles' % sourceserver, v=2)
if searchResults is not None and 'objects' in searchResults and searchResults['objects'] is not None and len(searchResults['objects']) > 0:
    searchResults['objects'] = [o for o in searchResults['objects'] if o['name'].lower() == sourceserver.lower()]
    if len(searchResults['objects']) == 0:
        print("source server %s is not protected" % sourceserver)
        exit(1)
    if jobname is not None:
        for object in searchResults['objects']:
            object['latestSnapshotsInfo'] = [l for l in object['latestSnapshotsInfo'] if l['protectionGroupName'].lower() == jobname.lower()]
        searchResults['objects'] = [o for o in searchResults['objects'] if len(o['latestSnapshotsInfo']) > 0]
        if len(searchResults['objects']) == 0:
            print('source server %s is not protected by %s' % (sourceserver, jobname))
            exit(1)
else:
    print("source server %s is not protected" % sourceserver)
    exit(1)

# gather snapshots
snapshots = []
for object in searchResults['objects']:
    for latestSnapshotInfo in object['latestSnapshotsInfo']:
        thesesnapshots = api('get','data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (object['id'], latestSnapshotInfo['protectionGroupId']), v=2)
        if thesesnapshots is not None and 'snapshots' in thesesnapshots and thesesnapshots['snapshots'] is not None and len(thesesnapshots['snapshots']) > 0:
            snapshots += thesesnapshots['snapshots']

# filter snapshots by runid
if runid is not None:
    snapshots = [s for s in snapshots if s['runInstanceId'] == runid]
    if len(snapshots) == 0:
        print('runid %s not found' % runid)
        exit(1)

# filter snapshots by olderthan 
if olderthan is not None:
    olderthanusecs = dateToUsecs(olderthan) + 60000000
    snapshots = [s for s in snapshots if s['runStartTimeUsecs'] <= olderthanusecs]
    if len(snapshots) == 0:
        print('no snapshots from before %s' % olderthan)
        exit(1)

# find most recent snapshots
snapshots = sorted(snapshots, key=lambda s: s['runStartTimeUsecs'], reverse=True)

# list snapshots
if listruns is True:
    print('')
    for snapshot in snapshots:
        print('%s [%s] %s (%s)' % (snapshot['protectionGroupName'], usecsToDate(snapshot['runStartTimeUsecs']), snapshot['runInstanceId'], snapshot['snapshotTargetType']))
    exit()

# select archive or local snapshots
if fromarchive is True:
    snapshots = [s for s in snapshots if s['snapshotTargetType'] == 'Archival']
    if len(snapshots) == 0:
        print('no archived snapshots available')
        exit(1)
else:
    snapshots = [s for s in snapshots if s['snapshotTargetType'] == 'Local']
    if len(snapshots) == 0:
        print('no local snapshots available')
        exit(1)

snapshot = snapshots[0]

restoreFiles = []
for file in files:
    isDirectory = False
    if file.endswith('/'):
        isDirectory = True
        file = file[0:-1]
    if file not in [r['absolutePath'] for r in restoreFiles]:
        restoreFiles.append({
            "absolutePath": file,
            "isDirectory": isDirectory
        })

if taskname is not None:
    restoreTaskName = taskname
else:
    restoreTaskName = "Recover-Files_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

restoreParams = {
    "snapshotEnvironment": snapshot['environment'],
    "name": restoreTaskName,
    "physicalParams": {
        "objects": [
            {
                "snapshotId": snapshot['id']
            }
        ],
        "recoveryAction": "RecoverFiles",
        "recoverFileAndFolderParams": {
            "filesAndFolders": restoreFiles,
            "targetEnvironment": "kPhysical",
            "physicalTargetParams": {
                "recoverTarget": {
                    "id": thistargetserver['rootNode']['id']
                },
                "restoreToOriginalPaths": True,
                "overwriteExisting": overwrite,
                "preserveAttributes": True,
                "continueOnError": True,
                "saveSuccessFiles": True,
                "restoreEntityType": snapshot['runType']
            }
        }
    }
}

if restorepath is not None:
    restoreParams['physicalParams']['recoverFileAndFolderParams']['physicalTargetParams']['restoreToOriginalPaths'] = False
    restoreParams['physicalParams']['recoverFileAndFolderParams']['physicalTargetParams']['alternateRestoreDirectory'] = restorepath
print('Restoring files...')
recovery = api('post', 'data-protect/recoveries', restoreParams, v=2)

if 'id' not in recovery:
    print('recovery error occured')
    if 'messages' in recovery and len(recovery['messages']) > 0:
        print(recovery['messages'][0])
    exit(1)

# wait for restores to complete
finishedStates = ['Canceled', 'Succeeded', 'Failed']
if wait is True:
    while 1:
        sleep(sleeptimeseconds)
        recoveryTask = api('get', 'data-protect/recoveries/%s?includeTenants=true' % recovery['id'], v=2)
        status = recoveryTask['status']
        if status is not None and status in finishedStates:
            break
    print("Recovery ended with status: %s" % status)
    if status == 'Failed':
        if 'messages' in recoveryTask and len(recoveryTask['messages']) > 0:
            print('\n'.join(recoveryTask['messages']))
    if status == 'Succeeded':
        exit(0)
    else:
        exit(1)
exit(0)
