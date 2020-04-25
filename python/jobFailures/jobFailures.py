#!/usr/bin/env python

### usage: ./jobFailures.py -v mycluster \
#                           -u myusername \
#                           -d mydomain.net \
#                           -s mail.mydomain.net \
#                           -t me@mydomain.net \
#                           -t them@mydomain.net \
#                           -f mycluster@mydomain.net

from pyhesity import *
from datetime import datetime
import smtplib
import email.message
import email.utils
import argparse

### command line arguments
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


def spanBold(content, margin):
    return '<span style="margin-left: %spx; font-weight: normal; color: #000;">%s</span>' % (margin, content)


def span(content, color):
    return '<span style="font-weight: 300; color: #%s;">%s</span>' % (color, content)


consoleWidth = 100

### authenticate
apiauth(vip=vip, username=username, domain=domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

cluster = api('get', 'cluster')

title = 'Cohesity Failure Report (%s)' % cluster['name'].upper()

message = '<html><body style="font-family: Helvetica, Arial, sans-serif; font-size: 12px; background-color: #f1f3f6; color: #444444;">'
message += '<div style="background-color: #fff; width:fit-content; padding: 2px 6px 8px 6px; font-weight: 300; box-shadow: 1px 2px 4px #cccccc; border-radius: 4px;">'
message += '<p style="font-weight: bold;">%s Failure Report (%s)</p>' % (cluster['name'].upper(), now.date())
failureCount = 0

jobs = api('get', 'protectionJobs')

for job in jobs:
    # only jobs that are supposed to run
    if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False) and ('isPaused' not in job or job['isPaused'] is not True):
        jobId = job['id']
        jobName = job['name']
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=2' % jobId)
        # first run (or 2nd run if first run is still running)
        for run in runs:
            startTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
            status = run['backupRun']['status']
            if status == 'kFailure' or 'warnings' in run['backupRun']:
                if status == 'kFailure':
                    msgType = 'Failure'
                    msgColor = 'E2181A'
                else:
                    msgType = 'Warning'
                    msgColor = 'E5742A'
                failureCount += 1
                # report job name
                print("%s (%s) %s (%s)" % (job['name'].upper(), job['environment'][1:], (usecsToDate(run['backupRun']['stats']['startTimeUsecs'])), msgType))
                if failureCount > 1:
                    message += '<br/>'
                message += '%s <span style="font-weight: 300;">(%s) %s (</span>%s<span style="font-weight: 300; color: #000;">)</span><br/>' % (spanBold(job['name'].upper(), 0), job['environment'][1:], (usecsToDate(run['backupRun']['stats']['startTimeUsecs'])), span(msgType, msgColor))

                if 'sourceBackupStatus' in run['backupRun']:
                    for source in run['backupRun']['sourceBackupStatus']:
                        if source['status'] == 'kFailure' or 'warnings' in source:
                            if source['status'] == 'kFailure':
                                msg = source['error']
                                msgType = 'Failure'
                                msgColor = 'E2181A'
                            else:
                                msg = source['warnings'][0]
                                msgType = 'Warning'
                                msgColor = 'E5742A'
                            # report object name and error
                            objectReport = "    %s (%s): %s" % (source['source']['name'].upper(), msgType, msg)
                            if len(objectReport) > consoleWidth:
                                objectReport = '%s...' % objectReport[0: consoleWidth - 5]
                            print(objectReport)
                            if (len(msg) + len(msgType) + len(source['source']['name'])) > consoleWidth:
                                msg = '%s...' % msg[0: (consoleWidth - 10 - len(msgType) - len(source['source']['name']))]
                            message += '%s <span style="font-weight:300; color: #000;">(</span>%s<span style="font-weight: 300; color: #000;">) %s</span><br/>' % (spanBold(source['source']['name'].upper(), 40), span(msgType, msgColor), msg)
                # if the first run had an error, skip the 2nd run
                break

if failureCount == 0:
    print('No failures recorded')
else:
    message += '</div></body></html>'
    # email report
    if mailserver is not None:
        print('\nSending report to %s...' % ', '.join(sendto))
        msg = email.message.Message()
        msg['Subject'] = title
        msg['From'] = sendfrom
        msg['To'] = ','.join(sendto)
        msg.add_header('Content-Type', 'text/html')
        msg.set_payload(message)
        smtpserver = smtplib.SMTP(mailserver, mailport)
        smtpserver.sendmail(sendfrom, sendto, msg.as_string())
        smtpserver.quit()
