#!/usr/bin/env python
"""change local retention (V2 API)"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-r', '--numruns', type=int, default=1000)
parser.add_argument('-k', '--keepfor', type=int, required=True)
parser.add_argument('-t', '--backupType', type=str, choices=['kLog', 'kRegular', 'kFull', 'kSystem', 'AllExceptLogs'], default='AllExceptLogs')
parser.add_argument('-log', '--includelogs', action='store_true')
parser.add_argument('-o', '--olderthan', type=int, default=0)
parser.add_argument('-n', '--newerthan', type=int, default=0)
parser.add_argument('-g', '--greaterthan', type=int, default=0)
parser.add_argument('-a', '--allowreduction', action='store_true')
parser.add_argument('-id', '--runid', type=int, default=None)
parser.add_argument('-dt', '--rundate', type=str, default=None)
parser.add_argument('-x', '--commit', action='store_true')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
jobnames = args.jobname
joblist = args.joblist
numruns = args.numruns
keepfor = args.keepfor
backupType = args.backupType
includelogs = args.includelogs
olderthan = args.olderthan
newerthan = args.newerthan
greaterthan = args.greaterthan
allowreduction = args.allowreduction
runid = args.runid
rundate = args.rundate
commit = args.commit

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

if backupType == 'kLog':
    includelogs = True

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'retention-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')
f.write('%s,%s,%s,%s,%s,%s,%s,%s\n' % ('Job Name', 'Run ID', 'Run Date', 'Run Type', 'Old Expiration', 'New Expiration', 'Action', 'Expiration Change (Days)'))

newerthanusecs = cluster['createdTimeMsecs'] * 1000
if newerthan > 0:
    newerthanusecs = timeAgo(newerthan, 'days')
olderthanusecs = nowUsecs
if olderthan > 0:
    olderthanusecs = timeAgo(olderthan, 'days')
    nowUsecs = olderthanusecs
if greaterthan > 0:
    greaterthanusecs = greaterthan * 86400000000


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

# V2 protection groups
jobs = api('get', 'data-protect/protection-groups', v=2)['protectionGroups']
jobs = [j for j in jobs if j.get('isDeleted') is not True]

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

# V1's 'kRegular' run type is called 'kIncremental' in the V2 API
myBackupType = 'kIncremental,kFull,kSystem'
if backupType == 'kRegular':
    myBackupType = 'kIncremental'
elif backupType != 'AllExceptLogs':
    myBackupType = backupType


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


for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('\n%s' % job['name'])
        jobUrlId = job['id']
        endUsecs = nowUsecs
        runFound = False
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&excludeNonRestorableRuns=true&includeObjectDetails=true&runTypes=%s' % (jobUrlId, numruns, endUsecs, myBackupType), v=2)
            if runs is None or 'runs' not in runs or runs['runs'] is None or len(runs['runs']) == 0:
                break
            rawRuns = runs['runs']

            # figure out where the next page should end, based on the oldest run in this page
            # (regardless of whether it's one we'll actually process below)
            lastRun = rawRuns[-1]
            lastRunBackupInfo = getRunBackupInfo(lastRun)
            if lastRunBackupInfo is not None:
                endUsecs = lastRunBackupInfo['startTimeUsecs'] - 1
            else:
                endUsecs = int(lastRun['id'].split(':')[1]) - 1

            for run in rawRuns:
                try:
                    # runs backed up locally have 'localBackupInfo'; runs replicated in from
                    # another cluster have 'originalBackupInfo' instead - both are relevant here
                    backupInfo = getRunBackupInfo(run)
                    if backupInfo is None:
                        continue
                    if run.get('isLocalSnapshotsDeleted') is True:
                        continue

                    runType = backupInfo.get('runType', 'kUnknown')[1:]
                    runStartTimeUsecs = backupInfo['startTimeUsecs']
                    runTime = usecsToDate(runStartTimeUsecs, fmt='%Y-%m-%d %H:%M')
                    runIdentifier = run.get('protectionGroupInstanceId', run['id'])

                    if rundate is not None:
                        if runTime != rundate:
                            if runTime < rundate and runFound is False:
                                print('    Run with start time %s not found' % rundate)
                                exit(1)
                            continue
                        else:
                            runFound = True
                    if runid is not None:
                        if runIdentifier != runid:
                            if isinstance(runIdentifier, int) and runIdentifier < runid and runFound is False:
                                print('    Run with ID %s not found' % runid)
                                exit(1)
                            continue
                        else:
                            runFound = True

                    if includelogs is True or runType != 'Log':
                        if runStartTimeUsecs > newerthanusecs and runStartTimeUsecs < olderthanusecs:
                            # current expiry lives per-object (there's no run-level expiry field
                            # in V2) - all objects in a run share the same retention, so the first
                            # object with a valid expiry is representative
                            currentExpireTimeUsecs = None
                            for obj in run.get('objects', []):
                                expiry = getObjectExpiry(obj)
                                if expiry is not None:
                                    currentExpireTimeUsecs = expiry
                                    break
                            if currentExpireTimeUsecs is None:
                                continue

                            retentionUsecs = currentExpireTimeUsecs - runStartTimeUsecs
                            if greaterthan == 0 or retentionUsecs > (greaterthanusecs + 3600000000):
                                newExpireTimeUsecs = runStartTimeUsecs + (keepfor * 86400000000)
                                extendByDays = dayDiff(newExpireTimeUsecs, currentExpireTimeUsecs)
                                actionString = ''
                                if allowreduction is False and extendByDays < 0:
                                    actionString = 'reduction disallowed'
                                if extendByDays == 0:
                                    actionString = 'no change'
                                if (allowreduction is True and extendByDays < 0) or extendByDays > 0:
                                    if extendByDays > 0:
                                        actionString = 'would extend'
                                    else:
                                        actionString = 'would reduce'
                                    if commit:
                                        if extendByDays > 0:
                                            actionString = 'extended'
                                        else:
                                            actionString = 'reduced'
                                        # V2 update: no jobUid lookup needed (that was only ever
                                        # required in V1 to resolve replicated runs); the run's
                                        # own id is enough to target the update.
                                        runParameters = {
                                            "updateProtectionGroupRunParams": [
                                                {
                                                    "runId": run['id'],
                                                    "replicationSnapshotConfig": {},
                                                    "localSnapshotConfig": {
                                                        "daysToKeep": extendByDays
                                                    }
                                                }
                                            ]
                                        }
                                        result = api('put', 'data-protect/protection-groups/%s/runs' % jobUrlId, runParameters, v=2)
                                if extendByDays == 0:
                                    print("    %s - %s (%-17s%s -> %s    (%s)" % (runIdentifier, runTime, runType + '):', usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString))
                                elif extendByDays < 0 and allowreduction is not True:
                                    print("    %s - %s (%-17s%s -> %s    (%s: %s days)" % (runIdentifier, runTime, runType + '):', usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString, extendByDays))
                                else:
                                    print("    %s - %s (%-17s%s -> %s    (%s by %s days)" % (runIdentifier, runTime, runType + '):', usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString, extendByDays))
                                f.write('%s,%s,%s,%s,%s,%s,%s,%s\n' % (job['name'], runIdentifier, runTime, runType, usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString, extendByDays))
                except Exception:
                    print('an error occurred')

            if endUsecs < newerthanusecs:
                break

f.close()
print('\nOutput saved to %s\n' % outfile)
