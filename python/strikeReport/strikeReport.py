#!/usr/bin/env python
"""Backup Strike Report v2.0"""

# usage: ./strikeReport.py -v mycluster \
#                          -u myusername \
#                          -d mydomain.net \
#                          -t myuser@mydomain.net \
#                          -s 192.168.1.95 \
#                          -f backupreport@mydomain.net

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import re

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)
parser.add_argument('-dy', '--days', type=int, default=31)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom
days = args.days


def cleanhtml(raw_html):
    cleanr = re.compile('<.*?>')
    cleantext = re.sub(cleanr, '', raw_html)
    return cleantext


# authenticate
apiauth(vip, username, domain)

environments = ['kUnknown', 'kVMware', 'kHyperV', 'kSQL', 'kView', 'kRemote Adapter',
                'kPhysical', 'kPure', 'kAzure', 'kNetapp', 'kAgent', 'kGenericNas',
                'kAcropolis', 'kPhysical Files', 'kIsilon', 'kKVM', 'kAWS', 'kExchange',
                'kHyperVVSS', 'kOracle', 'kGCP', 'kFlashBlade', 'kAWSNative', 'kVCD',
                'kO365', 'kO365 Outlook', 'kHyperFlex', 'kGCP Native', 'kAzure Native',
                'kAD', 'kAWS Snapshot Manager', 'kFuture', 'kFuture', 'kFuture']

runType = ['kRegular', 'kFull', 'kLog', 'kSystem']

print('Collecting report data...')

cluster = api('get', 'cluster')

title = 'Backup Strike Report (%s)' % cluster['name']
now = datetime.now()
date = now.strftime("%m/%d/%Y %H:%M:%S")

html = '''<html>
<head>
    <style>
        p {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        span {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }

        table {
            font-family: Arial, Helvetica, sans-serif;
            color: #333333;
            font-size: 0.75em;
            border-collapse: collapse;
            width: 100%;
        }

        tr {
            border: 1px solid #F1F1F1;
        }

        td,
        th {
            text-align: left;
            padding: 6px;
        }

        tr:nth-child(even) {
            background-color: #F1F1F1;
        }
    </style>
</head>
<body>

    <div style="margin:15px;">
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAARgAAAAoCAMAAAASXRWnAAAC8VBMVE
            WXyTz///+XyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTwJ0VJ2AAAA+nRSTlMAAAECAwQFBgcICQoLDA0ODxARExQVFhcYGRobHB0eHy
            EiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj9AQUNERUZHSElKS0xNTk9QUVJTVFVWV1hZWl
            tcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9foCBgoOEhYaHiImKi4yNjo+QkZKTlJ
            WWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc
            7Q0dLT1NXW19jZ2tvc3d7f4OHi4+Xm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+drbbjAAACOZJRE
            FUaIHtWmlcVUUUv6alIgpiEGiZZIpiKu2i4obhUgipmGuihuZWiYmkRBu4JJVappaG5VJRUWrllq
            ZWivtWVuIWllHwShRI51PvnjP33pk7M1d579Gn/j8+zDnnf2b5v3tnu2g1/ocUmvuPRasx83cVu1
            zFB5endtWUCHgoM/+0y1V64sOZcXVlhMDpWXdLM+PmPnmdZTVJeLCPiL6Jd9jT6nfo2y+hH4vE/h
            Fcj6bP6uhcqxvxfYzOdsxOb6gYm39qdrRmE6bBxB2EQWHOXfLBvVvMsIqWdBEYzYvcgWRJ6nS3f5
            +/YSWXEQVeYJPqpXx5XkaaalFuOu22h2E5UVkrIadaAyXFXTwbKh1cw0J3bCgvzFO/CRWtuk3IjP
            lKYK23C7ga3IFCblPwp1HrNvUAyH1W0tRzKlIbk/OmbpbX04uNHGp1/9j6MxMMxUNSYXbqoTJWmF
            t3yCqqHGVLzJK2l8qTtoOzldBqD/C/Ra3hDgOYZKTU2awmpZgVbwG7udWGEvovHYXFHIkuYzHECN
            Pzb0VNy9g8/60KVh5X/QbwtRCajQH//GsQ5k7KCTzqQGprVrwW7HC9GOKQQMhpP30UpWiIM0XYZQ
            gcsYR50Mo9vj73vS9+sOy1Vl6A5S7auXJ53v4Lpr2Trf9LcN0utNsZ/K9Ra4iy++XGE+h3zGGQaV
            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
            8LK0YAAAAASUVORK5CYII=" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'''

html += title
html += '''</span>
<span style="font-size:1em; text-align: right; padding-top: 8px; padding-right: 2px; float: right;">'''
html += date
html += '''</span>
</p>
<table>
<tr>
    <th>Object Name</th>
    <th>Type</th>
    <th>Job Name</th>
    <th>Failure Count</th>
    <th>Last Good Backup</th>
    <th>Error Message</th>
</tr>'''

# errorsRecorded = 0
objectStatus = {}

# errorCount = {}
# latestError = {}
# skip = []
# jobEntry = {}
# appErrors = {}
# objErrors = {}
# allObjects = []
totalObjects = 0
# totalFailedObjects = 0


