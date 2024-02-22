#!/usr/bin/env python

from pyhesity import *
import smtplib
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-l', '--logwarningminutes', type=int, default=60)
parser.add_argument('-m', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)

args = parser.parse_args()

username = args.username
password = args.password
noprompt = args.noprompt
logwarningminutes = args.logwarningminutes
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

# authentication =========================================================
apiauth(username=username, password=password, prompt=(not noprompt))

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

missesRecorded = False
message = ''

# gather helios tenant info
sessionUser = api('get', 'sessionUser')
tenantId = sessionUser['profiles'][0]['tenantId']
regions = api('get', 'dms/tenants/regions?tenantId=%s' % tenantId, mcmv2=True)
regionList = ','.join([r['regionId'] for r in regions['tenantRegionInfoList']])

activityQuery = {
    "activityTypes": [
        "ArchivalRun",
        "BackupRun"
    ],
    "statsParams": {
        "attributes": [
            "ActivityType"
        ]
    }
}

finishedStates = ['SucceededWithWarning', 'Succeeded', 'Failed', 'Canceled']
activities = api('post', 'data-protect/objects/activity?regionIds=%s' % regionList, activityQuery, mcmv2=True)
if 'activity' in activities and activities['activity'] is not None and len(activities['activity']) > 0:
    for activity in activities['activity']:
        objectName = '%s/%s' % (activity['object']['sourceName'], activity['object']['name'])
        environment = activity['object']['environment'][1:]
        if 'archivalRunParams' in activity:
            params = activity['archivalRunParams']
        else:
            params = activity['backupRunParams']
        status = params['status']
        startTimeUsecs = params['startTimeUsecs']
        runType = 'kIncremental'
        if 'runType' in params:
            runType = params['runType']
        slaViolated = False
        if 'isSlaViolated' in params:
            slaViolated = params['isSlaViolated']
            reason = 'SLA missed (%s)' % runType[1:]
        if status not in finishedStates:
            nowUsecs = dateToUsecs()
            if runType == 'kLog':
                if (startTimeUsecs + (logwarningminutes * 60000000)) > nowUsecs:
                    slaViolated = True
                    reason = 'SLA missed (Log)  *** still running ***'
            else:
                obj = api('get', 'data-protect/objects?ids=%s&regionId=%s' % (activity['object']['id'], activity['regionId']), v=2)
                sla = obj['objects'][0]['objectBackupConfiguration']['sla']
                thisSla = [s['slaMinutes'] for s in sla if s['backupRunType'] == runType]
                if (startTimeUsecs + (thisSla[0] * 60000000)) > nowUsecs:
                    slaViolated = True
                    reason = 'SLA missed (%s)  *** still running ***' % runType[1:]
        else:
            if runType == 'kLog':
                if 'endTimeUsecs' in params:
                    if (params['endTimeUsecs'] - params['startTimeUsecs']) > (logwarningminutes * 60000000):
                        slaViolated = True
                        reason = 'SLA missed (Log)'
        if slaViolated is True:
            missesRecorded = True
            messageLine = '%s %s (%s) %s' % (usecsToDate(startTimeUsecs, fmt='%Y-%m-%d %H:%M'), objectName, environment, reason)
            message += "%s\n" % messageLine
            print('%s %s (%s) %s' % (usecsToDate(startTimeUsecs, fmt='%Y-%m-%d %H:%M'), objectName, environment, reason))

if missesRecorded is False:
    print('No SLA misses recorded')
else:
    if mailserver is not None:
        print('sending report to %s' % ', '.join(sendto))
        msg = "Subject:%s\n\n%s" % ("Cohesity DataProtect as a Service: SLA Violations", message)
        smtpserver = smtplib.SMTP(mailserver, mailport)
        smtpserver.sendmail(sendfrom, sendto, msg)
