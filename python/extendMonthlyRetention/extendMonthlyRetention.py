#!/usr/bin/env python
"""Extend Monthly Snapshot using Python"""

# usage: ./extendMonthlyRetention.py -v mycluster -u myusername -d mydomain.net -j 'My Job' -k 365 -m 1

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobName', type=str, required=True)
parser.add_argument('-m', '--dayOfMonth', type=int, default=1)
parser.add_argument('-k', '--daysToKeep', type=int, required=True)
parser.add_argument('-e', '--extend', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobName = args.jobName
dayOfMonth = args.dayOfMonth
daysToKeep = args.daysToKeep
extend = args.extend

# authenticate
apiauth(vip, username, domain)

# find protectionJob
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
if not job:
    print("Job '%s' not found" % jobName)
    exit()


def extendRun(run, extendByDays):
    """extend run function"""

    # mark run found
    global foundMonthly
    foundMonthly = True

    # get run date for printing
    runStartTimeUsecs = run['copyRun'][0]['runStartTimeUsecs']
    runStartTime = datetime.strptime(usecsToDate(runStartTimeUsecs), '%Y-%m-%d %H:%M:%S')
    newExpireTimeUsecs = runStartTimeUsecs + (daysToKeep * 86400000000)

    # if run needs to be extended, extend it
    if extendByDays > 0:
        if extend is True:
            print('%s extending retention to %s' % (runStartTime, usecsToDate(newExpireTimeUsecs)))
        else:
            print('would extend %s retention to %s' % (runStartTime, usecsToDate(newExpireTimeUsecs)))

        # get originating cluster jobUid
        thisRun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&id=%s' % (run['copyRun'][0]['runStartTimeUsecs'], job[0]['id']))
        jobUid = thisRun[0]['backupJobRuns']['jobDescription']['primaryJobUid']

        # update retention of job run
        runParameters = {
            "jobRuns": [
                {
                    "jobUid": {
                        "clusterId": jobUid['clusterId'],
                        "clusterIncarnationId": jobUid['clusterIncarnationId'],
                        "id": jobUid['objectId']
                    },
                    "runStartTimeUsecs": run['copyRun'][0]['runStartTimeUsecs'],
                    "copyRunTargets": [
                        {
                            "daysToKeep": extendByDays,
                            "type": "kLocal"
                        }
                    ]
                }
            ]
        }
        if extend is True:
            api('put', 'protectionRuns', runParameters)
    else:
        print('%s already extended to %s' % (runStartTime, usecsToDate(newExpireTimeUsecs)))


# calculate target run date
now = datetime.now()
nowUsecs = dateToUsecs(now.strftime('%Y-%m-%d %H:%M:%S'))
if dayOfMonth <= 0:
    if dayOfMonth == 0:
        dayOfMonth = -1
    firstOfThisMonth = now.replace(day=1)
    targetDate = firstOfThisMonth + timedelta(days=dayOfMonth)
else:
    thisMonth = now.replace(day=dayOfMonth)
    lastMonth = (now.replace(day=1) - timedelta(days=1)).replace(day=dayOfMonth)
    if thisMonth > now:
        targetDate = lastMonth
    else:
        targetDate = thisMonth

foundMonthly = False
alternateRun = None

for run in api('get', 'protectionRuns?jobId=%s&runTypes=kRegular&runTypes=kFull' % job[0]['id']):
    if foundMonthly is True:
        exit()

    status = run['backupRun']['status']
    if status in ['kSuccess', 'kWarning'] and 'copyRun' in run and len(run['copyRun']) > 0 and 'expiryTimeUsecs' in run['copyRun'][0]:
        # get run date
        runStartTimeUsecs = run['copyRun'][0]['runStartTimeUsecs']
        runStartTime = datetime.strptime(usecsToDate(runStartTimeUsecs), '%Y-%m-%d %H:%M:%S')

        # calculate days to extend run
        currentExpireTimeUsecs = run['copyRun'][0]['expiryTimeUsecs']
        newExpireTimeUsecs = runStartTimeUsecs + (daysToKeep * 86400000000)
        extendByDays = dayDiff(newExpireTimeUsecs, currentExpireTimeUsecs)

        # confirm run hasn't expired yet and was successful
        if currentExpireTimeUsecs > nowUsecs and (status == 'kSuccess' or status == 'kWarning'):
            if runStartTime.day == dayOfMonth:
                extendRun(run, extendByDays)

            # store following run as alternate if specified date didn't run
            if foundMonthly is False and runStartTime > targetDate:
                alternateRun = run
                alternateExtendByDays = extendByDays

# extend alternate run if specified run wan't found
if foundMonthly is False:
    if alternateRun is not None:
        extendRun(alternateRun, alternateExtendByDays)

# report no runs found (only when job has been running for less than one month)
if foundMonthly is False:
    print('No job runs to extend')
