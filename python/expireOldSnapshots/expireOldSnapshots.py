#!/usr/bin/env python
"""expire old snapshots"""

# usage: ./expireOldSnapshots.py -v mycluster -u admin [ -d local ] -k 30 [ -e ] [ -r ]

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-k', '--daystokeep', type=int, required=True)  # number of days of snapshots to retain
parser.add_argument('-e', '--expire', action='store_true')          # (optional) expire snapshots older than k days
parser.add_argument('-r', '--confirmreplication', action='store_true')  # (optional) confirm replication before expiring

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
daystokeep = args.daystokeep
expire = args.expire
confirmreplication = args.confirmreplication

# authenticate
apiauth(vip, username, domain)

# get cluster Id
clusterId = api('get', 'cluster')['id']

print("Searching for old snapshots...")

for job in api('get', 'protectionJobs'):
    for run in api('get', 'protectionRuns?jobId=%s&numRuns=999999&excludeTasks=true&excludeNonRestoreableRuns=true' % job['id']):
        startdate = usecsToDate(run['copyRun'][0]['runStartTimeUsecs'])
        startdateusecs = run['copyRun'][0]['runStartTimeUsecs']

        # check for replication
        replicated = False
        for copyRun in run['copyRun']:
            if copyRun['target']['type'] == 'kRemote':
                if copyRun['status'] == 'kSuccess':
                    replicated = True

        if startdateusecs < timeAgo(daystokeep, 'days') and run['backupRun']['snapshotsDeleted'] is False:
            if expire:
                if replicated is True or confirmreplication is False:
                    exactRun = api('get', '/backupjobruns?exactMatchStartTimeUsecs=%s&id=%s' % (startdateusecs, job['id']))
                    jobUid = exactRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']
                    expireRun = {"jobRuns":
                                 [
                                     {
                                         "expiryTimeUsecs": 0,
                                         "jobUid": {
                                             "clusterId": jobUid['clusterId'],
                                             "clusterIncarnationId": jobUid['clusterIncarnationId'],
                                             "id": jobUid['objectId'],
                                         },
                                         "runStartTimeUsecs": startdateusecs,
                                         "copyRunTargets": [
                                             {
                                                 "daysToKeep": 0,
                                                 "type": "kLocal",
                                             }
                                         ]
                                     }
                                 ]
                                 }
                    print("Expiring %s snapshot from %s" % (job['name'], startdate))
                    api('put', 'protectionRuns', expireRun)
                else:
                    print("Skipping %s snapshot from %s (not replicated)" % (job['name'], startdate))
            else:
                print("%s - %s" % (job['name'], startdate))
