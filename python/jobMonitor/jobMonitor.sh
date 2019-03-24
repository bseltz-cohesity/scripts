#!/usr/bin/env python
"""Python script to monitor a protectionJob"""

from pyhesity import *
import urllib
import time
import smtplib

VIP = '192.168.1.198'
USERNAME = 'admin'
DOMAIN = 'local'
JOBNAME = 'VM Backup'
SLEEPTIME = 15  # seconds
FROMADDR = 'jobMonitor@seltzer.net'
TOADDR = 'bseltzer@cohesity.com'

STARTMESSAGE = 'Subject:' + JOBNAME + ' Started' + '\n\nProtection Job ' + JOBNAME + ' started at '
ENDMESSAGE = 'Subject:' + JOBNAME + ' Ended' + '\n\nProtection Job ' + JOBNAME + ' ended with '


def sendMessage(msg):
    server = smtplib.SMTP('192.168.1.95', 25)
    server.sendmail(FROMADDR, TOADDR, msg)
    server.quit()


apiauth(VIP, USERNAME)

f = open('lastrun', 'r')
lastRun = f.read()
f.close()
if lastRun == '':
    lastRun = timeAgo(1, 'sec')

print("Waiting for Cohesity Protection Job To Run...")

while True:
    jobId = api('get', 'protectionJobs?names=' + urllib.quote_plus(JOBNAME))[0]['id']
    runs = api('get', 'protectionRuns?jobId=' + str(jobId))
    if 'startTimeUsecs' in runs[0]['backupRun']['stats']:
        latestRun = runs[0]['backupRun']['stats']['startTimeUsecs']
    if int(latestRun) > int(lastRun):  # job started since we last checked
        runURL = 'protectionRuns?startedTimeUsecs=%s&jobId=%s' % (latestRun, jobId)
        # email start alert
        sendMessage(STARTMESSAGE + usecsToDate(latestRun))
        print(JOBNAME + ' started at ' + usecsToDate(latestRun))
        stillRunning = True
        while (stillRunning):
            state = api('get', runURL)
            if 'endTimeUsecs' in state[0]['backupRun']['stats']:
                result = state[0]['backupRun']['status']
                # email result
                if result == 'kSuccess':
                    COMPLETEDMESSAGE = ENDMESSAGE.replace('Ended', 'Completed Successfully')
                else:
                    COMPLETEDMESSAGE = ENDMESSAGE.replace('Ended', 'UNSUCCESSFUL!!')
                sendMessage(COMPLETEDMESSAGE + result + ' at ' + usecsToDate(state[0]['backupRun']['stats']['endTimeUsecs']))
                print(JOBNAME + ' ended with ' + result + ' at ' + usecsToDate(state[0]['backupRun']['stats']['endTimeUsecs']))
                stillRunning = False
            time.sleep(SLEEPTIME)
        lastRun = latestRun
        f = open('lastrun', 'w')
        f.write(str(lastRun))
        f.close()
    time.sleep(SLEEPTIME)
