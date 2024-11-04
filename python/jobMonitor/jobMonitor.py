#!/usr/bin/env python
"""Protection Job Monitor for python"""

# version 2022.07.28

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-n', '--numruns', type=int, default=10)
parser.add_argument('-s', '--showobjects', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
clustername = args.clustername
mcm = args.mcm
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobnames = args.jobname
numruns = args.numruns
showobjects = args.showobjects

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    if emailmfacode:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, emailMfaCode=True)
    else:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, mfaCode=mfacode)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit(1)

if apiconnected() is False:
    print('authentication failed')
    exit(1)

### get protectionJobs
jobs = [job for job in api('get', 'protectionJobs') if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False)]
if jobnames is not None and len(jobnames) > 0:
    jobs = [job for job in jobs if job['name'].lower() in [n.lower() for n in jobnames]]

# catch invalid job names
if jobnames is not None and len(jobnames) > 0:
    notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
    if len(notfoundjobs) > 0:
        print('Jobs not found: %s' % ', '.join(notfoundjobs))
        exit(1)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning', 'kCanceling', '3', '4', '5', '6']
statusMap = ['0', '1', '2', 'Canceled', 'Success', 'Failed', 'Warning']

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    print('\n%s' % job['name'])
    environment = job['environment']
    if environment == 'kPhysicalFiles':
        environment = 'kPhysical'
    runs = api('get', 'protectionRuns?jobId=%s&numRuns=%s' % (job['id'], numruns))
    runningCount = 0
    if runs is not None and len(runs) > 0:
        for run in runs:
            status = run['backupRun']['status']
            if status not in finishedStates:
                runningCount += 1
                startTime = usecsToDate(run['backupRun']['stats']['startTimeUsecs'])
                try:
                    progressTotal = 0
                    sourceCount = len(run['backupRun']['sourceBackupStatus'])
                    for source in sorted(run['backupRun']['sourceBackupStatus'], key=lambda source: source['source']['name'].lower()):
                        sourceName = source['source']['name']
                        progressPath = source['progressMonitorTaskPath']
                        progressMonitor = api('get', '/progressMonitors?taskPathVec=%s&includeFinishedTasks=true&excludeSubTasks=false' % progressPath)
                        thisProgress = progressMonitor['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                        progressTotal += thisProgress
                        if showobjects is True:
                            print('    %s:  %s%% completed\t%s' % (startTime, int(round(thisProgress)), sourceName))
                    percentComplete = int(round(progressTotal / sourceCount))
                    if showobjects is not True:
                        print('    %s: %s%%\tcompleted' % (startTime, percentComplete))
                except Exception:
                    pass
        if runningCount == 0:
            lastRunStatus = runs[0]['backupRun']['status']
            if str(lastRunStatus) in ['3', '4', '5', '6']:
                lastRunStatus = statusMap[lastRunStatus]
            else:
                lastRunStatus = lastRunStatus[1:]
            lastRunStartTime = usecsToDate(runs[0]['backupRun']['stats']['startTimeUsecs'])
            print('    %s:  %s' % (lastRunStartTime, lastRunStatus))
    else:
        print('    No runs found')
