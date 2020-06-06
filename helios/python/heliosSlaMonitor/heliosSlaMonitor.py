#!/usr/bin/env python

### import Cohesity python module
from pyhesity import *
from datetime import datetime
import smtplib
import email.message
import email.utils
import codecs

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)
parser.add_argument('-b', '--maxbackuphrs', type=int, default=8)
parser.add_argument('-r', '--maxreplicationhrs', type=int, default=12)
parser.add_argument('-w', '--watch', type=str, choices=['all', 'backup', 'replication'], default='all')

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
watch = args.watch

### authenticate
apiauth(vip, username, domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

title = 'Missed SLAs on %s' % vip
missesRecorded = False
message = '<html><body style="font-family: Helvetica, Arial, sans-serif; font-size: 12px; background-color: #f1f3f6; color: #444444;">'
message += '<div style="background-color: #fff; width:fit-content; padding: 2px 6px 8px 6px; font-weight: 300; box-shadow: 1px 2px 4px #cccccc; border-radius: 4px;">'
message += '<p style="font-weight: bold;">Helios SLA Miss Report (%s)</p>' % now.date()
for hcluster in heliosClusters():
    heliosCluster(hcluster['name'])

    cluster = api('get', 'cluster')
    if cluster:
        printedClusterName = False
        # for each active job
        jobs = api('get', 'protectionJobs')
        if jobs:
            for job in jobs:
                if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False) and ('isPaused' not in job or job['isPaused'] is not True):
                    jobId = job['id']
                    jobName = job['name']
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
                        if 'copyRun' in run:
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
                            if printedClusterName is False:
                                print(cluster['name'])
                                message += '<hr style="border: 1px solid #eee;"/><span style="font-weight: bold;">%s</span><br/>' % cluster['name'].upper()
                                printedClusterName = True
                            # replort sla miss
                            if status in finishedStates:
                                verb = 'ran'
                            else:
                                verb = 'has been running'
                            if (watch == 'all' or watch == 'backup') and (runTimeUsecs > slaUsecs or runTimeHours > maxbackuphrs):
                                messageline = '<span style="margin-left: 20px; font-weight: normal; color: #000;">%s:</span> <span style="font-weight: 300;">Backup %s for %s minutes (SLA: %s minutes)</span><br/>' % (jobName.upper(), verb, runTimeMinutes, sla)
                                message += messageline
                                print('    %s : (Missed Backup SLA) %s for %s minutes (SLA: %s minutes)' % (jobName.upper(), verb, runTimeMinutes, sla))
                                missesRecorded = True
                                # identify long running objects
                                if 'sourceBackupStatus' in run['backupRun']:
                                    for source in run['backupRun']['sourceBackupStatus']:
                                        if 'endTimeUsecs' in source['stats']:
                                            timeTakenUsecs = source['stats']['endTimeUsecs'] - startTimeUsecs
                                        elif 'timeTakenUsecs' in source['stats']:
                                            timeTakenUsecs = source['stats']['timeTakenUsecs']
                                        else:
                                            timeTakenUsecs = 0
                                        if timeTakenUsecs > slaUsecs:
                                            timeTakenMin = int(round(timeTakenUsecs / 60000000))
                                            print('            %s %s for %s minutes' % (source['source']['name'].upper(), verb, timeTakenMin))
                                            messageline = '<span style="margin-left: 60px;"><span style="color: #000; font-weight: normal;">%s</span> <span style="font-weight: 300;">%s for %s minutes</span></span><br/>' % (source['source']['name'].upper(), verb, timeTakenMin)
                                            message += messageline
                            # report long running replication
                            if (watch == 'all' or watch == 'replication') and replHours >= maxreplicationhrs:
                                print('    %s : (Missed Replication SLA) replication time: %s hours' % (jobName, replHours))
                                messageline = '<span style="margin-left: 20px; font-weight: normal; color: #000;">%s:</span> <span style="font-weight: 300;">Replication time: %s hours</span><br/>' % (jobName, replHours)
                                message += messageline
                                missesRecorded = True
                            break
    else:
        print('%-15s: (trouble accessing cluster)' % hcluster['name'])

if missesRecorded is False:
    print('No SLA misses recorded')
else:
    message += '</body></html>'
    f = codecs.open('out.html', 'w', 'utf-8')
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
        # handle unicode
        msg['Content-Transfer-Encoding'] = '8bit'
        msg.set_payload(message, 'UTF-8')
        smtpserver = smtplib.SMTP(mailserver, mailport)
        smtpserver.sendmail(sendfrom, sendto, msg.as_string())
        smtpserver.quit()
