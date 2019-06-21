#!/usr/bin/env python
"""Extend Retention using Python"""

# usage: ./extendRetention.py -v mycluster -u myusername -d mydomain.net -j 'My Job' \
#                             -wr 35 -w 6 -mr 365 -m 1 -ms 192.168.1.95 -mp 25 \
#                             -to myuser@mydomain.com -fr someuser@mydomain.com

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from smtptool import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobname', type=str, required=True)
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

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
jobname = args.jobname
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

if mailserver is not None:
    if sendto is None or sendfrom is None:
        print('sendto and sendfrom parameters are required!')
        exit(1)
    smtp_connect(mailserver, mailport)

# authenticate
apiauth(vip, username, domain)

# find protectionJob
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobname.lower()]
if not job:
    print("Job '%s' not found" % jobname)
    if mailserver is not None:
        smtp_send(sendfrom, sendto, 'extendedRetentionScript', "Script failed - Job '%s' not found" % jobname)
        smtp_disconnect()
    exit(1)

message = 'No actions taken'


def extendRun(run, retentiondays):

    global message
    runStartTimeUsecs = run['copyRun'][0]['runStartTimeUsecs']
    currentExpireTimeUsecs = run['copyRun'][0]['expiryTimeUsecs']
    newExpireTimeUsecs = runStartTimeUsecs + (retentiondays * 86400000000)
    extendByDays = dayDiff(newExpireTimeUsecs, currentExpireTimeUsecs)

    if extendByDays > 1:

        # get run date for printing
        runStartTime = datetime.strptime(usecsToDate(runStartTimeUsecs), '%Y-%m-%d %H:%M:%S')
        newExpireTimeUsecs = runStartTimeUsecs + (retentiondays * 86400000000)
        print('%s extending retention to %s' % (runStartTime, usecsToDate(newExpireTimeUsecs)))
        if message == 'No actions taken':
            message = ''
        message = message + '\n' + '%s extending retention to %s' % (runStartTime, usecsToDate(newExpireTimeUsecs))

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
        api('put', 'protectionRuns', runParameters)


for run in api('get', 'protectionRuns?jobId=%s&excludeNonRestoreableRuns=true' % job[0]['id']):

    if run['backupRun']['snapshotsDeleted'] is False:

        runStartTimeUsecs = run['copyRun'][0]['runStartTimeUsecs']
        runStartTime = datetime.strptime(usecsToDate(runStartTimeUsecs), '%Y-%m-%d %H:%M:%S')

        if yearlyretention is not None:
            if runStartTime.timetuple().tm_yday == dayofyear:
                extendRun(run, yearlyretention)
                continue

        if monthlyretention is not None:
            if runStartTime.day == dayofmonth:
                extendRun(run, monthlyretention)
                continue

        if weeklyretention is not None:
            if runStartTime.weekday() == dayofweek:
                extendRun(run, weeklyretention)

if mailserver is not None:
    smtp_send(sendfrom, sendto, 'extendedRetentionScript', message)
    smtp_disconnect()
