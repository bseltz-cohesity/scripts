#!/usr/bin/env python
"""Archive End of Month for python"""

# usage: ./archiveEndOfMonth.py -v mycluster -u myuser -d mydomain.net -j MyJob -k 365 -t myarchivetarget

# import pyhesity wrapper module
import sys
import os
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-j', '--jobname', action='append', type=str, required=True)   # job name
parser.add_argument('-k', '--keepfor', type=int, required=True)    # (optional) will use policy retention if omitted
parser.add_argument('-t', '--targetname', type=str, required=True)  # (optional) will use policy target if omitted

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobnames = args.jobname
keepfor = args.keepfor
targetname = args.targetname

# Log
SCRIPTFOLDER = sys.path[0]
LOGFILE = os.path.join(SCRIPTFOLDER, 'log-archiveEndOfMonth.txt')
log = open(LOGFILE, 'w')
log.write('started at %s\n' % datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

# authenticate
apiauth(vip, username, domain)

# find cloud archive target
vault = [vault for vault in api('get', 'vaults') if vault['name'].lower() == targetname.lower()]
if len(vault) > 0:
    vault = vault[0]
    target = {
        "vaultId": vault['id'],
        "vaultName": vault['name'],
        "vaultType": "kCloud"
    }
else:
    print('No archive target named %s' % targetname)
    log.write('No archive target named %s\n\n' % targetname)
    log.close()
    exit()

for jobname in jobnames:
    # find protection job
    job = [job for job in api('get', 'protectionJobs?isActive=true') if job['name'].lower() == jobname.lower()]
    if not job:
        print("Job '%s' not found" % jobname)
        log.write("Job '%s' not found\n" % jobname)
        continue
    else:
        job = job[0]

    # find requested run
    runs = api('get', 'protectionRuns?jobId=%s&startTimeUsecs=%s&runTypes=kRegular,kFull' % (job['id'], timeAgo(1, 'month')))

    now = datetime.now()
    thismonth = now.month

    foundRun = False
    for run in runs:
        if foundRun is False:
            runStartTimeUsecs = run['copyRun'][0]['runStartTimeUsecs']
            runStartTime = datetime.strptime(usecsToDate(runStartTimeUsecs), '%Y-%m-%d %H:%M:%S')

            # find last run of last month
            if runStartTime.month != thismonth:
                print('%s - last run of the month was: %s' % (jobname, runStartTime))
                log.write('%s - last run of the month was: %s\n' % (jobname, runStartTime))
                foundRun = True
                currentExpiry = None

                # check for existing archive
                foundArchive = False
                for copyRun in run['copyRun']:

                    if copyRun['target']['type'] == 'kArchival':
                        existingtarget = copyRun['target']['archivalTarget']
                        if existingtarget['vaultName'] == target['vaultName']:
                            print('%s - found existing archive for: %s' % (jobname, runStartTime))
                            log.write('%s - found existing archive for: %s\n' % (jobname, runStartTime))
                            foundArchive = True

                if foundArchive is False:

                    # let's archive this run
                    daysToKeep = keepfor - dayDiff(dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")), run['copyRun'][0]['runStartTimeUsecs'])

                    archiveTask = {
                        "jobRuns": [
                            {
                                "copyRunTargets": [
                                    {
                                        "archivalTarget": target,
                                        "type": "kArchival",
                                        "daysToKeep": int(daysToKeep)
                                    }
                                ],
                                "runStartTimeUsecs": run['copyRun'][0]['runStartTimeUsecs'],
                                "jobUid": run['jobUid']
                            }
                        ]
                    }
                    if run['backupRun']['snapshotsDeleted'] is False:
                        print('%s - archiving snapshot from: %s...' % (jobname, runStartTime))
                        log.write('%s - archiving snapshot from: %s...\n' % (jobname, runStartTime))
                        result = api('put', 'protectionRuns', archiveTask)
                    else:
                        print('%s - local snapshot already deleted for: %s' % (jobname, runStartTime))
                        log.write('%s - local snapshot already deleted for: %s\n' % (jobname, runStartTime))
log.write('\n')
log.close()
