#!/usr/bin/env python
"""expire old snapshots"""

# usage: ./expireOldSnapshots.py -v mycluster -u admin [ -d local ] -k 30 [ -e ] [ -r ]

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

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
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-y', '--daysback', type=int, default=7)
parser.add_argument('-x', '--expire', action='store_true')
parser.add_argument('-n', '--numruns', type=int, default=1000)

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
jobnames = args.jobname
joblist = args.joblist
daysback = args.daysback
expire = args.expire
numruns = args.numruns

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

# get cluster Id
# clusterId = api('get', 'cluster')['id']


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


jobnames = gatherList(jobnames, joblist, name='jobs', required=False)

jobs = api('get', 'protectionJobs')

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
daysbackUsecs = timeAgo(daysback, 'days')

print("Searching for outdated replicas...")

jobs = api('get', 'data-protect/protection-groups?isActive=false&includeTenants=true', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        v1JobId = job['id'].split(':')[2]
        print('%s' % job['name'])
        lastRunId = 0
        endUsecs = nowUsecs
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&startTimeUsecs=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=false' % (job['id'], numruns, daysbackUsecs, endUsecs), v=2)
            if len(runs['runs']) > 0:
                if 'localBackupInfo' in runs['runs'][-1]:
                    endUsecs = runs['runs'][-1]['localBackupInfo']['endTimeUsecs'] - 1
                else:
                    endUsecs = runs['runs'][-1]['originalBackupInfo']['endTimeUsecs'] - 1
                if runs['runs'][0]['id'] == lastRunId:
                    break
            else:
                break
            for run in runs['runs']:
                lastRunId = run['id']
                runStartTimeUsecs = run['originalBackupInfo']['startTimeUsecs']
                runEndTimeUsecs = run['originalBackupInfo']['endTimeUsecs']
                if 'replicationInfo' in run:
                    replEndTimeUsecs = run['replicationInfo']['replicationTargetResults'][0]['endTimeUsecs']
                    drift = replEndTimeUsecs - runStartTimeUsecs
                    if 'isLocalSnapshotsDeleted' not in run or run['isLocalSnapshotsDeleted'] is False:
                        exactRun = api('get', '/backupjobruns?exactMatchStartTimeUsecs=%s&id=%s&excludeTasks=true' % (runStartTimeUsecs, v1JobId))
                        jobUid = exactRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']
                        for task in exactRun[0]['backupJobRuns']['protectionRuns'][0]['copyRun']['finishedTasks']:
                            if task['snapshotTarget']['type'] == 1:
                                replExpiryTimeUsecs = task['expiryTimeUsecs']
                                if replExpiryTimeUsecs > 0:
                                    adjustedReplExpireTimeUsecs = replExpiryTimeUsecs - drift
                                    if adjustedReplExpireTimeUsecs < nowUsecs:  # + (2 * 86400000000)):
                                        expireRun = {
                                            "jobRuns":
                                                [
                                                    {
                                                        "expiryTimeUsecs": 0,
                                                        "jobUid": {
                                                            "clusterId": jobUid['clusterId'],
                                                            "clusterIncarnationId": jobUid['clusterIncarnationId'],
                                                            "id": jobUid['objectId'],
                                                        },
                                                        "runStartTimeUsecs": runStartTimeUsecs,
                                                        "copyRunTargets": [
                                                            {
                                                                "daysToKeep": 0,
                                                                "type": "kLocal"
                                                            }
                                                        ]
                                                    }
                                                ]
                                        }
                                        print("    %s  %s" % (usecsToDate(runStartTimeUsecs), usecsToDate(adjustedReplExpireTimeUsecs)))
                                        if expire:
                                            result = api('put', 'protectionRuns', expireRun, quiet=True)
            if endUsecs < daysbackUsecs:
                break
