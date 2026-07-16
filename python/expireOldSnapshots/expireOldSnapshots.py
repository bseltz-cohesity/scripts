#!/usr/bin/env python
"""expire old snapshots (V2 API)"""

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
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-j', '--jobname', action='append', type=str)   # (optional) job names to inspect
parser.add_argument('-l', '--joblist', type=str)                    # (optional) text file of job names to inspect
parser.add_argument('-dt', '--date', action='append', type=str)   # (optional) dates to expire
parser.add_argument('-dl', '--datelist', type=str)                    # (optional) text file of dates to expire
parser.add_argument('-k', '--daystokeep', type=int, required=True)  # number of days of snapshots to retain
parser.add_argument('-e', '--expire', action='store_true')          # (optional) expire snapshots older than k days
parser.add_argument('-r', '--confirmreplication', action='store_true')     # (optional) confirm replication before expiring
parser.add_argument('-ac', '--activeconfirmation', action='store_true')    # (optional) active replication confirmation
parser.add_argument('-fc', '--forceconfirmation', action='store_true')
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
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
jobnames = args.jobname
joblist = args.joblist
dates = args.date
datelist = args.datelist
daystokeep = args.daystokeep
expire = args.expire
confirmreplication = args.confirmreplication
replicationtarget = args.replicationtarget
confirmarchive = args.confirmarchive
archivetarget = args.archivetarget
numruns = args.numruns
skipmonthlies = args.skipmonthlies
activeconfirmation = args.activeconfirmation
forceconfirmation = args.forceconfirmation
activeonly = args.activeonly

if activeconfirmation is True:
    confirmreplication = True

if forceconfirmation is True:
    activeconfirmation = True
    confirmreplication = True

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

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
dates = gatherList(dates, datelist, name='dates', required=False)

# V2 protection groups
jobs = api('get', 'data-protect/protection-groups', v=2)['protectionGroups']
jobs = [j for j in jobs if j.get('isDeleted') is not True]

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

# V2 protection groups don't return an 'isActive' field directly (even though it's a valid
# filter on the list endpoint), so resolve the set of active job ids up front if we need it
activeJobIds = set()
if activeonly is True:
    activeJobs = api('get', 'data-protect/protection-groups?isActive=true', v=2)['protectionGroups']
    activeJobIds = set(j['id'] for j in activeJobs)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

remoteCluster = None
if confirmreplication is True:
    remoteClusters = api('get', 'remote-clusters', v=2)['remoteClusters']
if replicationtarget is not None:
    remoteCluster = [r for r in remoteClusters if r['clusterName'].lower() == replicationtarget.lower()]
    if len(remoteCluster) == 0:
        print('remote cluster %s not found' % replicationtarget)
        exit(1)
    else:
        remoteCluster = remoteCluster[0]

print("Searching for old snapshots...")
finishedStates = ['Succeeded', 'Failed', 'SucceededWithWarning']

contexts = {}
jobLists = {}


# a run backed up directly on this cluster has 'localBackupInfo'; a run replicated in from
# another cluster has 'originalBackupInfo' instead (no 'localBackupInfo' at all)
def getRunBackupInfo(run):
    if run.get('localBackupInfo') is not None:
        return run['localBackupInfo']
    if run.get('originalBackupInfo') is not None:
        return run['originalBackupInfo']
    return None


# same local/replicated split applies per-object: 'localSnapshotInfo' for locally backed up
# objects, 'originalBackupInfo' for objects that arrived via replication
def getObjectExpiry(obj):
    localInfo = obj.get('localSnapshotInfo')
    if localInfo is not None and localInfo.get('snapshotInfo') is not None and localInfo['snapshotInfo'].get('expiryTimeUsecs') is not None:
        return localInfo['snapshotInfo']['expiryTimeUsecs']
    originalInfo = obj.get('originalBackupInfo')
    if originalInfo is not None and originalInfo.get('snapshotInfo') is not None and originalInfo['snapshotInfo'].get('expiryTimeUsecs') is not None:
        return originalInfo['snapshotInfo']['expiryTimeUsecs']
    return None


# current expiry lives per-object (there's no run-level expiry field in V2) - all objects in
# a run share the same retention, so the first object with a valid expiry is representative
def getCurrentExpiry(run):
    for obj in run.get('objects', []):
        expiry = getObjectExpiry(obj)
        if expiry is not None:
            return expiry
    return None


