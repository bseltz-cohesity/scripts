#!/usr/bin/env python
"""base V1 example"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

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
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-r', '--numruns', type=int, default=1000)
parser.add_argument('-k', '--keepfor', type=int, required=True)
parser.add_argument('-b', '--backupType', type=str, choices=['kLog', 'kRegular', 'kFull', 'kSystem', 'kAll'], default='kAll')
parser.add_argument('-log', '--includelogs', action='store_true')
parser.add_argument('-o', '--olderthan', type=int, default=0)
parser.add_argument('-n', '--newerthan', type=int, default=0)
parser.add_argument('-g', '--greaterthan', type=int, default=0)
parser.add_argument('-a', '--allowreduction', action='store_true')
parser.add_argument('-x', '--commit', action='store_true')
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
numruns = args.numruns
keepfor = args.keepfor
backupType = args.backupType
includelogs = args.includelogs
olderthan = args.olderthan
newerthan = args.newerthan
greaterthan = args.greaterthan
allowreduction = args.allowreduction
commit = args.commit

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

if backupType == 'kLog':
    includelogs = True

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'archiveRetention-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')
f.write('%s,%s,%s,%s,%s,%s,%s\n' % ('Job Name', 'Run Date', 'Archive Target', 'Old Expiration', 'New Expiration', 'Action', 'Expiration Change (Days)'))

newerthanusecs = cluster['createdTimeMsecs'] * 1000
if newerthan > 0:
    newerthanusecs = timeAgo(newerthan, 'days')
olderthanusecs = nowUsecs
if olderthan > 0:
    olderthanusecs = timeAgo(olderthan, 'days')
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

jobs = api('get', 'protectionJobs')

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('\n%s' % job['name'])
        archiveRuns = {}
        endUsecs = nowUsecs
        while 1:
            runs = api('get', 'protectionRuns?jobId=%s&numRuns=%s&endTimeUsecs=%s&excludeTasks=true&excludeNonRestoreableRuns=true&runTypes=%s' % (job['id'], numruns, endUsecs, backupType))
            if len(runs) > 0:
                endUsecs = runs[-1]['backupRun']['stats']['startTimeUsecs'] - 1
            else:
                break
            for run in runs:
                try:
                    if includelogs is True or run['backupRun']['runType'] != 'kLog':
                        runStartTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
                        if runStartTimeUsecs > newerthanusecs and runStartTimeUsecs < olderthanusecs:
                            runStartTime = usecsToDate(runStartTimeUsecs, fmt='%Y-%m-%d %H:%M')
                            for copyRun in run['copyRun']:
                                if copyRun['target']['type'] == 'kArchival':
                                    # only if archive has not expired yet
                                    if 'expiryTimeUsecs' in copyRun and copyRun['expiryTimeUsecs'] > nowUsecs:
                                        currentExpireTimeUsecs = copyRun['expiryTimeUsecs']
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
                                                    thisRun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&id=%s' % (runStartTimeUsecs, job['id']))
                                                    jobUid = thisRun[0]['backupJobRuns']['jobDescription']['primaryJobUid']
                                                    # update retention of copy run
                                                    runParameters = {
                                                        "jobRuns": [
                                                            {
                                                                "jobUid": {
                                                                    "clusterId": jobUid['clusterId'],
                                                                    "clusterIncarnationId": jobUid['clusterIncarnationId'],
                                                                    "id": jobUid['objectId']
                                                                },
                                                                "runStartTimeUsecs": copyRun['runStartTimeUsecs'],
                                                                "copyRunTargets": [
                                                                    {
                                                                        "daysToKeep": extendByDays,
                                                                        "type": "kArchival",
                                                                        'archivalTarget': copyRun['target']['archivalTarget']
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    }
                                                    archiveRuns['%s:%s' % (copyRun['runStartTimeUsecs'], copyRun['target']['archivalTarget']['vaultId'])] = runParameters
                                            if extendByDays == 0:
                                                print("    %s:    %s -> %s    (%s)" % (runStartTime, usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString))
                                            elif extendByDays < 0 and allowreduction is not True:
                                                print("    %s:    %s -> %s    (%s: %s days)" % (runStartTime, usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString, extendByDays))
                                            else:
                                                print("    %s:    %s -> %s    (%s by %s days)" % (runStartTime, usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString, extendByDays))
                                        f.write('%s,%s,%s,%s,%s,%s,%s\n' % (job['name'], runStartTime, copyRun['target']['archivalTarget']['vaultName'], usecsToDate(currentExpireTimeUsecs, fmt='%Y-%m-%d'), usecsToDate(newExpireTimeUsecs, fmt='%Y-%m-%d'), actionString, extendByDays))
                except Exception:
                    pass
            if run['backupRun']['stats']['startTimeUsecs'] < newerthanusecs or run['backupRun']['stats']['startTimeUsecs'] > olderthanusecs:
                break
        # perform archive changes in chronological order
        if len(archiveRuns.keys()) > 0:
            print('    performing updates in chronological order...')
            for objectId in sorted(archiveRuns.keys()):
                runParameters = archiveRuns[objectId]
                try:
                    result = api('put', 'protectionRuns', runParameters)
                except Exception:
                    pass
f.close()
print('\nOutput saved to %s\n' % outfile)
