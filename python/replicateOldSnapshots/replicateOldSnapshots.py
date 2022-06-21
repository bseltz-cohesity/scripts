#!/usr/bin/env python
"""expire old snapshots"""

# usage: ./expireOldSnapshots.py -v mycluster -u admin [ -d local ] -k 30 [ -e ] [ -r ]

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')     # use api key for authentication
parser.add_argument('-p', '--password', type=str, default=None)   # password or api key to use
parser.add_argument('-k', '--keepfor', type=int, default=0)   # number of days to retain
parser.add_argument('-c', '--commit', action='store_true')        # perform replication
parser.add_argument('-r', '--remotecluster', type=str, required=True)  # cluster to replicate to
parser.add_argument('-j', '--jobname', action='append', type=str)  # one or more job names
parser.add_argument('-l', '--joblist', type=str, required=False)   # text file of job names
parser.add_argument('-e', '--excludelogs', action='store_true')   # exclude log backups

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
keepfor = args.keepfor
remotecluster = args.remotecluster
jobnames = args.jobname
joblist = args.joblist
excludelogs = args.excludelogs
commit = args.commit


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

# authenticate
apiauth(vip, username, domain)

# get cluster Id
clusterId = api('get', 'cluster')['id']

# get replication target info
remote = [r for r in api('get', 'remoteClusters') if r['name'].lower() == remotecluster.lower()]
if remote is None or len(remote) == 0:
    print('remote cluster %s not found' % remotecluster)
    exit(1)
else:
    remote = remote[0]

jobs = api('get', 'protectionJobs')
jobs = [j for j in jobs if 'isDeleted' not in j]

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)


for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('%s' % job['name'])
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=999999&excludeTasks=true&excludeNonRestoreableRuns=true' % job['id'])
        runs = [r for r in runs if r['backupRun']['snapshotsDeleted'] is not True]
        runs = [r for r in runs if 'endTimeUsecs' in r['backupRun']['stats']]
        if excludelogs is True:
            runs = [r for r in runs if r['backupRun']['runType'] != 'kLog']
        for run in sorted(runs, key=lambda run: run['backupRun']['stats']['startTimeUsecs']):
            daysToKeep = keepfor

            startdate = usecsToDate(run['copyRun'][0]['runStartTimeUsecs'])
            startdateusecs = run['copyRun'][0]['runStartTimeUsecs']

            # check for replication
            replicated = False
            for copyRun in run['copyRun']:
                if copyRun['target']['type'] == 'kRemote':
                    if copyRun['status'] not in ['kFailure', 'kCanceled']:
                        if copyRun['target']['replicationTarget']['clusterName'].lower() == remotecluster.lower():
                            replicated = True

            if replicated is False:
                startTimeUsecs = run['backupRun']['stats']['startTimeUsecs']

                if keepfor > 0:
                    expireTimeUsecs = startTimeUsecs + (int(keepfor * 86400000000))
                else:
                    expireTimeUsecs = run['copyRun'][0]['expiryTimeUsecs']

                now = datetime.now()
                nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
                daysToKeep = int(round((expireTimeUsecs - nowUsecs) / 86400000000, 0))
                if daysToKeep == 0:
                    daysToKeep = 1

                ### create replication task definition
                replicationTask = {
                    'jobRuns': [
                        {
                            'copyRunTargets': [
                                {
                                    "replicationTarget": {
                                        "clusterId": remote['clusterId'],
                                        "clusterName": remote['name']
                                    },
                                    'daysToKeep': int(daysToKeep),
                                    'type': 'kRemote'
                                }
                            ],
                            'runStartTimeUsecs': run['copyRun'][0]['runStartTimeUsecs'],
                            'jobUid': run['jobUid']
                        }
                    ]
                }
                if commit:
                    print('  Replicating  %s  for %s days' % (startdate, daysToKeep))
                    result = api('put', 'protectionRuns', replicationTask)
                else:
                    print('  Would replicate  %s  for %s days' % (startdate, daysToKeep))
            else:
                print('  Already replicated  %s' % startdate)
