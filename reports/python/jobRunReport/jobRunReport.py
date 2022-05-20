#!/usr/bin/env python
"""Job Run Report"""

### usage: ./jobRunReport.py -v mycluster -u admin [-d domain]

### import pyhesity wrapper module
from pyhesity import *
import codecs
from datetime import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-l', '--localonly', action='store_true')       # use API key authentication

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
localonly = args.localonly

### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'jobRunReport-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('"Job Name","Status","RunDate","BackupMinutes","Objects","LocalExpiry","ReplicaStatus","ReplicaMinutes","ReplicaExpiry"\n')

### find protectionRuns for last 24 hours

seen = {}
print("{:>20} {:>10}   {:20}".format('JobName', 'Status ', 'StartTime'))
print("{:>20} {:>10}   {:20}".format('-------', '-------', '---------'))

jobs = api('get', 'protectionJobs')
if localonly:
    jobs = [j for j in jobs if 'isActive' not in j or j['isActive'] is not False]

for job in sorted(jobs, key=lambda job: job['name'].lower()):

    runs = api('get', 'protectionRuns?startTimeUsecs=%s&numRuns=100000&jobId=%s' % (timeAgo('24', 'hours'), job['id']))

    for run in runs:

        localDuration = '-'
        replicaDuration = '-'
        objectCount = '-'
        jobName = run['jobName']
        status = run['backupRun']['status'][1:]
        startTime = usecsToDate(run['backupRun']['stats']['startTimeUsecs'])
        if 'backupRun' in run and 'sourceBackupStatus' in run['backupRun'] and run['backupRun']['sourceBackupStatus'] is not None:
            objectCount = len(run['backupRun']['sourceBackupStatus'])
        if 'backupRun' in run and 'stats' in run['backupRun'] and 'startTimeUsecs' in run['backupRun']['stats'] and 'endTimeUsecs' in run['backupRun']['stats']:
            localDuration = (run['backupRun']['stats']['endTimeUsecs'] - run['backupRun']['stats']['startTimeUsecs']) / 60000000
        localExpiry = '-'
        replicaExpiry = '-'
        replicaStatus = '-'
        if 'copyRun' in run and run['copyRun'] is not None:
            for copyRun in run['copyRun']:
                if copyRun['target']['type'] == 'kLocal':
                    if 'expiryTimeUsecs' in copyRun:
                        localExpiry = usecsToDate(copyRun['expiryTimeUsecs'])
                if copyRun['target']['type'] == 'kRemote':
                    if replicaDuration == '-' and 'stats' in copyRun and 'startTimeUsecs' in copyRun['stats'] and 'endTimeUsecs' in copyRun['stats']:
                        replicaDuration = (copyRun['stats']['endTimeUsecs'] - copyRun['stats']['startTimeUsecs']) / 60000000
                    if 'expiryTimeUsecs' in copyRun and replicaExpiry == '-':
                        replicaExpiry = usecsToDate(copyRun['expiryTimeUsecs'])
                    if replicaStatus == '-' and 'status' in copyRun:
                        replicaStatus = copyRun['status'][1:]
                    elif 'status' in copyRun and copyRun['status'] == 'kFailed':
                        replicaStatus = copyRun['status'][1:]

        if jobName not in seen:
            seen[jobName] = True
            print("{:>20} {:>10}   {:20}".format(jobName, status, startTime))
            f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, status, startTime, localDuration, objectCount, localExpiry, replicaStatus, replicaDuration, replicaExpiry))

f.close()
print('\nOutput saved to %s\n' % outfile)
