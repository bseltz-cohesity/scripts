#!/usr/bin/env python

# import Cohesity python module
from pyhesity import *
from datetime import datetime
import codecs
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-a', '--alertdays', type=int, default=2)
parser.add_argument('-x', '--extenddays', type=int, default=7)
parser.add_argument('-n', '--numruns', type=int, default=1000)
parser.add_argument('-commit', '--commit', action='store_true')
parser.add_argument('-o', '--outputpath', type=str, default='.')
parser.add_argument('-ms', '--mailserver', type=str)
parser.add_argument('-mp', '--mailport', type=int, default=25)
parser.add_argument('-to', '--sendto', action='append', type=str)
parser.add_argument('-fr', '--sendfrom', type=str)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
numruns = args.numruns
alertdays = args.alertdays
extenddays = args.extenddays
commit = args.commit
outputpath = args.outputpath
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

finishedStates = ['kSuccess', 'kWarning']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
outfile = os.path.join(outputpath, 'extendedSnapshots-%s.csv' % cluster['name'])
logfile = os.path.join(outputpath, 'log-extendSnapshots-%s.txt' % cluster['name'])

f = codecs.open(outfile, 'w')
f.write('"Protection Group","Run Date","Previous Expiry","New Expiry","Target Type","Target Name"\n')
extensions = 0

log = codecs.open(logfile, 'w')
log.write('Script started: %s\n' % now.strftime("%Y-%m-%d %H:%M:%S"))


def out(message, quiet=False):
    if quiet is False:
        print(message)
    log.write('%s\n' % message)


def bail(code=0):
    log.close()
    f.close()
    exit(code)


if extenddays <= alertdays:
    out('--extenddays must be greater than --alertdays')
    bail(1)

# for each job
jobs = api('get', 'protectionJobs?allUnderHierarchy=true')
out('')
for job in sorted(jobs, key=lambda job: job['name'].lower()):
    jobId = job['id']
    out("%s" % job['name'])
    # impersonate tenant
    if 'tenantId' in job and job['tenantId'] is not None:
        impersonate(job['tenantId'][0:-1])
    endUsecs = nowUsecs
    while 1:
        # find runs with active copy tasks
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=%s&endTimeUsecs=%s&excludeTasks=true&excludeNonRestoreableRuns=true' % (job['id'], numruns, endUsecs))
        if len(runs) > 0:
            endUsecs = runs[-1]['backupRun']['stats']['startTimeUsecs'] - 1
        else:
            break
        for run in runs:
            runStartTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
            expiryTimeUsecs = None
            daysTilExpiry = 0
            if 'copyRun' in run:
                # calculate required extension
                for copyRun in run['copyRun']:
                    if copyRun['target']['type'] == 'kLocal':
                        expiryTimeUsecs = copyRun['expiryTimeUsecs']
                if expiryTimeUsecs:
                    daysTilExpiry = int(round((expiryTimeUsecs - nowUsecs) / (1000000 * 60 * 60 * 24), 0))
                if daysTilExpiry > alertdays:
                    continue
                extendByDays = extenddays - daysTilExpiry
                newExpiryDate = usecsToDate(expiryTimeUsecs + (extendByDays * 1000000 * 60 * 60 * 24))
                # find active copy tasks
                for copyRun in run['copyRun']:
                    targetName = ''
                    if copyRun['target']['type'] in ['kRemote', 'kArchival']:
                        if copyRun['target']['type'] == 'kRemote':
                            copyRun['target']['type'] = 'kReplica'
                            targetName = copyRun['target']['replicationTarget']['clusterName']
                        else:
                            targetName = copyRun['target']['archivalTarget']['vaultName']
                        if copyRun['status'] not in finishedStates:
                            if expiryTimeUsecs:
                                if commit is True:
                                    # extend this local snapshot
                                    thisRun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&id=%s' % (runStartTimeUsecs, job['id']))
                                    jobUid = thisRun[0]['backupJobRuns']['jobDescription']['primaryJobUid']
                                    runParameters = {
                                        "jobRuns": [
                                            {
                                                "jobUid": {
                                                    "clusterId": jobUid['clusterId'],
                                                    "clusterIncarnationId": jobUid['clusterIncarnationId'],
                                                    "id": jobUid['objectId']
                                                },
                                                "runStartTimeUsecs": runStartTimeUsecs,
                                                "copyRunTargets": [
                                                    {
                                                        "daysToKeep": extendByDays,
                                                        "type": "kLocal"
                                                    }
                                                ]
                                            }
                                        ]
                                    }
                                    out('    %s - extending to %s' % (usecsToDate(runStartTimeUsecs), newExpiryDate))
                                    api('put', 'protectionRuns', runParameters)
                                    extensions += 1
                                else:
                                    # just report, do not change
                                    out('    %s - would extend to %s' % (usecsToDate(runStartTimeUsecs), newExpiryDate))
                                f.write('"%s","%s","%s","%s","%s","%s"\n' % (job['name'], usecsToDate(runStartTimeUsecs), usecsToDate(expiryTimeUsecs), newExpiryDate, copyRun['target']['type'][1:], targetName))
                                # break here so we don't extend the same snapshot more than once
                                break
    # end impersonation
    if 'tenantId' in job and job['tenantId'] is not None:
        switchback()
f.close()

# email report
if extensions > 0 and mailserver is not None and sendto is not None and sendfrom is not None:
    out('')
    msg = MIMEMultipart()
    msg['From'] = sendfrom
    msg['To'] = ', '.join(sendto)
    msg['Subject'] = "extended expirations for snapshots with active replica/archive tasks on cluster: %s" % cluster['name']
    body = "extended expirations for snapshots with active replica/archive tasks on cluster: %s" % cluster['name']
    msg.attach(MIMEText(body, 'plain'))
    filename = outfile
    attachment = open(outfile, "rb")
    part = MIMEBase('application', 'octet-stream')
    part.set_payload((attachment).read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', "attachment; filename= %s" % filename)
    msg.attach(part)
    smtp = smtplib.SMTP(mailserver, mailport)
    smtp.sendmail(sendfrom, sendto, msg.as_string())
    out('Sending email report to %s\n' % ', '.join(sendto))

out('\nOutput saved to %s\n' % outfile)
log.close()
