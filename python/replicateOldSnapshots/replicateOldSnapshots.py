#!/usr/bin/env python
"""replicate old snapshots"""

# version 2025.06.15

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
parser.add_argument('-resync_WARNING_READ_THE_README_YOU_PROBABLY_DONT_WANT_TO_DO_THIS', '--resync_WARNING_READ_THE_README_YOU_PROBABLY_DONT_WANT_TO_DO_THIS', action='store_true')        # perform replication
parser.add_argument('-r', '--remotecluster', type=str, required=True)  # cluster to replicate to
parser.add_argument('-j', '--jobname', action='append', type=str)  # one or more job names
parser.add_argument('-l', '--joblist', type=str, required=False)   # text file of job names
parser.add_argument('-e', '--excludelogs', action='store_true')   # exclude log backups
parser.add_argument('-x', '--numruns', type=int, default=1000)
parser.add_argument('-ri', '--runid', type=int, default=None)
parser.add_argument('-n', '--newerthan', type=int, default=0)     # number of days back to search for snapshots to replicate
parser.add_argument('-o', '--olderthan', type=int, default=0)     # number of days back to search for snapshots to replicate
parser.add_argument('-b', '--ifexpiringbefore', type=int, default=0)     # if expiring before X days
parser.add_argument('-a', '--ifexpiringafter', type=int, default=0)     # if expiring after X days
parser.add_argument('-rl', '--retentionlessthan', type=int, default=0)     # if retention less than X days
parser.add_argument('-rg', '--retentiongreaterthan', type=int, default=0)     # if retention greater than X days

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
resync = args.resync_WARNING_READ_THE_README_YOU_PROBABLY_DONT_WANT_TO_DO_THIS
numruns = args.numruns
runid = args.runid
newerthan = args.newerthan
olderthan = args.olderthan
ifexpiringbefore = args.ifexpiringbefore
ifexpiringafter = args.ifexpiringafter
retentionlessthan = args.retentionlessthan
retentiongreaterthan = args.retentiongreaterthan

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
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

# get cluster Id
clusterId = api('get', 'cluster')['id']

newerthanUsecs = timeAgo(newerthan, 'days')
olderthanUsecs = timeAgo(olderthan, 'days')
expiringbeforeusecs = timeAgo(-ifexpiringbefore, 'days')
expiringafterusecs = timeAgo(-ifexpiringafter, 'days')
retentiongreaterthanusecs = retentiongreaterthan * (86400000000)
retentionlessthanusecs = retentionlessthan * (86400000000)

# get replication target info
remote = [r for r in api('get', 'remoteClusters') if r['name'].lower() == remotecluster.lower()]
if remote is None or len(remote) == 0:
    print('remote cluster %s not found' % remotecluster)
    exit(1)
else:
    remote = remote[0]

