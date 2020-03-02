#!/usr/bin/env python

### import Cohesity python module
from pyhesity import *
from datetime import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-n', '--numruns', type=int, default=9999)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
numruns = args.numruns

### authenticate
apiauth(vip, username, domain)

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

runningTasks = {}

# for each active job
jobs = api('get', 'protectionJobs')
for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False):
        jobId = job['id']
        jobName = job['name']
        print("Getting tasks for %s" % jobName)
        # find runs with unfinished replication tasks
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=%s&excludeTasks=true' % (jobId, numruns))
        for run in runs:
            runStartTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
            if 'copyRun' in run:
                for copyRun in run['copyRun']:
                    # store run details in dictionary
                    if copyRun['status'] not in finishedStates and copyRun['target']['type'] == 'kRemote':
                        runningTask = {
                            "jobname": jobName,
                            "jobId": jobId,
                            "startTimeUsecs": runStartTimeUsecs,
                            "copyType": copyRun['target']['type'],
                            "status": copyRun['status']
                        }
                        runningTasks[runStartTimeUsecs] = runningTask

if len(runningTasks.keys()) > 0:
    print("\n\nStart Time           Job Name")
    print("----------           --------")
    # for each replicating run - sorted from oldest to newest
    for startTimeUsecs in sorted(runningTasks.keys()):
        t = runningTasks[startTimeUsecs]
        print("%s  %s (%s)" % (usecsToDate(t['startTimeUsecs']), t['jobname'], t['jobId']))
        # get detailed run info
        run = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&id=%s' % (t['startTimeUsecs'], t['jobId']))
        runStartTimeUsecs = run[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['startTimeUsecs']
        # get replication task(s)
        if 'activeTasks' in run[0]['backupJobRuns']['protectionRuns'][0]['copyRun']:
            for task in run[0]['backupJobRuns']['protectionRuns'][0]['copyRun']['activeTasks']:
                if task['snapshotTarget']['type'] == 2:
                    # determine if run is now older than the intended retention
                    noLongerNeeded = ''
                    daysToKeep = task['retentionPolicy']['numDaysToKeep']
                    usecsToKeep = daysToKeep * 1000000 * 86400
                    timePassed = nowUsecs - runStartTimeUsecs
                    if timePassed > usecsToKeep:
                        noLongerNeeded = "NO LONGER NEEDED"
                    print('                       Replication Task ID: %s  %s' % (task['taskUid']['objectId'], noLongerNeeded))
                    if 'activeCopySubTasks' in task:
                        # display status of per-object sub tasks
                        for subTask in sorted(task['activeCopySubTasks'], key=lambda subtask: subtask['publicStatus'], reverse=True):
                            if subTask['snapshotTarget']['type'] == 2:
                                if subTask['publicStatus'] == 'kRunning':
                                    if 'pctCompleted' in subTask['replicationInfo']:
                                        pct = subTask['replicationInfo']['pctCompleted']
                                    else:
                                        pct = 0
                                else:
                                    pct = 0
                                print('                       %s (%s)\t%s' % (subTask['publicStatus'], pct, subTask['entity']['displayName']))
else:
    print('\nNo active replication tasks found')
