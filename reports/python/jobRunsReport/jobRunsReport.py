#!/usr/bin/env python
"""job runs report"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-n', '--numruns', type=int, default=100)
parser.add_argument('-y', '--days', type=int, default=7)
parser.add_argument('-units', '--units', type=str, choices=['MB', 'GB', 'mb', 'gb'], default='MB')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
jobname = args.jobname
numruns = args.numruns
days = args.days
units = args.units

multiplier = 1024 * 1024
if units.lower() == 'gb':
    multiplier = 1024 * 1024 * 1024

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
daysBackUsecs = timeAgo(days, 'days')

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'jobRunsReport-%s-%s-%s.csv' % (cluster['name'], jobname, dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Run Date,Run Type,Duration Seconds,Status,Data Read (%s),Data Written (%s),Success,Error\n' % (units, units))

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true', v=2)

job = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
if jobs is None or len(jobs) == 0:
    print('job %s not found' % jobname)
    exit()
else:
    job = job[0]

finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning', 'kCanceling', '3', '4', '5', '6']

endUsecs = nowUsecs

while 1:
    runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true' % (job['id'], numruns, endUsecs), v=2)
    for run in runs['runs']:
        try:
            if 'localBackupInfo' in run:
                info = run['localBackupInfo']
            else:
                info = run['archivalInfo']['archivalTargetResults'][0]
            endUsecs = info['startTimeUsecs'] - 1
            runtype = info['runType'][1:]
            if runtype == 'Regular':
                runType = 'Incremental'
            startTimeUsecs = info['startTimeUsecs']
            if 'endTimeUsecs' in info:
                endTimeUsecs = info['endTimeUsecs']
            else:
                endTimeUsecs = nowUsecs
            durationSecs = round((endTimeUsecs - startTimeUsecs) / 1000000, 0)
            runStartTime = usecsToDate(info['startTimeUsecs'])
            if info['startTimeUsecs'] < daysBackUsecs:
                break
            if 'localSnapshotStats' in info:
                bytesread = round(info['localSnapshotStats']['bytesRead'] / multiplier, 2)
                byteswritten = round(info['localSnapshotStats']['bytesWritten'] / multiplier, 2)
                numsuccess = len([o for o in run['objects'] if o['localSnapshotInfo']['snapshotInfo']['status'] in ['kSuccessful', 'kWarning']])
                numfailed = len([o for o in run['objects'] if o['localSnapshotInfo']['snapshotInfo']['status'] == 'kFailed'])
            else:
                bytesread = ''
                byteswritten = ''
                if 'stats' in info and 'bytesRead' in info['stats']:
                    bytesread = round(info['stats']['bytesRead'] / multiplier, 2)
                if 'stats' in info and 'physicalBytesTransferred' in info['stats']:
                    byteswritten = round(info['stats']['physicalBytesTransferred'] / multiplier, 2)
                numsuccess = ''
                numfailed = ''
            status = info['status']
            print("    %s  %s" % (runStartTime, status))
            f.write('"%s","%s","%s","%s","%s","%s","%s","%s"\n' % (runStartTime, runtype, durationSecs, status, bytesread, byteswritten, numsuccess, numfailed))
        except Exception as e:
            print('exception!')
            pass
    if len(runs['runs']) < numruns:
        break
f.close()
print('\nOutput saved to %s\n' % outfile)
