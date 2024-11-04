#!/usr/bin/env python

### import Cohesity python module
from pyhesity import *
import smtplib

### command line arguments
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
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-y', '--daysback', type=int, default=7)
parser.add_argument('-x', '--maxlogbackupminutes', type=int, default=0)
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)

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
emailmfacode = args.emailmfacode
daysback = args.daysback
maxlogbackupminutes = args.maxlogbackupminutes
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

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

finishedStates = ['Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning']

nowUsecs = dateToUsecs()
daysBackUsecs = timeAgo(daysback, 'days')
maxLogBackupUsecs = maxlogbackupminutes * 60000000
cluster = api('get', 'cluster')
title = 'Missed SLAs on %s' % cluster['name']

missesRecorded = False
message = ''

# for each active job
jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true', v=2)

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    slaPass = 'Met'
    jobId = job['id']
    jobName = job['name']
    if 'sla' in job:
        sla = job['sla'][0]['slaMinutes']
        slaUsecs = sla * 60000000
        runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=2&includeTenants=true' % job['id'], v=2)
        for run in runs['runs']:
            if 'localBackupInfo' in run:
                startTimeUsecs = run['localBackupInfo']['startTimeUsecs']
                status = run['localBackupInfo']['status']
                if 'endTimeUsecs' in run['localBackupInfo']:
                    endTimeUsecs = run['localBackupInfo']['endTimeUsecs']
            else:
                startTimeUsecs = run['archivalInfo']['archivalTargetResults'][0]['startTimeUsecs']
                status = run['archivalInfo']['archivalTargetResults'][0]['status']
                if 'endTimeUsecs' in run['archivalInfo']['archivalTargetResults'][0]:
                    endTimeUsecs = run['archivalInfo']['archivalTargetResults'][0]['endTimeUsecs']
            if status in finishedStates:
                runTimeUsecs = endTimeUsecs - startTimeUsecs
            else:
                runTimeUsecs = nowUsecs - startTimeUsecs
            if not (startTimeUsecs <= daysBackUsecs and status in finishedStates):
                if status != 'Canceled':
                    if runTimeUsecs > slaUsecs:
                        slaPass = "Miss"
                        reason = "SLA: %s minutes" % sla
                    if maxlogbackupminutes > 0 and 'localBackupInfo' in run and run['localBackupInfo']['runType'] == 'kLog' and runTimeUsecs >= maxLogBackupUsecs:
                        slaPass = "Miss"
                        reason = "Log SLA: %s minutes" % maxlogbackupminutes

            runTimeMinutes = int(round((runTimeUsecs / 60000000), 0))
            if slaPass == "Miss":
                missesRecorded = True
                if status in finishedStates:
                    verb = "ran"
                else:
                    verb = "has been running"
                startTime = usecsToDate(startTimeUsecs)
                messageLine = "- %s (%s) %s for %s minutes (%s)" % (jobName, startTime, verb, runTimeMinutes, reason)
                print(messageLine)
                message += "%s\n" % messageLine
                break

if missesRecorded is False:
    print('No SLA misses recorded')
else:
    if mailserver is not None:
        msg = "Subject:%s\n\n%s" % (title, message)
        smtpserver = smtplib.SMTP(mailserver, mailport)
        smtpserver.sendmail(sendfrom, sendto, msg)
