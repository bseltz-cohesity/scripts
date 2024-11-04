#!/usr/bin/env python
"""monitorTasks"""

# usage: ./monitorTasks.py -v ve2 -u admin -j 54334 -k 'Starting directory differ' -t 120

# import pyhesity wrapper module
from pyhesity import *
from time import sleep
from datetime import datetime
import os
import smtplib
import email.message
import email.utils

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-j', '--jobid', type=int, required=True)       # job ID to monitor
parser.add_argument('-n', '--jobname', type=str, required=True)   # string to find in pulse log
parser.add_argument('-k', '--keystring', type=str, required=True)   # string to find in pulse log
parser.add_argument('-o', '--timeoutsec', type=int, required=True)  # seconds until we alert and bailout
parser.add_argument('-c', '--callbackuser', type=str, required=True)  # user@target to run callback script
parser.add_argument('-b', '--callbackpath', type=str, required=True)  # user@target to run callback script
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobid = args.jobid
jobname = args.jobname
keystring = args.keystring
timeoutsec = args.timeoutsec
callbackuser = args.callbackuser
callbackpath = args.callbackpath
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

# authenticate
apiauth(vip, username, domain)

# track seconds passed
s = 0
# count tasks where preprocess is finished
x = 0
preprocessFinished = True

# new job run startTime should be in the last 60 seconds
now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
startTimeUsecs = nowUsecs - 60000000

# get latest job run
run = None

print("waiting for new run...")
while run is None and s < timeoutsec:
    try:
        run = api('get', 'protectionRuns?jobId=%s&numRuns=1&startTimeUsecs=%s' % (jobid, startTimeUsecs))[0]
        runStartTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
        # create a flag file for this run so we only run once
        if not os.path.exists(str(runStartTimeUsecs)):
            f = open(str(runStartTimeUsecs), 'w')
            f.write(str(runStartTimeUsecs))
            f.close()
        else:
            exit()
        stats = run['backupRun']['sourceBackupStatus']
        if run:
            print("found new run")
    except Exception as e:
        run = None
        sleep(1)
        s += 1

# wait until all tasks are finished preprocessing
print("monitoring tasks...")
while x < len(run['backupRun']['sourceBackupStatus']) and s < timeoutsec:
    sleep(1)
    s += 1
    if s > timeoutsec:
        break
    x = 0
    for source in run['backupRun']['sourceBackupStatus']:
        # get task monitor per source
        task = api('get', '/progressMonitors?taskPathVec=%s' % source['progressMonitorTaskPath'])
        try:
            # get pulse log messages
            eventmsgs = task['resultGroupVec'][0]['taskVec'][0]['progress']['eventVec']
            foundkeystring = False
            # check for key string in event messages
            for eventmsg in eventmsgs:
                if keystring in eventmsg['eventMsg']:
                    foundkeystring = True
            if foundkeystring is True:
                x += 1
            else:
                preprocessFinished = False
        except Exception as e:
            pass
if x >= len(run['backupRun']['sourceBackupStatus']):
    # we're good
    print('preprocessing complete')
else:
    # we timed out - send an alert email
    print('we timed out')
    print('Sending report to %s...' % ', '.join(sendto))
    msg = email.message.Message()
    msg['Subject'] = "thaw timeout %s" % jobname
    msg['From'] = sendfrom
    msg['To'] = ','.join(sendto)
    msg.add_header('Content-Type', 'text')
    msg.set_payload("thaw timeout %s" % jobname)
    smtpserver = smtplib.SMTP(mailserver, mailport)
    smtpserver.sendmail(sendfrom, sendto, msg.as_string())
    smtpserver.quit()
# regardless - call the thaw script
os.system("ssh -t %s %s" % (callbackuser, callbackpath))
