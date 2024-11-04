#!/usr/bin/env python
"""expire old snapshots"""

# usage: ./expireOldSnapshots.py -v mycluster -u admin [ -d local ] -k 30 [ -e ] [ -r ]

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # (optional) password
parser.add_argument('-j', '--jobname', action='append', type=str)   # (optional) job names to inspect
parser.add_argument('-l', '--joblist', type=str)                    # (optional) text file of job names to inspect
parser.add_argument('-k', '--daystokeep', type=int, required=True)  # number of days of snapshots to retain
parser.add_argument('-e', '--expire', action='store_true')          # (optional) expire snapshots older than k days
parser.add_argument('-r', '--confirmreplication', action='store_true')     # (optional) confirm replication before expiring
parser.add_argument('-ac', '--activeconfirmation', action='store_true')    # (optional) active replication confirmation
parser.add_argument('-ao', '--activeonly', action='store_true')  # (optional) skip confirmations for inactive jobs 
parser.add_argument('-rt', '--replicationtarget', type=str, default=None)  # (optional) replication target to confirm
parser.add_argument('-a', '--confirmarchive', action='store_true')     # (optional) confirm archival before expiring
parser.add_argument('-at', '--archivetarget', type=str, default=None)  # (optional) archive target to confirm
parser.add_argument('-n', '--numruns', type=int, default=1000)      # (optional) page size per API call
parser.add_argument('-s', '--skipmonthlies', action='store_true')   # skip snapshots that land on the first of the month
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
jobnames = args.jobname
joblist = args.joblist
daystokeep = args.daystokeep
expire = args.expire
confirmreplication = args.confirmreplication
replicationtarget = args.replicationtarget
confirmarchive = args.confirmarchive
archivetarget = args.archivetarget
numruns = args.numruns
skipmonthlies = args.skipmonthlies
activeconfirmation = args.activeconfirmation
activeonly = args.activeonly

if activeconfirmation is True:
    confirmreplication = True

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

# get cluster Id
clusterId = api('get', 'cluster')['id']


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

print("Searching for old snapshots...")
finishedStates = ['kSuccess', 'kFailure', 'kWarning']

contexts = {}
jobLists = {}

for job in sorted(jobs, key=lambda job: job['name'].lower()):

    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('\n%s' % job['name'])
        endUsecs = nowUsecs
        while 1:
            runs = api('get', 'protectionRuns?jobId=%s&numRuns=%s&endTimeUsecs=%s&excludeTasks=true' % (job['id'], numruns, endUsecs))
            if len(runs) > 0:
                endUsecs = runs[-1]['backupRun']['stats']['startTimeUsecs'] - 1
            else:
                break
            for run in runs:
                if 'backupRun' in run:
                    status = run['backupRun']['status']
                    if status in finishedStates:
                        startdate = usecsToDate(run['backupRun']['stats']['startTimeUsecs'])
                        startdateusecs = run['backupRun']['stats']['startTimeUsecs']
                    else:
                        continue
                elif 'copyRun' in run and len(run['copyRun']) > 0:
                    status = run['copyRun'][0]['status']
                    if status in finishedStates:
                        startdate = usecsToDate(run['copyRun'][0]['runStartTimeUsecs'])
                        startdateusecs = run['copyRun'][0]['runStartTimeUsecs']
                    else:
                        continue
                # check for replication
                replicated = False
                if activeonly is not True or 'isActive' not in job or job['isActive'] is True:
                    for copyRun in run['copyRun']:
                        if copyRun['target']['type'] == 'kRemote':
                            if copyRun['status'] == 'kSuccess':
                                if replicationtarget is None or ('clusterName' in copyRun['target']['replicationTarget'] and copyRun['target']['replicationTarget']['clusterName'].lower() == replicationtarget.lower()):
                                    if activeconfirmation:
                                        repltarget = copyRun['target']['replicationTarget']['clusterName']
                                        context = getContext()
                                        if repltarget not in contexts.keys():
                                            apiauth(vip=repltarget, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True, quiet=True)
                                            # exit if not authenticated
                                            if apiconnected() is False:
                                                print('authentication failed')
                                                exit(1)
                                            contexts[repltarget] = getContext()
                                            jobLists[repltarget] = api('get', 'protectionJobs')
                                        else:
                                            setContext(contexts[repltarget])
                                        repljob = [j for j in jobLists[repltarget] if j['name'] == job['name']]
                                        if repljob is not None and len(repljob) > 0:
                                            replicaRun = api('get', 'protectionRuns?startedTimeUsecs=%s&jobId=%s' % (startdateusecs, repljob[0]['id']))
                                            if replicaRun is not None and len(replicaRun) > 0:
                                                for replicaCopyRun in replicaRun[0]['copyRun']:
                                                    if replicaCopyRun['target']['type'] == 'kLocal':
                                                        if replicaCopyRun['expiryTimeUsecs'] > nowUsecs and replicaCopyRun['status'] == 'kSuccess':
                                                            replicated = True
                                        setContext(context)
                                    else:    
                                        replicated = True
                else:
                    replicated = True

                # check for archive
                archived = False
                for copyRun in run['copyRun']:
                    if copyRun['target']['type'] == 'kArchival':
                        if copyRun['status'] == 'kSuccess':
                            if archivetarget is None or ('vaultName' in copyRun['target']['archivalTarget'] and copyRun['target']['archivalTarget']['vaultName'].lower() == archivetarget.lower()):
                                archived = True

                if startdateusecs < timeAgo(daystokeep, 'days') and run['backupRun']['snapshotsDeleted'] is False:
                    skip = False
                    if replicated is False and confirmreplication is True:
                        skip = True
                        if replicationtarget is not None:
                            print("    Skipping %s (not replicated to %s)" % (startdate, replicationtarget))
                        else:
                            print("    Skipping %s (not replicated)" % startdate)
                    elif archived is False and confirmarchive is True:
                        skip = True
                        if archivetarget is not None:
                            print("    Skipping %s (not archived to %s)" % (startdate, archivetarget))
                        else:
                            print("    Skipping %s (not archived)" % startdate)
                    startdatetime = datetime.strptime(startdate, '%Y-%m-%d %H:%M:%S')
                    if skipmonthlies is True and startdatetime.day == 1:
                        skip = True
                        print("    Skipping %s (monthly)" % startdate)
                    if skip is False:
                        if expire:
                            exactRun = api('get', '/backupjobruns?exactMatchStartTimeUsecs=%s&id=%s' % (startdateusecs, job['id']))
                            jobUid = exactRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']
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
                            print("    Expiring %s" % startdate)
                            api('put', 'protectionRuns', expireRun)
                        else:
                            print("    %s" % startdate)