for job in sorted(jobs, key=lambda job: job['name'].lower()):

    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('\n%s' % job['name'])
        jobUrlId = job['id']
        endUsecs = nowUsecs
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s' % (jobUrlId, numruns, endUsecs), v=2)
            if runs is None or 'runs' not in runs or runs['runs'] is None or len(runs['runs']) == 0:
                break
            rawRuns = runs['runs']

            # figure out where the next page should end, based on the oldest run in this page
            lastRun = rawRuns[-1]
            lastBackupInfo = getRunBackupInfo(lastRun)
            if lastBackupInfo is not None:
                endUsecs = lastBackupInfo['startTimeUsecs'] - 1
            else:
                endUsecs = int(lastRun['id'].split(':')[1]) - 1

            for run in rawRuns:
                backupInfo = getRunBackupInfo(run)
                if backupInfo is None:
                    continue
                status = backupInfo.get('status')
                if status not in finishedStates:
                    continue
                startdateusecs = backupInfo['startTimeUsecs']
                startdate = usecsToDate(startdateusecs)

                # check for replication
                replicated = False
                if activeonly is not True or job['id'] in activeJobIds:
                    replicationTargetResults = (run.get('replicationInfo') or {}).get('replicationTargetResults') or []
                    for replicationTargetResult in replicationTargetResults:
                        if replicationTargetResult.get('status') == 'Succeeded' or forceconfirmation is True:
                            if replicationtarget is None or replicationTargetResult.get('clusterId') == remoteCluster['clusterId']:
                                if activeconfirmation:
                                    repltarget = replicationTargetResult.get('clusterName')
                                    if not repltarget:
                                        print('remote cluster with ID %s not found' % replicationTargetResult.get('clusterId'))
                                        exit(1)
                                    context = getContext()
                                    if repltarget not in contexts.keys():
                                        apiauth(vip=repltarget, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True, quiet=True)
                                        # exit if not authenticated
                                        if apiconnected() is False:
                                            print('authentication failed')
                                            exit(1)
                                        contexts[repltarget] = getContext()
                                        jobLists[repltarget] = api('get', 'data-protect/protection-groups', v=2)['protectionGroups']
                                    else:
                                        setContext(contexts[repltarget])
                                    repljob = [j for j in jobLists[repltarget] if j['name'] == job['name']]
                                    if repljob is not None and len(repljob) > 0:
                                        replicaRuns = api('get', 'data-protect/protection-groups/%s/runs?startTimeUsecs=%s&endTimeUsecs=%s&includeObjectDetails=true' % (repljob[0]['id'], startdateusecs - 1, startdateusecs + 1), v=2)
                                        if replicaRuns is not None and 'runs' in replicaRuns and replicaRuns['runs'] is not None:
                                            for replicaRun in replicaRuns['runs']:
                                                replicaBackupInfo = getRunBackupInfo(replicaRun)
                                                if replicaBackupInfo is not None and replicaBackupInfo.get('startTimeUsecs') == startdateusecs and replicaBackupInfo.get('status') == 'Succeeded':
                                                    replicaExpiry = getCurrentExpiry(replicaRun)
                                                    if replicaExpiry is not None and replicaExpiry > nowUsecs:
                                                        replicated = True
                                    setContext(context)
                                else:
                                    replicated = True
                else:
                    replicated = True

                # check for archive
                archived = False
                archivalTargetResults = (run.get('archivalInfo') or {}).get('archivalTargetResults') or []
                for archivalTargetResult in archivalTargetResults:
                    if archivalTargetResult.get('status') == 'Succeeded':
                        if archivetarget is None or (archivalTargetResult.get('targetName') is not None and archivalTargetResult['targetName'].lower() == archivetarget.lower()):
                            archived = True

                if startdateusecs < timeAgo(daystokeep, 'days') and run.get('isLocalSnapshotsDeleted') is not True:
                    skip = False
                    if len(dates) > 0:
                        matchingdates = [d for d in dates if d in startdate]
                        if len(matchingdates) == 0:
                            skip = True
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
                            # V2: no jobUid lookup needed (that was only ever required in V1 to
                            # resolve replicated runs); the run's own id is enough, and
                            # 'deleteSnapshot' expires it immediately without daysToKeep math.
                            expireRun = {
                                "updateProtectionGroupRunParams": [
                                    {
                                        "runId": run['id'],
                                        "replicationSnapshotConfig": {},
                                        "localSnapshotConfig": {
                                            "deleteSnapshot": True
                                        }
                                    }
                                ]
                            }
                            print("    Expiring %s" % startdate)
                            api('put', 'data-protect/protection-groups/%s/runs' % jobUrlId, expireRun, v=2)
                        else:
                            if confirmarchive is True or confirmreplication is True:
                                print("    would expire %s (remote copy confirmed)" % startdate)
                            else:
                                print("    would expire %s" % startdate)
