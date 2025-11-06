#!/usr/bin/env python
"""base V1 example"""

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
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-n', '--numruns', type=int, default=5000)
parser.add_argument('-a', '--addhold', action='store_true')
parser.add_argument('-r', '--removehold', action='store_true')
parser.add_argument('-t', '--showtrue', action='store_true')
parser.add_argument('-f', '--showfalse', action='store_true')
parser.add_argument('-p', '--pushtoreplicas', action='store_true')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
jobnames = args.jobname
joblist = args.joblist
numruns = args.numruns
addhold = args.addhold
removehold = args.removehold
showtrue = args.showtrue
showfalse = args.showfalse
pushtoreplicas = args.pushtoreplicas

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'legalHoldReport-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Job Name,Run Date,Status\n')


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


jobnames = gatherList(jobnames, joblist, name='jobs', required=False)

jobs = api('get', 'protectionJobs')

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

if addhold:
    holdValue = True
    actionString = 'adding hold'
elif removehold:
    holdValue = False
    actionString = 'removing hold'
else:
    actionString = 'checking'
    if not showtrue and not showfalse:
        showtrue = True
        showfalse = True

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('%s' % job['name'])
        endUsecs = nowUsecs
        while 1:
            runs = api('get', 'protectionRuns?jobId=%s&numRuns=%s&endTimeUsecs=%s&excludeTasks=true' % (job['id'], numruns, endUsecs))
            if len(runs) > 0:
                endUsecs = runs[-1]['backupRun']['stats']['startTimeUsecs'] - 1
            else:
                break
            for run in runs:
                held = False
                copyRunsFound = False
                if 'copyRun' in run and run['copyRun'] is not None and len(run['copyRun']) > 0:
                    for copyRun in run['copyRun']:
                        if pushtoreplicas is True or copyRun['target']['type'] in ['kLocal', 'kArchival']:
                            if 'expiryTimeUsecs' in copyRun and copyRun['expiryTimeUsecs'] > dateToUsecs():
                                copyRunsFound = True
                            if 'holdForLegalPurpose' in copyRun and copyRun['holdForLegalPurpose'] is True:
                                held = True
                    if copyRunsFound is True or held is True:
                        if (addhold and copyRunsFound is True and held is False) or (removehold and held is True):
                            runParams = {
                                "jobRuns": [
                                    {
                                        "copyRunTargets": [],
                                        "runStartTimeUsecs": run['backupRun']['stats']['startTimeUsecs']
                                    }
                                ]
                            }
                            update = False
                            for copyRun in run['copyRun']:
                                if pushtoreplicas is True or copyRun['target']['type'] in ['kLocal', 'kArchival']:
                                    if (addhold and 'expiryTimeUsecs' in copyRun and copyRun['expiryTimeUsecs'] > dateToUsecs()) or (removehold and held is True):
                                        update = True
                                        copyRunTarget = copyRun['target']
                                        copyRunTarget['holdForLegalPurpose'] = holdValue
                                        runParams['jobRuns'][0]['copyRunTargets'].append(copyRunTarget)
                            if update is True:
                                thisRun = api('get', '/backupjobruns?id=%s&exactMatchStartTimeUsecs=%s' % (run['jobId'], run['backupRun']['stats']['startTimeUsecs']))
                                jobUid = {
                                    "clusterId": thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']['clusterId'],
                                    "clusterIncarnationId": thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']['clusterIncarnationId'],
                                    "id": thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobUid']['objectId']
                                }
                                runParams['jobRuns'][0]['jobUid'] = jobUid
                                print('    %s - %s' % (usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), actionString))
                                f.write('%s,%s,%s\n' % (job['name'], usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), actionString))
                                result = api('put', 'protectionRuns', runParams)
                        else:
                            if (showtrue and held is True) or (addhold and held is True):
                                print('    %s - %s' % (usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), 'on hold'))
                                f.write('%s,%s,%s\n' % (job['name'], usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), 'on hold'))
                            if (showfalse and held is False) or (removehold and held is False):
                                print('    %s - %s' % (usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), 'not on hold'))
                                f.write('%s,%s,%s\n' % (job['name'], usecsToDate(run['backupRun']['stats']['startTimeUsecs'], fmt='%Y-%m-%d %H:%M'), 'not on hold'))
f.close()
print('\nOutput saved to %s\n' % outfile)
