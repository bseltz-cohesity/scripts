#!/usr/bin/env python
"""restart failed jobs - 2021-02-02"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', action='append', type=str)
parser.add_argument('-l', '--clusterlist', type=str)
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-c', '--canceled', action='store_true')        # restart canceled jobs
parser.add_argument('-n', '--hoursback', type=int, default=24)      # number of hours back to look
parser.add_argument('-r', '--restart', action='store_true')         # perform restarts
parser.add_argument('-t', '--jobtype', type=str, default=None)      # optional job type

args = parser.parse_args()

clusternames = args.vip
clusterlist = args.clusterlist
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
restartCanceled = args.canceled
hoursback = args.hoursback
restart = args.restart
jobtypefilter = args.jobtype


def out(message):
    print(message)
    log.write('%s\n' % message)


def bail(code=0):
    log.close()
    exit(code)


# gather list
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


clusternames = gatherList(clusternames, clusterlist, name='clusters', required=True)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
dateString = now.strftime("%Y-%m-%d-%H-%M-%S")
hoursAgoUsecs = timeAgo(hoursback, 'hours')

outfile = 'log-restartFailedJobs-%s.txt' % dateString
log = codecs.open(outfile, 'w')

successStates = ['Succeeded', 'SucceededWithWarning', 'Running', 'Canceled']
if restartCanceled:
    successStates = ['Succeeded', 'SucceededWithWarning', 'Running']

for clustername in clusternames:

    apiauth(vip=clustername, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True, quiet=True)
    if apiconnected() is True:
        out(clustername)
        policies = api('get', 'protectionPolicies')
        jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeLastRunInfo=true', v=2)

        for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
            if job['isPaused'] is not True:
                jobtype = job['environment'][1:]
                if jobtypefilter is None or jobtypefilter.lower() == jobtype.lower():
                    if 'lastRun' in job:
                        status = job['lastRun']['localBackupInfo']['status']
                        runDate = job['lastRun']['localBackupInfo']['startTimeUsecs']
                        runType = job['lastRun']['localBackupInfo']['runType']
                    else:
                        runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=1&includeTenants=true' % job['id'], v=2)
                        if runs is not None and 'runs' in runs and len(runs['runs']) > 0:
                            run = runs['runs'][0]
                            status = run['localBackupInfo']['status']
                            runDate = run['localBackupInfo']['startTimeUsecs']
                            runType = run['localBackupInfo']['runType']
                    if status not in successStates and runDate > hoursAgoUsecs:
                        if restart:
                            out('    %s (%s) %s, restarting...' % (job['name'], jobtype, status))
                            policy = [p for p in policies if p['id'] == job['policyId']][0]

                            # job parameters (base)
                            jobData = {
                                "copyRunTargets": [
                                    {
                                        "type": "kLocal",
                                        "daysToKeep": policy['daysToKeep']
                                    }
                                ],
                                "sourceIds": [],
                                "runType": runType
                            }

                            # replication
                            if 'snapshotReplicationCopyPolicies' in policy:
                                for replica in policy['snapshotReplicationCopyPolicies']:
                                    if replica['target'] not in [p.get('replicationTarget', None) for p in jobData['copyRunTargets']]:
                                        jobData['copyRunTargets'].append({
                                            "daysToKeep": replica['daysToKeep'],
                                            "replicationTarget": replica['target'],
                                            "type": "kRemote"
                                        })

                            # archival
                            if 'snapshotArchivalCopyPolicies' in policy:
                                for archive in policy['snapshotArchivalCopyPolicies']:
                                    if archive['target'] not in [p.get('archivalTarget', None) for p in jobData['copyRunTargets']]:
                                        jobData['copyRunTargets'].append({
                                            "archivalTarget": archive['target'],
                                            "daysToKeep": archive['daysToKeep'],
                                            "type": "kArchival"
                                        })

                            # run job
                            jobId = job['id'].split(':')[2]
                            runNow = api('post', "protectionJobs/run/%s" % jobId, jobData)
                        else:
                            out('    %s (%s) %s' % (job['name'], jobtype, status))
    else:
        out('%s - unable to connect' % clustername)

log.close()
print('\nOutput saved to %s\n' % outfile)
