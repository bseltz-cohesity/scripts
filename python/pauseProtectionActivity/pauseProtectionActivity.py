#!/usr/bin/env python
"""pause or resume protection jobs"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import os
import codecs
import json
import sys
import urllib3
from time import sleep
import requests.packages.urllib3

if sys.version_info.major >= 3 and sys.version_info.minor >= 5:
    from urllib.parse import quote_plus
else:
    from urllib import quote_plus

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-r', '--resume', action='store_true')
parser.add_argument('-p', '--pause', action='store_true')
parser.add_argument('-o', '--outpath', type=str, default='.')
parser.add_argument('-l', '--nojoblist', action='store_true')
parser.add_argument('-c', '--cancelrunsonly', action='store_true')
parser.add_argument('-g', '--stopgconly', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
pause = args.pause
resume = args.resume
outpath = args.outpath
nojoblist = args.nojoblist
cancelrunsonly = args.cancelrunsonly
stopgconly = args.stopgconly

requests.packages.urllib3.disable_warnings()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def setGflag(servicename, flagname, flagvalue, reason, clear=False):
    gflag = {
        'serviceName': servicename,
        'gflags': [
            {
                'name': flagname,
                'value': flagvalue,
                'reason': reason
            }
        ],
        'effectiveNow': True
    }
    if clear is True:
        gflag['clear'] = True
    response = api('put', '/clusters/gflag', gflag)


if resume and pause:
    print('please choose either -p (--pause) or -r (--resume), but not both')
    exit()

if cancelrunsonly:
    pause = True
    resume = False

if stopgconly and (not pause and not resume):
    print('please choose either -p (--pause) or -r (--resume), but not both')
    exit()


def out(message, quiet=False):
    if quiet is not True:
        print(message)
    log.write('%s\n' % message)


### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode)

if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    exit(1)

print('')

cluster = api('get', 'cluster')

# open output files
now = datetime.now()
dateString = now.strftime("%Y-%m-%d")
startDateString = now.strftime("%Y-%m-%d %H:%M:%S")

logfile = os.path.join(outpath, 'pauseLog-%s.txt' % cluster['name'])
log = codecs.open(logfile, 'a')

log.write('\nScript started at %s ********************************************************\n' % startDateString)
log.write('\nCommand line parameters:\n\n')
for arg, value in vars(args).items():
    if arg not in ['password', 'mfacode', 'noprompt']:
        log.write("    %s: %s\n" % (arg, value))
log.write('\n')

# read job list
jobnames = []
if resume:
    jobList = os.path.join(outpath, 'jobsPaused-%s.txt' % cluster['name'])
    if nojoblist is not True:
        if not os.path.exists(jobList):
            out('job list %s not found!' % jobList)
            log.close()
            exit(1)
        f = open(jobList, 'r')
        jobnames += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()

jobs = api('get', 'protectionJobs?isActive=true&isDeleted=false&onlyReturnBasicSummary=true')

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    out('Jobs not found: %s' % ', '.join(notfoundjobs))

if resume is True:
    action = 'kResume'
    actiontext = 'Resuming'
elif pause is True:
    action = 'kPause'
    actiontext = 'Pausing'
else:
    action = 'show'
jobIds = []

runningStates = ['kAccepted', 'kRunning']

if action == 'kPause':
    outfile = os.path.join(outpath, 'jobsPaused-%s.txt' % cluster['name'])
    f = codecs.open(outfile, 'w')

# pause protection jobs =======================================================
if not cancelrunsonly and not stopgconly:
    for job in sorted(jobs, key=lambda job: job['name'].lower()):
        if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
            if action == 'show':
                if 'isPaused' in job and job['isPaused'] is True:
                    out("%s (paused)" % job['name'])
                else:
                    out("%s (active)" % job['name'])
            else:
                if ('isPaused' in job and job['isPaused'] is True and action == 'kResume') or (('isPaused' not in job or job['isPaused'] is False) and action == 'kPause'):
                    out("%s protection group: %s" % (actiontext, job['name']))
                    jobIds.append(job['id'])
                    if action == 'kPause':
                        f.write('%s\n' % job['name'])

    if len(jobIds) > 0:
        result = api('post', 'protectionJobs/states', {"action": action, "jobIds": jobIds})

    if action == 'kPause':
        f.close()

# cancel protection runs ======================================================
if not stopgconly:
    foundRuns = False
    for job in sorted(jobs, key=lambda job: job['name'].lower()):
        if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
            if action == 'kPause':
                runs = api('get', 'protectionRuns?jobId=%s&numRuns=20&excludeTasks=true' % job['id'])
                if runs is not None and len(runs) > 0:
                    for run in runs:
                        if run['backupRun']['status'] in runningStates:
                            out('Canceling job run: %s: %s' % (job['name'], usecsToDate(run['backupRun']['stats']['startTimeUsecs'])))
                            result = api('post', 'protectionRuns/cancel/%s' % job['id'], {"jobRunId": run['backupRun']['jobRunId']})
                            foundRuns = True
    if action == 'kPause' and foundRuns is False:
        out('No runs to cancel')

# replication =================================================================
if not cancelrunsonly and not stopgconly:
    if action in ['kPause', 'kResume']:
        remoteClusters = api('get', 'remoteClusters')
        if remoteClusters is not None and len(remoteClusters) > 0:
            for remoteCluster in remoteClusters:
                if action == 'kPause':
                    out('%s replication to %s' % (actiontext, remoteCluster['name']))
                    if 'bandwidthLimit' not in remoteCluster or 'rateLimitBytesPerSec' not in remoteCluster['bandwidthLimit']:
                        remoteCluster['bandwidthLimit'] = {
                            "rateLimitBytesPerSec": None,
                            "bandwidthLimitOverrides": [],
                            "timezone": "America/New_York"
                        }
                    if 'bandwidthLimitOverrides' not in remoteCluster['bandwidthLimit']:
                        remoteCluster['bandwidthLimit']['bandwidthLimitOverrides'] = []
                    remoteCluster['bandwidthLimit']['bandwidthLimitOverrides'].append({
                        "bytesPerSecond": 0,
                        "timePeriods": {
                            "days": [
                                "kWednesday",
                                "kSunday",
                                "kMonday",
                                "kTuesday",
                                "kThursday",
                                "kFriday",
                                "kSaturday"
                            ],
                            "startTime": {
                                "hour": 0,
                                "minute": 0
                            },
                            "endTime": {
                                "hour": 23,
                                "minute": 59
                            }
                        }
                    })
                if action == 'kResume':
                    out('%s replication to %s' % (actiontext, remoteCluster['name']))
                    if 'bandwidthLimit' in remoteCluster and 'bandwidthLimitOverrides' in remoteCluster['bandwidthLimit'] and len(remoteCluster['bandwidthLimit']['bandwidthLimitOverrides']) > 0:
                        remoteCluster['bandwidthLimit']['bandwidthLimitOverrides'] = [o for o in remoteCluster['bandwidthLimit']['bandwidthLimitOverrides'] if not (o['bytesPerSecond'] == 0
                                                                                      and len(o['timePeriods']['days']) == 7
                                                                                      and o['timePeriods']['startTime']['hour'] == 0 and o['timePeriods']['startTime']['minute'] == 0
                                                                                      and o['timePeriods']['endTime']['hour'] == 23 and o['timePeriods']['endTime']['minute'] == 59)]
                result = api('put', 'remoteClusters/%s' % remoteCluster['clusterId'], remoteCluster)

# archival ====================================================================
if not cancelrunsonly and not stopgconly:
    if action in ['kPause', 'kResume']:
        out('%s archival' % actiontext)
        settings = api('get', 'vaults/bandwidthSettings')
        archivesettings = os.path.join(outpath, 'archivesettings-%s.txt' % cluster['name'])
        if action == 'kPause':
            if settings is not None:
                f = codecs.open(archivesettings, 'w')
                f.write(json.dumps(settings, sort_keys=True, indent=4, separators=(', ', ': ')))
                f.close()
            settings = {
                "upload": {
                    "rateLimitBytesPerSec": 0,
                    "timezone": "America/New_York"
                }
            }
            result = api('put', 'vaults/bandwidthSettings', settings)
        if action == 'kResume':
            if os.path.exists(archivesettings):
                settings = json.loads(open(archivesettings, 'r').read())
        else:
            settings = {}
        result = api('put', 'vaults/bandwidthSettings', settings)

# indexing ====================================================================
if not cancelrunsonly and not stopgconly:
    if action in ['kPause', 'kResume']:
        out('%s indexing' % actiontext)
        if action == 'kPause':
            setGflag(servicename='kYoda', flagname='yoda_block_slave_dispatcher', flagvalue='true', reason='pause')
        if action == 'kResume':
            setGflag(servicename='kYoda', flagname='yoda_block_slave_dispatcher', flagvalue='false', reason='resume', clear=True)
        restartParams = {
            'action': 'kRestart',
            'services': ['kYoda']
        }
        restart = api('post', 'clusters/services/states', restartParams)

# apollo service ==============================================================
if not cancelrunsonly:
    if action in ['kPause', 'kResume']:
        if action == 'kPause':
            restartParams = {
                'action': 'kStop',
                'services': ['kApollo']
            }
            response = api('post', 'clusters/services/states', restartParams)
        if action == 'kResume':
            restartParams = {
                'action': 'kStart',
                'services': ['kApollo']
            }
            response = api('post', 'clusters/services/states', restartParams)

# apollo pipeline =============================================================
if not cancelrunsonly:
    if action in ['kPause', 'kResume']:
        out('%s background maintenance services' % actiontext)
    if action == 'kPause':
        nodes = api('get', 'nodes')
        context = getContext()
        cookies = context['COOKIES']
        for node in nodes:
            try:
                apollo = context['SESSION'].get('https://%s/siren/v1/remote?relPath=&remoteUrl=http' % vip + quote_plus('://') + node['ip'] + quote_plus(':') + '24680' + quote_plus('/'), verify=False, headers=context['HEADER'], cookies=cookies)
                masterpath = str(apollo.content).split('Master V2 Location')[1].split('Is Running on App Node')[0].split('href="')[1].split('">')[0]
                cancel = context['SESSION'].get('https://%s%s' % (vip, masterpath) + quote_plus('/cancel?pipeline_name=Healer'), verify=False, headers=context['HEADER'], cookies=cookies)
                out('Canceled background maintenance processes')
                break
            except Exception:
                out('*** exception trying to stop pipeline')
                pass

if not cancelrunsonly and not stopgconly:
    if action == 'kPause':
        out('Paused job list saved to %s' % outfile)

out('waiting for service restart...')
out('')
log.close()
allFinished = False
cluster = api('get', 'cluster')
while allFinished is False:
    if cluster['currentOperation'] == 'kRestartServices':
        sleep(10)
        cluster = api('get', 'cluster')
    else:
        allFinished = True

print('Output logged to %s\n' % logfile)
