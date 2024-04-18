#!/usr/bin/env python
"""Extend Retention using Python"""

# usage: ./extendRetention.py -s mycluster -u myusername -d mydomain.net -j 'PROD*' -j '*DEV*' \
#                             -wr 35 -w 6 -mr 365 -m 1 -ms 192.168.1.95 -mp 25 \
#                             -to myuser@mydomain.com -fr someuser@mydomain.com

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from sys import exit
from smtptool import *
import fnmatch

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobfilters', action='append', type=str, required=True)
parser.add_argument('-y', '--dayofyear', type=int, default=1)
parser.add_argument('-m', '--dayofmonth', type=int, default=1)
parser.add_argument('-w', '--dayofweek', type=int, default=6)  # Monday is 0, Sunday is 6
parser.add_argument('-yr', '--yearlyretention', type=int)
parser.add_argument('-mr', '--monthlyretention', type=int)
parser.add_argument('-wr', '--weeklyretention', type=int)
parser.add_argument('-ms', '--mailserver', type=str)
parser.add_argument('-mp', '--mailport', type=int, default=25)
parser.add_argument('-to', '--sendto', type=str)
parser.add_argument('-fr', '--sendfrom', type=str)
parser.add_argument('-r', '--includereplicas', action='store_true')
parser.add_argument('-o', '--offset', type=int, default=-8)

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
jobfilters = args.jobfilters
dayofyear = args.dayofyear
dayofmonth = args.dayofmonth
dayofweek = args.dayofweek
yearlyretention = args.yearlyretention
monthlyretention = args.monthlyretention
weeklyretention = args.weeklyretention
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom
offset = args.offset
includereplicas = args.includereplicas

log = open('extendRetentionLog.txt', 'a')
now = datetime.now()
log.write('\n\n----------------\n')
log.write('%s\n' % now.strftime("%Y-%m-%d %H:%M"))
log.write('----------------\n')

if mailserver is not None:
    if sendto is None or sendfrom is None:
        print('sendto and sendfrom parameters are required!')
        log.write('sendto and sendfrom parameters are required!\n')
        exit(1)
    smtp_connect(mailserver, mailport)

# authenticate
apiauth(vip, username, domain)

# find protectionJobs
selectedjobs = []
jobs = api('get', 'protectionJobs')
for job in jobs:
    for f in jobfilters:
        if fnmatch.fnmatch(job['name'].lower(), f.lower()):
            selectedjobs.append(job)

if len(selectedjobs) == 0:
    print('No Jobs Match Search Criteria')
    log.write('No Jobs Match Search Criteria\n')
    if mailserver is not None:
        smtp_send(sendfrom, sendto, 'extendedRetentionScript', 'No Jobs Match Search Criteria')
        smtp_disconnect()
    exit(1)

message = 'No actions taken'
lastjobname = ''

log.write('Selected Job List:\n')
for job in selectedjobs:
    log.write('\t%s\n' % job['name'])
log.write('\n')


def extendRun(job, run, retentiondays):
    global message
    global lastjobname
    runStartTimeUsecs = run['copyRun'][0]['runStartTimeUsecs']
    currentExpireTimeUsecs = run['copyRun'][0]['expiryTimeUsecs']
    newExpireTimeUsecs = runStartTimeUsecs + (retentiondays * 86400000000)
    extendByDays = dayDiff(newExpireTimeUsecs, currentExpireTimeUsecs)
    if extendByDays > 0:

        # get run date for printing
        runStartTime = datetime.strptime(usecsToDate(runStartTimeUsecs), '%Y-%m-%d %H:%M:%S')
        newExpireTimeUsecs = runStartTimeUsecs + (retentiondays * 86400000000)
        if message == 'No actions taken':
            message = ''
        if job['name'] != lastjobname:
            print('Job: %s' % job['name'])
            log.write('Job: %s\n' % job['name'])
            message = message + '\n\n Job: %s' % job['name']
            lastjobname = job['name']
        print('\t%s extending retention to %s' % (runStartTime, usecsToDate(newExpireTimeUsecs)))
        log.write('\t%s extending retention to %s\n' % (runStartTime, usecsToDate(newExpireTimeUsecs)))
        message = message + '\n' + '  %s extending retention to %s' % (runStartTime, usecsToDate(newExpireTimeUsecs))

        thisRun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&id=%s' % (run['copyRun'][0]['runStartTimeUsecs'], job['id']))
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
        if includereplicas:
            replicaRuns = [r for r in run['copyRun'] if r['target']['type'] == 'kRemote']
            for replicaRun in replicaRuns:
                runParameters['jobRuns'][0]['copyRunTargets'].append({
                    "daysToKeep": extendByDays,
                    "replicationTarget": replicaRun['target']['replicationTarget'],
                    "type": "kRemote"
                })
        api('put', 'protectionRuns', runParameters)


finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning']

for job in selectedjobs:

    for run in api('get', 'protectionRuns?jobId=%s&excludeNonRestoreableRuns=true&excludeTasks=true&runTypes=kRegular&runTypes=kFull&numRuns=1000' % job['id']):

        if run['backupRun']['snapshotsDeleted'] is False and run['copyRun'][0]['status'] in finishedStates:

            runStartTimeUsecs = run['copyRun'][0]['runStartTimeUsecs'] + ((offset + 8) * 3600000000)
            runStartTime = datetime.strptime(usecsToDate(runStartTimeUsecs), '%Y-%m-%d %H:%M:%S')
            if yearlyretention is not None:
                if runStartTime.timetuple().tm_yday == dayofyear:
                    extendRun(job, run, yearlyretention)
                    continue

            if monthlyretention is not None:
                if runStartTime.day == dayofmonth:
                    extendRun(job, run, monthlyretention)
                    continue

            if weeklyretention is not None:
                if runStartTime.weekday() == dayofweek:
                    extendRun(job, run, weeklyretention)

if mailserver is not None:
    smtp_send(sendfrom, sendto, 'extendedRetentionScript', message)
    smtp_disconnect()

if message == 'No actions taken':
    print('No actions taken')
    log.write('No actions taken\n')

log.close()
