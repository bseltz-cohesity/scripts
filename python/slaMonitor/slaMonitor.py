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
parser.add_argument('-b', '--maxbackuphrs', type=int, default=8)
parser.add_argument('-r', '--maxreplicationhrs', type=int, default=12)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom
maxbackuphrs = args.maxbackuphrs
maxreplicationhrs = args.maxreplicationhrs

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
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=2' % jobId)
        for run in runs:
            # get backup run time
            startTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
            status = run['backupRun']['status']
            if status in finishedStates:
                endTimeUsecs = run['backupRun']['stats']['endTimeUsecs']
                runTimeUsecs = endTimeUsecs - startTimeUsecs
            else:
                runTimeUsecs = nowUsecs - startTimeUsecs
            runTimeMinutes = int(round(runTimeUsecs / 60000000))
            runTimeHours = runTimeMinutes / 60
            # get replication time
            replHours = 0
            remoteRuns = [copyRun for copyRun in run['copyRun'] if copyRun['target']['type'] == 'kRemote']
            for remoteRun in remoteRuns:
                if 'stats' in remoteRun:
                    if 'startTimeUsecs' in remoteRun['stats']:
                        replStartTimeUsecs = remoteRun['stats']['startTimeUsecs']
                        if 'endTimeUsecs' in remoteRun['stats']:
                            replEndTimeUsecs = remoteRun['stats']['endTimeUsecs']
                            replUsecs = replEndTimeUsecs - replStartTimeUsecs
                        else:
                            replUsecs = nowUsecs - replStartTimeUsecs
                        replHours = int(round(replUsecs / 60000000)) / 60
                        if replHours > maxreplicationhrs:
                            break

            if runTimeUsecs > slaUsecs or runTimeHours > maxbackuphrs or replHours > maxreplicationhrs:
                slaPass = 'Miss'
                missesRecorded = True
                # replort sla miss
                if status in finishedStates:
                    verb = 'ran'
                else:
                    verb = 'has been running'
                messageline = '%s (Missed SLA) %s for %s minutes (SLA: %s minutes)' % (jobName, verb, runTimeMinutes, sla)
                message += '%s\n' % messageline
                print(messageline)
                # report long running replication
                if replHours >= maxreplicationhrs:
                    messageline = '                       replication time: %s hours' % replHours
                    message += '%s\n' % messageline
                    print(messageline)
                # identify long running objects
                if 'sourceBackupStatus' in run['backupRun']:
                    for source in run['backupRun']['sourceBackupStatus']:
                        if 'timeTakenUsecs' in source['stats']:
                            timeTakenUsecs = source['stats']['timeTakenUsecs']
                        else:
                            timeTakenUsecs = 0
                        if timeTakenUsecs > slaUsecs:
                            timeTakenMin = int(round(timeTakenUsecs / 60000000))
                            messageline = '                       %s %s for %s minutes' % (source['source']['name'], verb, timeTakenMin)
                            message += '%s\n' % messageline
                            print(messageline)
                break

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
