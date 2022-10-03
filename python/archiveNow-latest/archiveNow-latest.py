#!/usr/bin/env python
"""Archive Now for python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-k', '--keepfor', type=int, required=True)    # (optional) will use policy retention if omitted
parser.add_argument('-t', '--target', type=str, required=True)  # (optional) will use policy target if omitted
parser.add_argument('-f', '--fromtoday', action='store_true')     # (optional) keepfor x days from today instead of from snapshot date
parser.add_argument('-c', '--commit', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobnames = args.jobname
joblist = args.joblist
keepfor = args.keepfor
target = args.target
fromtoday = args.fromtoday
commit = args.commit

# authenticate
apiauth(vip, username, domain)


# gather server list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


jobnames = gatherList(jobnames, joblist, name='jobs', required=True)

jobs = api('get', 'protectionJobs')

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))

daysToKeep = None

vault = [vault for vault in api('get', 'vaults') if vault['name'].lower() == target.lower()]
if len(vault) > 0:
    vault = vault[0]
    target = {
        "vaultId": vault['id'],
        "vaultName": vault['name'],
        "vaultType": "kCloud"
    }
else:
    print('No archive target named %s' % target)
    exit()

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning']

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    daysToKeep = keepfor
    if job['name'].lower() in [j.lower() for j in jobnames]:
        print('\n%s' % job['name'])
        runs = api('get', 'protectionRuns?jobId=%s&runTypes=kRegular&runTypes=kFull&numRuns=10&excludeTasks=true' % job['id'])
        for run in runs:
            if run['backupRun']['snapshotsDeleted'] is False and run['backupRun']['status'] in ['kSuccess', 'kWarning']:
                # check for active copy tasks
                activeCopyTasks = [t for t in run['copyRun'] if t['status'] not in finishedStates]
                if activeCopyTasks is None or len(activeCopyTasks) == 0:
                    # check for already completed archive tasks to this target
                    copyTasks = [t for t in run['copyRun'] if t['target']['type'] == 'kArchival' and t['status'] == 'kSuccess' and t['target']['archivalTarget']['vaultName'].lower() == target['vaultName'].lower()]
                    if copyTasks is None or len(copyTasks) == 0:
                        thisrun = api('get', '/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=%s&excludeTasks=true&id=%s' % (run['backupRun']['stats']['startTimeUsecs'], run['jobId']))
                        jobUid = thisrun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']
                        currentExpiry = None

                        # configure archive task
                        archiveTask = {
                            "jobRuns": [
                                {
                                    "copyRunTargets": [
                                        {
                                            "archivalTarget": target,
                                            "type": "kArchival"
                                        }
                                    ],
                                    "runStartTimeUsecs": run['copyRun'][0]['runStartTimeUsecs'],
                                    "jobUid": {
                                        "clusterId": jobUid['clusterId'],
                                        "clusterIncarnationId": jobUid['clusterIncarnationId'],
                                        "id": jobUid['objectId']
                                    }
                                }
                            ]
                        }

                        # if fromtoday is not set, calculate days to keep from snapshot date
                        if fromtoday is False:
                            daysToKeep = keepfor - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])

                        archiveTask['jobRuns'][0]['copyRunTargets'][0]['daysToKeep'] = int(daysToKeep)

                        # update run
                        if (daysToKeep > 0 and currentExpiry is None) or (daysToKeep != 0 and currentExpiry is not None):
                            if commit:
                                print('    archiving snapshot from %s...' % usecsToDate(run['copyRun'][0]['runStartTimeUsecs']))
                                result = api('put', 'protectionRuns', archiveTask)
                            else:
                                print('    would archive snapshot from %s' % usecsToDate(run['copyRun'][0]['runStartTimeUsecs']))
                            break
                        else:
                            print('    skipping archive snapshot from %s' % usecsToDate(run['copyRun'][0]['runStartTimeUsecs']))
                            break
                    else:
                        print('    already archived snapshot from %s' % usecsToDate(run['copyRun'][0]['runStartTimeUsecs']))
                        break
                else:
                    # check if currently archiving to this target
                    copyTasks = [t for t in run['copyRun'] if t['target']['type'] == 'kArchival' and t['target']['archivalTarget']['vaultName'].lower() == target['vaultName'].lower()]
                    if copyTasks is not None and len(copyTasks) > 0:
                        print('    already archiving snapshot from %s' % usecsToDate(run['copyRun'][0]['runStartTimeUsecs']))
                        break