def objectHistory(objectName, status, scheduleType, jobName, jobId, jobType, startTimeUsecs, message):
    thisStatus = {'objectName': objectName,
                  'status': status,
                  'scheduleType': scheduleType,
                  'jobName': jobName,
                  'jobId': jobId,
                  'jobType': jobType,
                  'startTimeUsecs': startTimeUsecs,
                  'message': message}
    searchJobType = jobType
    if jobType == 5:
        searchJobType = 4
    search = api('get', '/searchvms?vmName=%s&entityTypes=%s&allUnderHierarchy=true' % (objectName, environments[searchJobType]))
    if 'vms' in search:
        latestSnapshotUsecs = search['vms'][0]['vmDocument']['versions'][0]['instanceId']['jobStartTimeUsecs']
        errorRuns = api('get', '/backupjobruns?id=%s&startTimeUsecs=%s&allUnderHierarchy=true&excludeTasks=true&numRuns=99999' % (jobId, (latestSnapshotUsecs + 1)))
    else:
        errorRuns = api('get', '/backupjobruns?id=%s&startTimeUsecs=%s&allUnderHierarchy=true&excludeTasks=true&numRuns=99999' % (jobId, (timeAgo(days, 'days'))))
        latestSnapshotUsecs = 0
    if errorRuns:
        numErrors = len(errorRuns[0]['backupJobRuns']['protectionRuns'])
    else:
        numErrors = '-'
    thisStatus['latestSnapshotUsecs'] = latestSnapshotUsecs
    thisStatus['numErrors'] = numErrors
    if objectName not in objectStatus or startTimeUsecs > objectStatus[objectName]['startTimeUsecs']:
        objectStatus[objectName] = thisStatus


jobs = api('get', '/backupjobssummary?_includeTenantInfo=true&allUnderHierarchy=true&includeJobsWithoutRun=false&isActive=true&isDeleted=false&numRuns=1000&onlyReturnBasicSummary=true&onlyReturnJobDescription=false')

for job in sorted(jobs, key=lambda job: job['backupJobSummary']['jobDescription']['name'].lower()):
    jobName = job['backupJobSummary']['jobDescription']['name']
    jobId = job['backupJobSummary']['jobDescription']['jobId']
    print(jobName)
    if 'lastProtectionRun' in job['backupJobSummary']:
        startTimeUsecs = job['backupJobSummary']['lastProtectionRun']['backupRun']['base'].get('startTimeUsecs', None)
        endTimeUsecs = job['backupJobSummary']['lastProtectionRun']['backupRun']['base'].get('endTimeUsecs', None)
        jobId = job['backupJobSummary']['lastProtectionRun']['backupRun']['base'].get('jobId', None)
        if jobId is not None and startTimeUsecs is not None:
            lastrun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&id=%s&onlyReturnDataMigrationJobs=false' % (startTimeUsecs, jobId))
            scheduleType = runType[lastrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['backupType']]
            if 'activeAttempt' in lastrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']:
                attempt = lastrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['activeAttempt']
                status = attempt['publicStatus']
                jobType = attempt['type']
                for source in attempt['sources']:
                    entity = source['source']['displayName']
                    totalObjects += 1
                    objectHistory(entity, status, scheduleType, jobName, jobId, jobType, startTimeUsecs, '')
            if 'latestFinishedTasks' in lastrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']:
                for task in lastrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['latestFinishedTasks']:
                    status = task['base']['publicStatus']
                    jobType = task['base']['type']
                    entity = task['base']['sources'][0]['source']['displayName']
                    totalObjects += 1
                    if status == 'kFailure':
                        message = task['base']['error']['errorMsg']
                        objectHistory(entity, status, scheduleType, jobName, jobId, jobType, startTimeUsecs, message)

for entity in objectStatus:
    if objectStatus[entity]['latestSnapshotUsecs'] == 0:
        lastSuccess = '-'
    else:
        lastSuccess = usecsToDate(objectStatus[entity]['latestSnapshotUsecs'])
    jobUrl = 'https://%s/protection/job/%s/details' % (vip, objectStatus[entity]['jobId'])
    jobEntry = '<a href=%s target="_blank">%s</a>' % (jobUrl, objectStatus[entity]['jobName'])
    row = '''<tr>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
            </tr>''' % (entity, environments[objectStatus[entity]['jobType']], jobEntry, objectStatus[entity]['numErrors'], lastSuccess, objectStatus[entity]['message'][:99])
    html += row

totalFailedObjects = len(objectStatus)
percentFailed = round((100 * (float(totalObjects - totalFailedObjects)) / float(totalObjects)), 2)

html += '''</table>
<p style="margin-top: 15px; margin-bottom: 15px;"><span style="font-size:1em;">%s protected objects failed out of %s total objects (%s%% success rate)</span></p>
</div>
</body>
</html>
''' % (totalFailedObjects, totalObjects, percentFailed)

print('saving report as strikeReport-%s' % cluster['name'])
outfileName = 'strikeReport-%s.html' % cluster['name']
f = open(outfileName, "w")
f.write(html)
f.close()

# email report
if mailserver is not None:
    print('Sending report to %s...' % ', '.join(sendto))
    emailhtml = MIMEText(html, 'html')
    msg = MIMEMultipart('alternative')
    msg['Subject'] = title
    msg['From'] = sendfrom
    msg['To'] = ','.join(sendto)
    msg.attach(emailhtml)
    smtpserver = smtplib.SMTP(mailserver, mailport)
    smtpserver.sendmail(sendfrom, sendto, msg.as_string())
    smtpserver.quit()
