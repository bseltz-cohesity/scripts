#!/usr/bin/env python

### import Cohesity python module
from pyhesity import *
from datetime import datetime
import smtplib
import email.message
import email.utils

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

### authenticate
apiauth(vip, username, domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

cluster = api('get', 'cluster')
title = 'Missed SLAs on %s' % cluster['name']

missesRecorded = False
message = ''

# for each active job
jobs = api('get', 'protectionJobs')
for job in jobs:
    if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False):
        jobId = job['id']
        jobName = job['name']
        slaPass = 'Pass'
        sla = job['incrementalProtectionSlaTimeMins']
        slaUsecs = sla * 60000000
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=2&excludeTasks=true' % jobId)
        for run in runs:
            startTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
            status = run['backupRun']['status']
            if status in finishedStates:
                endTimeUsecs = run['backupRun']['stats']['endTimeUsecs']
                runTimeUsecs = endTimeUsecs - startTimeUsecs
            else:
                runTimeUsecs = nowUsecs - startTimeUsecs
            if runTimeUsecs > slaUsecs:
                slaPass = 'Miss'
            runTimeMinutes = int(round(runTimeUsecs / 60000000))
            if slaPass == 'Miss':
                missesRecorded = True
                if status in finishedStates:
                    verb = 'ran'
                else:
                    verb = 'has been running'
                messageline = '%s (Missed SLA) %s for %s minutes (SLA: %s minutes)' % (jobName, verb, runTimeMinutes, sla)
                message += '%s\n' % messageline
                print(messageline)

if missesRecorded is False:
    print('No SLA misses recorded')
else:
    # email report
    if mailserver is not None:
        print('Sending report to %s...' % ', '.join(sendto))
        msg = email.message.Message()
        msg['Subject'] = title
        msg['From'] = sendfrom
        msg['To'] = ','.join(sendto)
        msg.add_header('Content-Type', 'text')
        msg.set_payload(message)
        smtpserver = smtplib.SMTP(mailserver, mailport)
        smtpserver.sendmail(sendfrom, sendto, msg.as_string())
        smtpserver.quit()