jobs = api('get', 'data-protect/protection-groups', v=2)
jobs = [j for j in jobs['protectionGroups']]  # if 'isDeleted' not in j or j['isDeleted'] is not True]

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
policies = api('get', 'data-protect/policies', v=2)

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('%s' % job['name'])
        if 'isActive' in job and job['isActive'] == True and keepfor == 0:
            policy = [p for p in policies['policies'] if p['id'] == job['policyId']]
            if len(policy) > 0:
                policy = policy[0]
                if 'remoteTargetPolicy' in policy and policy['remoteTargetPolicy'] is not None and 'replicationTargets' in policy['remoteTargetPolicy'] and policy['remoteTargetPolicy']['replicationTargets'] is not None:
                    replicationTarget = [t for t in policy['remoteTargetPolicy']['replicationTargets'] if t['targetType'] == 'RemoteCluster' and t['remoteTargetConfig']['clusterName'].lower() == remotecluster.lower()]
                    if len(replicationTarget) > 0:
                        frequent = [t for t in replicationTarget if t['schedule']['unit'] == 'Runs']
                        if len(frequent) == 0:
                           frequent = [t for t in replicationTarget if t['schedule']['unit'] == 'Days']
                        if len(frequent) == 0:
                           frequent = [t for t in replicationTarget if t['schedule']['unit'] == 'Weeks']
                        if len(frequent) == 0:
                           frequent = [t for t in replicationTarget if t['schedule']['unit'] == 'Months']
                        if len(frequent) == 0:
                           frequent = [t for t in replicationTarget if t['schedule']['unit'] == 'Years']
                        if len(frequent) > 0:
                            retention = frequent[0]['retention']
                            retentionduration = retention['duration']
                            retentionunit = retention['unit']
                            if retentionunit == 'Weeks':
                                retentionduration = retentionduration * 7
                            if retentionunit == 'Months':
                                retentionduration = retentionduration * 30
                            if retentionunit == 'Years':
                                retentionduration = retentionduration * 365
                            print('  ** using policy retention of %s days **' % retentionduration)
                            keepfor = retentionduration

        jobident = job['id'].split(':')
        jobuid = {
            "clusterId": int(jobident[0]),
            "clusterIncarnationId": int(jobident[1]),
            "id": int(jobident[2])
        }
        runstoreplicate = {}
        endUsecs = nowUsecs
        if olderthan > 0:
            endUsecs = olderthanUsecs
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true' % (job['id'], numruns, endUsecs), v=2)
            if len(runs['runs']) > 0:
                endUsecs = int(runs['runs'][-1]['id'].split(':')[1]) - 1
            else:
                break
            runs = [r for r in runs['runs'] if 'isLocalSnapshotsDeleted' not in r or r['isLocalSnapshotsDeleted'] is not True]
            if runs is not None and len(runs) > 0:
                runs = [r for r in runs if ('localBackupInfo' in r and 'endTimeUsecs' in r['localBackupInfo']) or ('originalBackupInfo' in r and 'endTimeUsecs' in r['originalBackupInfo'])]
            if runs is not None and len(runs) > 0 and excludelogs is True:
                runs = [r for r in runs if ('localBackupInfo' in r and r['localBackupInfo']['runType'] != 'kLog') or ('originalBackupInfo') in r and r['originalBackupInfo']['runType'] != 'kLog']
            if runs is not None and len(runs) > 0:
                for run in sorted(runs, key=lambda run: run['id']):
                    thisrun = None
                    if runid is not None and run['protectionGroupInstanceId'] != runid:
                        continue
                    daysToKeep = keepfor
                    startdateusecs = int(run['id'].split(':')[1])
                    startdate = usecsToDate(startdateusecs)
                    if newerthan > 0 and startdateusecs < newerthanUsecs:
                        continue
                       
                    # check for replication
                    replicated = False
                    if 'replicationInfo' in run:
                        if 'replicationTargetResults' in run['replicationInfo'] and len(run['replicationInfo']['replicationTargetResults']) > 0:
                            for replicationTargetResult in run['replicationInfo']['replicationTargetResults']:
                                if 'clusterName' in replicationTargetResult and replicationTargetResult['clusterName'].lower() == remotecluster.lower() and replicationTargetResult['status'] in ['Succeeded', 'Running', 'Accepted', 'Canceling']:
                                    replicated = True
                                    if resync and replicationTargetResult['clusterName'].lower() == remotecluster.lower() and replicationTargetResult['status'] == 'Succeeded':
                                        replicated = False

                    if ifexpiringbefore > 0 or ifexpiringafter > 0 or retentiongreaterthan > 0 or retentionlessthan > 0:
                        thisrun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&excludeTasks=true&id=%s' % (startdateusecs, jobuid['id']))
                        expireTimeUsecs = thisrun[0]['backupJobRuns']['protectionRuns'][0]['copyRun']['finishedTasks'][0]['expiryTimeUsecs']

                        if ifexpiringbefore > 0 and expireTimeUsecs >= expiringbeforeusecs:
                            continue
                        if ifexpiringafter > 0 and expireTimeUsecs <= expiringafterusecs:
                            continue
                        if retentiongreaterthan > 0 and (expireTimeUsecs - startdateusecs) <= retentiongreaterthanusecs:
                            continue
                        if retentionlessthan > 0 and (expireTimeUsecs - startdateusecs) >= retentionlessthanusecs:
                            continue

                    if replicated is False:
                        startTimeUsecs = startdateusecs
                        if keepfor > 0:
                            expireTimeUsecs = startTimeUsecs + (int(keepfor * 86400000000))
                        else:
                            if thisrun is None:
                                thisrun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&excludeTasks=true&id=%s' % (startdateusecs, jobuid['id']))
                                expireTimeUsecs = thisrun[0]['backupJobRuns']['protectionRuns'][0]['copyRun']['finishedTasks'][0]['expiryTimeUsecs']
                        daysToKeep = int(round((expireTimeUsecs - nowUsecs) / 86400000000, 0)) + 1
                        if daysToKeep == 0:
                            daysToKeep = 1
                        if commit:
                            # create replication task definition
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
                                        'runStartTimeUsecs': startdateusecs,
                                        'jobUid': jobuid
                                    }
                                ]
                            }
                            print('  Replicating  %s  for %s days' % (startdate, daysToKeep))
                            runstoreplicate[startdateusecs] = replicationTask
                        else:
                            print('  Would replicate  %s (%s)  for %s days' % (startdate, run['protectionGroupInstanceId'], daysToKeep))
                        # display(run)
                    else:
                        print('  Already replicated  %s' % startdate)
        if len(runstoreplicate.keys()) > 0:
            print('  Committing replications...')
        for rundate in sorted(runstoreplicate.keys()):
            result = api('put', 'protectionRuns', runstoreplicate[rundate])
