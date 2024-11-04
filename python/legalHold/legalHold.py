#!/usr/bin/env python
"""add remove legal hold"""

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
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-n', '--numruns', type=int, default=1000)
parser.add_argument('-a', '--addhold', action='store_true')
parser.add_argument('-r', '--removehold', action='store_true')
parser.add_argument('-p', '--pushtoreplicas', action='store_true')
parser.add_argument('-l', '--includelogs', action='store_true')
parser.add_argument('-y', '--daysback', type=int, default=None)
parser.add_argument('-id', '--runid', type=int, default=None)
parser.add_argument('-rl', '--runidlist', type=str)
parser.add_argument('-dt', '--rundate', type=str, default=None)

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
jobname = args.jobname
numruns = args.numruns
addhold = args.addhold
removehold = args.removehold
pushtoreplicas = args.pushtoreplicas
includelogs = args.includelogs
daysback = args.daysback
runid = args.runid
runidlist = args.runidlist
rundate = args.rundate


def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [int(s.strip()) for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


runids = gatherList(runid, runidlist, name='runids', required=False)
minrunid = 0
if len(runids) > 0:
    minrunid = min(runids)

if (addhold is True or removehold is True) and rundate is None and len(runids) ==0:
    print('Please specify a rundate or runid when adding or removing a hold')
    exit(1)

tail = ''
if daysback is not None:
    daysBackUsecs = timeAgo(daysback, 'days')
    tail = '&startTimeUsecs=%s' % daysBackUsecs

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

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

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

jobs = api('get', 'data-protect/protection-groups?names=%s&isDeleted=false&pruneSourceIds=true&pruneExcludedSourceIds=true' % jobname, v=2)
if jobs['protectionGroups'] is None:
    print("Job '%s' not found" % jobname)
    exit(1)
job = [job for job in jobs['protectionGroups'] if job['name'].lower() == jobname.lower()]
if not job:
    print("Job '%s' not found" % jobname)
    exit(1)
else:
    job = job[0]
    v2JobId = job['id']
    v1JobId = v2JobId.split(':')[2]
    jobname = job['name']

if addhold:
    holdValue = True
    actionString = 'adding hold'
elif removehold:
    holdValue = False
    actionString = 'removing hold'
else:
    actionString = 'checking'

endUsecs = nowUsecs

while 1:
    runs = api('get', 'protectionRuns?jobId=%s&numRuns=%s&endTimeUsecs=%s&excludeTasks=true%s' % (v1JobId, numruns, endUsecs, tail))
    if len(runs) > 0:
        endUsecs = runs[-1]['backupRun']['stats']['startTimeUsecs'] - 1
    else:
        break
    if not includelogs:
        runs = [r for r in runs if r['backupRun']['runType'] != 'kLog']
    for run in runs:
        runTime = usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M')
        if rundate is not None:
            if runTime != rundate:
                if runTime < rundate and runFound is False:
                    print('    Run with start time %s not found' % rundate)
                    exit(1)
                continue
            else:
                runFound = True
        if len(runids) > 0:
            if run['backupRun']['jobRunId'] not in runids:
                continue
            else:
                runFound = True
        held = False
        copyRunsFound = False
        for copyRun in run['copyRun']:
            if pushtoreplicas is True or copyRun['target']['type'] in ['kLocal', 'kArchival']:
                if 'expiryTimeUsecs' in copyRun and copyRun['expiryTimeUsecs'] > dateToUsecs():
                    copyRunsFound = True
                if 'holdForLegalPurpose' in copyRun and copyRun['holdForLegalPurpose'] is True:
                    held = True
        if copyRunsFound is True or held is True:
            if (rundate is not None or len(runids) > 0) and ((addhold and copyRunsFound is True and held is False) or (removehold and held is True)):
                runParams = {
                    "jobRuns": [
                        {
                            "copyRunTargets": [],
                            "runStartTimeUsecs": run['backupRun']['stats']['startTimeUsecs']
                        }
                    ]
                }
                update = False
                for copyRun in run['copyRun']:
                    if pushtoreplicas is True or copyRun['target']['type'] in ['kLocal', 'kArchival']:
                        if (addhold and 'expiryTimeUsecs' in copyRun and copyRun['expiryTimeUsecs'] > dateToUsecs()) or (removehold and held is True):
                            update = True
                            copyRunTarget = copyRun['target']
                            copyRunTarget['holdForLegalPurpose'] = holdValue
                            runParams['jobRuns'][0]['copyRunTargets'].append(copyRunTarget)
                if update is True:
                    thisRun = api('get', '/backupjobruns?id=%s&exactMatchStartTimeUsecs=%s' % (run['jobId'], run['backupRun']['stats']['startTimeUsecs']))
                    jobUid = {
                        "clusterId": thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']['clusterId'],
                        "clusterIncarnationId": thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']['clusterIncarnationId'],
                        "id": thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']['objectId']
                    }
                    runParams['jobRuns'][0]['jobUid'] = jobUid
                    print('    %s - %s (%s) - %s' % (run['backupRun']['jobRunId'], usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), run['backupRun']['runType'][1:].replace('Regular', 'Incremental'), actionString))
                    result = api('put', 'protectionRuns', runParams)
            else:
                if held is True:
                    print('    %s - %s (%s) - %s' % (run['backupRun']['jobRunId'], usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), run['backupRun']['runType'][1:].replace('Regular', 'Incremental'), 'on hold'))
                if held is False:
                    print('    %s - %s (%s) - %s' % (run['backupRun']['jobRunId'], usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), run['backupRun']['runType'][1:].replace('Regular', 'Incremental'), 'not on hold'))
