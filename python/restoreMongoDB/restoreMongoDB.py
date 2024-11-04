#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
from time import sleep
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
parser.add_argument('-s', '--sourceserver', type=str, required=True)
parser.add_argument('-n', '--sourceobject', type=str, required=True)
parser.add_argument('-t', '--targetserver', type=str, default=None)
parser.add_argument('-dt', '--recoverdate', type=str, default=None)
parser.add_argument('-x', '--suffix', type=str, default=None)
parser.add_argument('-streams', '--streams', type=int, default=16)
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')

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
sourceserver = args.sourceserver
sourceobject = args.sourceobject
targetserver = args.targetserver
recoverdate = args.recoverdate
suffix = args.suffix
streams = args.streams
overwrite = args.overwrite
wait = args.wait

if noprompt is True:
    prompt = False
else:
    prompt = None

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True, prompt=prompt)
else:
    if emailmfacode:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, emailMfaCode=True, prompt=prompt)
    else:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, mfaCode=mfacode, prompt=prompt)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if apiconnected() is False:
    print('authentication failed')
    exit(1)

if targetserver is not None:
    rootNodes = api('get', 'protectionSources/rootNodes?environments=kMongoDB')
    targetNode = [r for r in rootNodes if r['protectionSource']['name'].lower() == targetserver.lower()]
    if targetNode is None or len(targetNode) == 0:
        print("targetserver %s not found" % targetserver)
        exit(1)
    else:
        targetNode = targetNode[0]

searchParams = {
    "mongodbParams": {
        "mongoDBObjectTypes": [
            "MongoDatabases",
            "MongoCollections"
        ],
        "searchString": sourceobject,
        "sourceIds": []
    },
    "objectType": "MongoObjects",
    "protectionGroupIds": [],
    "storageDomainIds": []
}

search = api('post', 'data-protect/search/indexed-objects', searchParams, v=2)

if search is None:
    print("Database/Collection %s not found" % sourceobject)
    exit(1)

results = [o for o in search['mongoObjects'] if o['sourceInfo']['name'].lower() == sourceserver.lower() and o['name'].lower() == sourceobject.lower()]

if results is None:
    print("Database/Collection %s/%s not found" % (sourceserver, sourceobject))
    exit(1)

allSnapshots = []
for result in results:
    snapshots = api('get', 'data-protect/objects/%s/protection-groups/%s/indexed-objects/snapshots?indexedObjectName=%s&includeIndexedSnapshotsOnly=true' % (result['sourceInfo']['sourceId'], result['protectionGroupId'], result['id']), v=2)
    if snapshots is not None:
        for snapshot in snapshots['snapshots']:
            allSnapshots.append(snapshot)

if recoverdate:
    recoverDateUsecs = dateToUsecs(recoverdate) + 60000000
    snapshots = [s for s in sorted(allSnapshots, key=lambda snap: snap['snapshotTimestampUsecs'], reverse=True) if s['snapshotTimestampUsecs'] < recoverDateUsecs]
    if snapshots is not None and len(snapshots) > 0:
        snapshot = snapshots[0]
        snapshotId = snapshot['objectSnapshotid']
    else:
        print("No snapshots available for %s/%s" % (sourceserver, sourceobject))
else:
    snapshots = sorted(allSnapshots, key=lambda snap: snap['snapshotTimestampUsecs'], reverse=True)
    snapshot = snapshots[0]
    snapshotId = snapshot['objectSnapshotid']

recoverDateString = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
recoverTaskName = "Recover_MongoDB_%s_%s_%s" % (sourceserver, sourceobject, recoverDateString)
recoverParams = {
    "name": recoverTaskName,
    "snapshotEnvironment": "kMongoDB",
    "mongodbParams": {
        "recoveryAction": "RecoverObjects",
        "recoverMongodbParams": {
            "overwrite": False,
            "concurrency": streams,
            "bandwidthMBPS": None,
            "snapshots": [
                {
                    "snapshotId": snapshotId,
                    "objects": [
                        {
                            "objectName": sourceobject
                        }
                    ]
                }
            ],
            "recoverTo": None,
            "suffix": None
        }
    }
}

if targetserver is not None:
    recoverParams['mongodbParams']['recoverMongodbParams']['recoverTo'] = targetNode['protectionSource']['id']

if suffix is not None:
    suffix = '-%s' % suffix
    recoverParams['mongodbParams']['recoverMongodbParams']['suffix'] = suffix

if overwrite is not None:
    recoverParams['mongodbParams']['recoverMongodbParams']['overwrite'] = True

targetobject = '%s%s' % (sourceobject, suffix)
if targetserver is not None:
    print("Restoring %s/%s to %s/%s" % (sourceserver, sourceobject, targetserver, targetobject))
elif suffix is not None:
    print("Restoring %s/%s to %s" % (sourceserver, sourceobject, targetobject))
else:
    print("Restoring %s/%s" % (sourceserver, sourceobject))

recovery = api('post', 'data-protect/recoveries', recoverParams, v=2)

# wait for restores to complete
finishedStates = ['Canceled', 'Succeeded', 'Failed']
if 'id' not in recovery:
    print('recovery error occured')
    if 'messages' in recovery and len(recovery['messages']) > 0:
        print(recovery['messages'][0])
    exit(1)
if wait is not None:
    print("Waiting for restore to complete...")
    while 1:
        sleep(30)
        recoveryTask = api('get', 'data-protect/recoveries/%s?includeTenants=true' % recovery['id'], v=2)
        status = recoveryTask['status']
        if status is not None and status in finishedStates:
            break
    print("Restore task finished with status: %s" % status)
    if status == 'Failed':
        if 'messages' in recoveryTask and len(recoveryTask['messages']) > 0:
            print(recoveryTask['messages'][0])
    if status == 'Succeedded':
        exit(0)
    else:
        exit(1)
exit(0)
