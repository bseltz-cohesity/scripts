#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
from time import sleep
import argparse

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
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-n', '--objectname', type=str, required=True)
parser.add_argument('-r', '--newname', type=str, default=None)
parser.add_argument('-t', '--targetserver', type=str, default=None)
parser.add_argument('-dt', '--recoverdate', type=str, default=None)
parser.add_argument('-x', '--suffix', type=str, default=None)
parser.add_argument('-cc', '--concurrency', type=int, default=None)
parser.add_argument('-bw', '--bandwidth', type=int, default=None)
parser.add_argument('-o', '--overwrite', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')

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
sourceserver = args.sourcename
objectname = args.objectname
newname = args.newname
targetserver = args.targetserver
recoverdate = args.recoverdate
suffix = args.suffix
concurrency = args.concurrency
bandwidth = args.bandwidth
overwrite = args.overwrite
wait = args.wait

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

if targetserver is not None:
    rootNodes = api('get', 'protectionSources/rootNodes?environments=kCassandra')
    targetNode = [r for r in rootNodes if r['protectionSource']['name'].lower() == targetserver.lower() or r['protectionSource']['customName'].lower() == targetserver.lower()]
    if targetNode is None or len(targetNode) == 0:
        print("targetserver %s not found" % targetserver)
        exit(1)
    else:
        targetNode = targetNode[0]

recoverDateString = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
recoverTaskName = "Recover_Cassandra_%s_%s" % (sourceserver, recoverDateString)
recoverParams = {
    "name": recoverTaskName,
    "snapshotEnvironment": "kCassandra",
    "cassandraParams": {
        "recoveryAction": "RecoverObjects",
        "recoverCassandraParams": {
            "overwrite": False,
            "concurrency": concurrency,
            "bandwidthMBPS": None,
            "snapshots": [],
            "recoverTo": None,
            "suffix": None
        }
    }
}

if targetserver is not None:
    recoverParams['cassandraParams']['recoverCassandraParams']['recoverTo'] = targetNode['protectionSource']['id']

if suffix is not None:
    # suffix = '%s' % suffix
    recoverParams['cassandraParams']['recoverCassandraParams']['suffix'] = suffix

if overwrite is True:
    recoverParams['cassandraParams']['recoverCassandraParams']['overwrite'] = True

searchParams = {
    "cassandraParams": {
        "cassandraObjectTypes": [
            "CassandraKeyspaces",
            "CassandraTables"
        ],
        "searchString": objectname,
        "sourceIds": []
    },
    "objectType": "CassandraObjects",
    "protectionGroupIds": [],
    "storageDomainIds": []
}

search = api('post', 'data-protect/search/indexed-objects', searchParams, v=2)

if search is None:
    print(" %s not found" % objectname)
    exit(1)

results = [o for o in search['cassandraObjects'] if o['sourceInfo']['name'].lower() == sourceserver.lower() and o['name'].lower() == objectname.lower()]

if results is None or len(results) == 0:
    print("Keyspace/Table %s/%s not found" % (sourceserver, objectname))
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
        print("No snapshots available for %s/%s" % (sourceserver, objectname))
        exit(1)
else:
    snapshots = sorted(allSnapshots, key=lambda snap: snap['snapshotTimestampUsecs'], reverse=True)
    snapshot = snapshots[0]
    snapshotId = snapshot['objectSnapshotid']
    recoverParams['cassandraParams']['recoverCassandraParams']['snapshots'].append({
        "snapshotId": snapshotId,
        "objects": [
            {
                "objectName": objectname
            }
        ]
    })

if newname is not None:
    recoverParams['cassandraParams']['recoverCassandraParams']['snapshots'][0]['objects'][0]['renameTo'] = newname

print('Performing recovery...')

recovery = api('post', 'data-protect/recoveries', recoverParams, v=2)

# wait for restores to complete
finishedStates = ['Canceled', 'Succeeded', 'Failed']
if 'id' not in recovery:
    print('recovery error occured')
    if 'messages' in recovery and len(recovery['messages']) > 0:
        print(recovery['messages'][0])
    exit(1)
if wait is True:
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
