#!/usr/bin/env python
"""aag failover / sql log chain monitor"""

from pyhesity import *
from time import sleep
import smtplib
import email.message

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, action='append')
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-ms', '--mailserver', type=str)
parser.add_argument('-mp', '--mailport', type=int, default=25)
parser.add_argument('-to', '--sendto', action='append', type=str)
parser.add_argument('-fr', '--sendfrom', type=str)
parser.add_argument('-as', '--alwayssend', action='store_true')
parser.add_argument('-f', '--fullbackup', action='store_true')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom
alwayssend = args.alwayssend
fullbackup = args.fullbackup


def waitForRefresh(sourceId):
    authStatus = ''
    while authStatus != 'Finished':
        rootFinished = False
        appsFinished = False
        sleep(5)
        rootNodes = api('get', 'protectionSources/registrationInfo?includeApplicationsTreeInfo=false&ids=%s' % sourceId)
        rootNode = [r for r in rootNodes['rootNodes'] if r['rootNode']['id'] == sourceId]
        if rootNode[0]['registrationInfo']['authenticationStatus'] == 'kFinished':
            rootFinished = True
        if 'registeredAppsInfo' in rootNode[0]['registrationInfo']:
            for app in rootNode[0]['registrationInfo']['registeredAppsInfo']:
                if app['authenticationStatus'] == 'kFinished':
                    appsFinished = True
                else:
                    appsFinished = False
        else:
            appsFinished = True
        if rootFinished is True and appsFinished is True:
            authStatus = 'Finished'
    return rootNode[0]['rootNode']['id']


# authentication =========================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), quiet=True)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# end authentication =====================================================

mailmsg = '<html><body style="font-family: Helvetica, Arial, sans-serif; font-size: 14px;"><div>'
issuesfound = False

if mcm or vip.lower() == 'helios.cohesity.com':
    if clusternames is None or len(clusternames) == 0:
        clusternames = [c['name'] for c in heliosClusters()]
else:
    cluster = api('get', 'cluster')
    clusternames = [cluster['name']]

for clustername in clusternames:
    print('%s' % clustername)
    if mcm or vip.lower() == 'helios.cohesity.com':
        heliosCluster(clustername)

    try:
        cluster = api('get', 'cluster')

        jobs = api('get', 'protectionJobs?isDeleted=false&isActive=true&environments=kSQL')

        if jobs is None:
            print('    no SQL jobs found')
            continue

        for job in sorted(jobs, key=lambda job: job['name'].lower()):
            refreshSourceIds = []
            try:
                runs = api('get', 'protectionRuns?jobId=%s&numRuns=1' % job['id'])
                if runs is not None and len(runs) > 0:
                    run = runs[0]
                    needsrun = False
                    runStartTime = usecsToDate(run['backupRun']['stats']['startTimeUsecs'])
                    status = run['backupRun']['status']
                    runType = run['backupRun']['runType']
                    if status == 'kFailure':
                        if 'error' in run['backupRun']:
                            runNowParameters = []
                            message = run['backupRun']['error']
                            if 'Detected AAG metadata changes' in message or \
                               'No matching replica found for the backup preference' in message or \
                               'Discovered a break in the logchain' in message:
                                needsrun = True
                                print('- %s (%s): %s' % (job['name'], runStartTime, message))
                                mailmsg = mailmsg + '<br/><b>Cluster</b>: %s<br/><b>Protection Group</b>: %s<br/><b>Date (UTC)</b>: %s<br/><b>Message</b>: %s<br/>' % (cluster['name'], job['name'], runStartTime, message)
                            for source in run['backupRun']['sourceBackupStatus']:
                                if source['status'] == 'kFailure':
                                    sourceId = source['source']['id']
                                    refreshSourceIds.append(sourceId)
                                    runNowParameter = {
                                        "sourceId": sourceId
                                    }
                                    sourceName = source['source']['name']
                                    for app in source['appsBackupStatus']:
                                        if 'error' in app:
                                            if 'databaseIds' not in runNowParameter:
                                                runNowParameter['databaseIds'] = []
                                            runNowParameter['databaseIds'].append(app['appId'])
                                    runNowParameters.append(runNowParameter)
                    else:
                        print('- %s' % job['name'])
                    if needsrun is True:
                        issuesfound = True
                        print('- Refreshing sources')
                        for sourceId in refreshSourceIds:
                            result = api('post', 'protectionSources/refresh/%s' % sourceId)
                            waitForRefresh(sourceId)
                        jobId = job['id']
                        policy = [p for p in api('get', 'protectionPolicies') if p['id'] == job['policyId']]
                        copyRunTargets = []
                        # replicas from policy
                        if 'snapshotReplicationCopyPolicies' in policy:
                            for replica in policy['snapshotReplicationCopyPolicies']:
                                if len([t for t in copyRunTargets if t['replicationTarget']['clusterName'] == replica['target']['clusterName']]) == 0:
                                    copyRunTargets.append({
                                        "daysToKeep": replica['daysToKeep'],
                                        "replicationTarget": replica['target'],
                                        "type": "kRemote"
                                    })
                        # archives from policy
                        if 'snapshotArchivalCopyPolicies' in policy:
                            for archive in policy['snapshotArchivalCopyPolicies']:
                                if len([t for t in copyRunTargets if t['archivalTarget']['vaultName'] == archive['target']['vaultName']]) == 0:
                                    copyRunTargets.append({
                                        "archivalTarget": archive['target'],
                                        "daysToKeep": archive['daysToKeep'],
                                        "type": "kArchival"
                                    })
                        runParams = {
                            "runType": 'kRegular',
                            "usePolicyDefaults": True,
                            "copyRunTargets": copyRunTargets,
                            "runNowParameters": runNowParameters
                        }
                        if fullbackup is True:
                            runParams['runType'] = 'kFull'
                        newRun = api('post', 'protectionJobs/run/%s' % jobId, runParams)
                        print('- Running job %s again' % job['name'])
            except Exception:
                pass
    except Exception:
        pass

if issuesfound is True:
    mailsubject = "Helios SQL Monitor - *** Issue Detected ***"
else:
    mailsubject = "Helios SQL Monitor"
    mailmsg += '<br/>No issues detected<br/>'
mailmsg += '</div></body></html>'

if issuesfound is True or alwayssend is True:
    if mailserver is not None and sendto is not None and sendfrom is not None:
        print('\nSending email report to %s\n' % ', '.join(sendto))
        msg = email.message.Message()
        msg['From'] = sendfrom
        msg['To'] = ', '.join(sendto)
        msg['Subject'] = mailsubject
        msg.add_header('Content-Type', 'text/html')
        msg.set_payload(mailmsg)
        msg['Content-Transfer-Encoding'] = '8bit'
        msg.set_payload(mailmsg, 'UTF-8')
        smtpserver = smtplib.SMTP(mailserver, mailport)
        smtpserver.sendmail(sendfrom, sendto, msg.as_string())
        smtpserver.quit()

print('Completed')
