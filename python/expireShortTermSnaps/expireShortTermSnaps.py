#!/usr/bin/env python
"""expire old short term snapshots"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

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
parser.add_argument('-mm', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-m', '--minutestokeep', type=int, default=120)   # (optional) number of minutes to retain snapshots, defaults to 120
parser.add_argument('-n', '--numsnapstokeep', type=int, default=2)    # (optional) number of snaps to retain, defaults to 2
parser.add_argument('-j', '--jobname', type=str, action='append')     # (optional) job names to include
parser.add_argument('-l', '--joblist', type=str)                      # (optional) text file of job names
parser.add_argument('-e', '--expire', action='store_true')            # (optional) expire
parser.add_argument('-f', '--maxlogfilesize', type=int, default=100000)  # max size to truncate log

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
minutestokeep = args.minutestokeep
numsnapstokeep = args.numsnapstokeep
jobnames = args.jobname
joblist = args.joblist
expire = args.expire
maxlogfilesize = args.maxlogfilesize

# truncate log file
logfilename = 'log-expireOldShortTermSnaps.txt'
try:
    log = codecs.open(logfilename, 'r', 'utf-8')
    logfile = log.read()
    log.close()
    if len(logfile) > maxlogfilesize:
        lines = logfile.split('\n')
        linecount = int(len(lines) / 2)
        log = codecs.open(logfilename, 'w')
        log.writelines('\n'.join(lines[linecount:]))
        log.close()
except Exception:
    pass


def out(outstring):
    print(outstring)
    log.write('%s\n' % outstring)


def bailout():
    log.close()
    exit(1)


# open log file
log = codecs.open(logfilename, 'a', 'utf-8')
date = datetime.now().strftime("%m/%d/%Y %H:%M:%S")
out('\n----------------------------\nStarted: %s\n----------------------------\n' % date)

# gather job names
if jobnames is None:
    jobnames = []
if joblist is not None:
    f = open(joblist, 'r')
    jobnames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
if len(jobnames) == 0:
    out('no jobs specified')
    bailout()
jobnames = [j.lower() for j in jobnames]

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

nowUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

jobs = [j for j in api('get', 'protectionJobs') if j['name'].lower() in jobnames]

# warn on missing jobs
for jobname in jobnames:
    if len([j for j in jobs if jobname.lower() == j['name'].lower()]) == 0:
        out('Warning: job not found: %s\n' % jobname)

if len(jobs) > 0:
    for job in jobs:
        expirecount = 0
        out('%s' % job['name'])
        runs = api('get', 'protectionRuns?jobId=%s&numRuns=1440&excludeTasks=true&excludeNonRestoreableRuns=true' % job['id'])
        unexpiredruns = [r for r in runs if r['backupRun']['snapshotsDeleted'] is not True and r['backupRun']['status'] in ['kSuccess', 'kWarning']]
        # find runs with short retention (1 day)
        shorttermruns = []
        for run in unexpiredruns:
            localrun = [c for c in run['copyRun'] if c['target']['type'] == 'kLocal']
            if localrun is not None and len(localrun) > 0:
                if 'expiryTimeUsecs' in localrun[0] and 'runStartTimeUsecs' in localrun[0]:
                    expiryTimeUsecs = localrun[0]['expiryTimeUsecs']
                    runStartTimeUsecs = localrun[0]['runStartTimeUsecs']
                    if (expiryTimeUsecs - runStartTimeUsecs) < 172000000000:
                        shorttermruns.append(run)
        # keep minimum number of snaps
        if len(shorttermruns) > numsnapstokeep:
            shorttermruns = shorttermruns[numsnapstokeep:]
            for run in shorttermruns:
                jobUid = run['jobUid']
                starttime = run['backupRun']['stats']['startTimeUsecs']
                # expire short term snaps that are older than minutestokeep
                if (nowUsecs - starttime) > (minutestokeep * 60000000):
                    expirecount += 1
                    if expire:
                        expireRun = {
                            "jobRuns": [
                                {
                                    "expiryTimeUsecs": 0,
                                    "jobUid": jobUid,
                                    "runStartTimeUsecs": starttime,
                                    "copyRunTargets": [
                                        {
                                            "daysToKeep": 0,
                                            "type": "kLocal",
                                        }
                                    ]
                                }
                            ]
                        }
                        out("    Expiring %s snapshot from %s" % (job['name'], usecsToDate(starttime)))
                        api('put', 'protectionRuns', expireRun)
                    else:
                        out("    Would expire %s snapshot from %s" % (job['name'], usecsToDate(starttime)))
        if expirecount == 0:
            out('    No runs to expire')
print('')
log.close()
