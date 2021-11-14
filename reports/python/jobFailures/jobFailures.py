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

consoleWidth = 100

### authenticate
apiauth(vip=vip, username=username, domain=domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

cluster = api('get', 'cluster')

title = 'Cohesity Failure Report (%s)' % cluster['name'].upper()

message = '''<html>
<head>
    <style>
        body {
            font-family: Helvetica, Arial, sans-serif;
            font-size: 12px;
            background-color: #f1f3f6;
            color: #444444;
            overflow: auto;
        }

        div {
            clear: both;
        }

        ul {
            displa-block;
            margin: 2px; 2px; 2px; -5px;
        }

        li {
            margin-left: -25px;
            margin-bottom: 2px;
        }

        #wrapper {
            background-color: #fff;
            width: fit-content;
            padding: 2px 6px 8px 6px;
            font-weight: 300;
            box-shadow: 1px 2px 4px #cccccc;
            border-radius: 4px;
        }

        .title {
            font-weight: bold;
        }

        .jobname {
            margin-left: 0px;
            font-weight: normal;
            color: #000;
        }

        .info {
            font-weight: 300;
            color: #000;
        }

        .Warning {
            font-weight: normal;
            color: #E5742A;
        }

        .Failure {
            font-weight: normal;
            color: #E2181A;
        }

        .object {
            margin: 4px 0px 2px 20px;
            font-weight: normal;
            color: #000;
            text-decoration: none;
        }

        .message {
            font-weight: 300;
            font-size: 11px;
            background-color: #f1f3f6;
            padding: 4px 6px 4px 6px;
            margin: 3px 3px 7px 15px;
            line-height: 1.5em;
            border-radius: 4px;
            box-shadow: 1px 2px 4px #cccccc;
        }
    </style>
</head>

<body>
    <div id="wrapper">'''

message += '<p class="title">%s Failure Report (%s)</p>' % (cluster['name'].upper(), now.date())

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
                else:
                    msgType = 'Warning'
                failureCount += 1
                # report job name
                link = 'https://%s/protection/job/%s/run/%s/%s/protection' % (vip, jobId, run['backupRun']['jobRunId'], run['backupRun']['stats']['startTimeUsecs'])
                print("%s (%s) %s" % (job['name'].upper(), job['environment'][1:], (usecsToDate(run['backupRun']['stats']['startTimeUsecs']))))
                if failureCount > 1:
                    message += '<br/>'
                message += '<div class="jobname"><span>%s</span><span class="info"> (%s) <a href="%s" target="_blank">%s</a> </span></div>' % (job['name'].upper(), job['environment'][1:], link, (usecsToDate(run['backupRun']['stats']['startTimeUsecs'])))
                if 'sourceBackupStatus' in run['backupRun']:
                    message += '<div class="object">'
                    for source in run['backupRun']['sourceBackupStatus']:
                        if source['status'] == 'kFailure' or 'warnings' in source:
                            if source['status'] == 'kFailure':
                                msg = source['error']
                                msghtml = '<ul><li>%s</li></ul>' % source['error']
                                msgType = 'Failure'
                            else:
                                msg = source['warnings'][0]
                                msghtml = '<ul><li>%s</li></ul>' % '</li><li>'.join(source['warnings'])
                                msgType = 'Warning'
                            # report object name and error
                            objectReport = "    %s (%s): %s" % (source['source']['name'].upper(), msgType, msg)
                            if len(objectReport) > consoleWidth:
                                objectReport = '%s...' % objectReport[0: consoleWidth - 5]
                            print(objectReport)
                            message += '<span>%s</span><span class="info"> (<span class="%s">%s</span>)</span><div class="message">%s</div>' % (source['source']['name'].upper(), msgType, msgType, msghtml)
                    message += '</div>'
                # if the first run had an error, skip the 2nd run
                break

if failureCount == 0:
    print('No failures recorded')
else:
    message += '</div></body></html>'
    f = open('report.html', 'w')
    f.write(message)
    f.close()
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
