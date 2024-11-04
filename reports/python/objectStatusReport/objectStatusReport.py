#!/usr/bin/env python
"""Object Status Report"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs
import os

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str)
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-dy', '--days', type=int, default=2)
parser.add_argument('-n', '--numruns', type=int, default=500)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
folder = args.outfolder
days = args.days
useApiKey = args.useApiKey
numruns = args.numruns

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

cluster = api('get', 'cluster')

print('%s: Collecting report data' % cluster['name'])

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
startUsecs = timeAgo(days, 'days')
dateString = now.strftime("%Y-%m-%d")
outfileName = '%s/%s-objectStatusReport.csv' % (folder, dateString)
summaryFileName = '%s/%s-objectStatusReport-summary.csv' % (folder, dateString)

if os.path.isfile(outfileName) is False:
    f = codecs.open(outfileName, 'w', 'utf-8')
    f.write('"Cluster Name","Job Name","Environment","Object Name","Runs","Last Status","Successful","Unsuccessful","Last Error"\n')
else:
    f = codecs.open(outfileName, 'a', 'utf-8')

if os.path.isfile(summaryFileName) is False:
    s = codecs.open(summaryFileName, 'w', 'utf-8')
    s.write('"Cluster Name","Object Count","Successful Objects","Failed Objects","Success Rate"\n')
else:
    s = codecs.open(summaryFileName, 'a', 'utf-8')

jobs = api('get', 'protectionJobs')

objectStats = {}
numObjects = 0
numSuccessfulObjects = 0
numFailedObjects = 0

successStates = ['kSuccess', 'kWarning', 'kAccepted', 'kRunning']
failStates = ['kFailure', 'kCanceled', 'kWaitingToRetry']

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    # only jobs that are supposed to run
    if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False) and ('isPaused' not in job or job['isPaused'] is not True):
        jobId = job['id']
        jobName = job['name']
        print('    %s' % jobName)
        endUsecs = nowUsecs

        runs = [r for r in api('get', 'protectionRuns?jobId=%s&numRuns=%s&startTimeUsecs=%s' % (jobId, numruns, startUsecs)) if 'endTimeUsecs' not in r['backupRun']['stats'] or r['backupRun']['stats']['endTimeUsecs'] < endUsecs]
        if runs is not None:
            runs = sorted(runs, key=lambda r: r['backupRun']['stats']['startTimeUsecs'], reverse=True)
            for run in runs:
                startTimeUsecs = run['backupRun']['stats']['startTimeUsecs']
                if 'sourceBackupStatus' in run['backupRun']:
                    for source in run['backupRun']['sourceBackupStatus']:
                        keyName = '%s---%s' % (job['name'], source['source']['name'])
                        if keyName not in objectStats:
                            objectStats[keyName] = {
                                'jobName': job['name'],
                                'objectName': source['source']['name'],
                                'jobType': job['environment'][1:],
                                'runs': 0,
                                'lastStatus': '',
                                'successful': 0,
                                'unsuccessful': 0,
                                'lastError': '',
                                'lastStatus': '',
                                'counted': False
                            }
                            numObjects += 1
                        if 'status' in source:
                            if objectStats[keyName]['lastStatus'] == '':
                                objectStats[keyName]['lastStatus'] = source['status'][1:]
                            if source['status'] == 'kFailure':
                                if objectStats[keyName]['lastError'] == '':
                                    error = ''
                                    if 'error' in source:
                                        error = source['error']
                                        objectStats[keyName]['lastError'] = error
                            if source['status'] in successStates:
                                if objectStats[keyName]['counted'] is False:
                                    numSuccessfulObjects += 1
                                objectStats[keyName]['successful'] += 1
                            if source['status'] in failStates:
                                if objectStats[keyName]['counted'] is False:
                                    numFailedObjects += 1
                                objectStats[keyName]['unsuccessful'] += 1
                            objectStats[keyName]['runs'] += 1
                            objectStats[keyName]['counted'] = True

for keyName in sorted(objectStats.keys()):
    f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], objectStats[keyName]['jobName'], objectStats[keyName]['jobType'], objectStats[keyName]['objectName'], objectStats[keyName]['runs'], objectStats[keyName]['lastStatus'], objectStats[keyName]['successful'], objectStats[keyName]['unsuccessful'], objectStats[keyName]['lastError']))
f.close()

successRate = round(100 * float(numSuccessfulObjects) / numObjects, 1)
s.write('"%s","%s","%s","%s","%s"\n' % (cluster['name'], numObjects, numSuccessfulObjects, numFailedObjects, successRate))
s.close()
