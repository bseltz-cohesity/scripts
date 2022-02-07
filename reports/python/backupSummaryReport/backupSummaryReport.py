#!/usr/bin/env python
"""Backup Summary Report"""

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-n', '--units', type=str, choices=['KiB', 'MiB', 'GiB', 'TiB'], default='MiB')
parser.add_argument('-y', '--days', type=int, default=7)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
units = args.units
days = args.days
password = args.password
useApiKey = args.useApiKey

multiplier = 1024 * 1024
if units.lower() == 'kib':
    multiplier = 1024
if units.lower() == 'gib':
    multiplier = 1024 * 1024 * 1024
if units.lower() == 'tib':
    multiplier = 1024 * 1024 * 1024 * 1024

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

now = datetime.now()
nowUsecs = dateToUsecs()
daysbackusecs = timeAgo(days, 'days')

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'backupSummaryReport-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Protection Group,Type,Source,Successful Runs,Failed Runs,Last Run Successful Objects,Last Run Failed Objects,Data Read Total %s,Data Written Total %s,SLA Violation,Last Run Status,Last Run Date,Message\n' % (units, units))

environments = ['kUnknown', 'kVMware', 'kHyperV', 'kSQL', 'kView', 'kPuppeteer',
                'kPhysical', 'kPure', 'kAzure', 'kNetapp', 'kAgent', 'kGenericNas',
                'kAcropolis', 'kPhysicalFiles', 'kIsilon', 'kKVM', 'kAWS', 'kExchange',
                'kHyperVVSS', 'kOracle', 'kGCP', 'kFlashBlade', 'kAWSNative', 'kVCD',
                'kO365', 'kO365Outlook', 'kHyperFlex', 'kGCPNative', 'kAzureNative',
                'kAD', 'kAWSSnapshotManager', 'kGPFS', 'kRDSSnapshotManager', 'kUnknown', 'kKubernetes',
                'kNimble', 'kAzureSnapshotManager', 'kElastifile', 'kCassandra', 'kMongoDB',
                'kHBase', 'kHive', 'kHdfs', 'kCouchbase', 'kUnknown', 'kUnknown', 'kUnknown']

slaViolation = {False: 'Pass', True: 'Fail'}

finishedStates = ['Succeeded', 'Canceled', 'Failed', 'Warning']

summary = api('get', '/backupjobssummary?_includeTenantInfo=true&allUnderHierarchy=false&endTimeUsecs=%s&onlyReturnJobDescription=false&startTimeUsecs=%s' % (nowUsecs, daysbackusecs))

for job in sorted(summary, key=lambda j: j['backupJobSummary']['jobDescription']['name'].lower()):

    jobName = job['backupJobSummary']['jobDescription']['name']
    jobType = environments[job['backupJobSummary']['jobDescription']['type']][1:]
    source = job['backupJobSummary']['jobDescription']['parentSource']['displayName']
    if jobType == 'View':
        source = job['backupJobSummary']['jobDescription']['sources'][0]['entities'][0]['displayName']
    if jobType == 'Puppeteer':
        source = job['backupJobSummary']['jobDescription']['preScript']['remoteHostParams']['hostAddress']
    if 'lastProtectionRun' in job['backupJobSummary']:
        successfulRuns = 0
        if 'numSuccessfulJobRuns' in job['backupJobSummary']:
            successfulRuns = job['backupJobSummary']['numSuccessfulJobRuns']
        failedRuns = 0
        if 'numFailedJobRuns' in job['backupJobSummary']:
            failedRuns = job['backupJobSummary']['numFailedJobRuns']
        dateRead = job['backupJobSummary']['totalBytesReadFromSource']
        dataWritten = 0
        if 'totalPhysicalBackupSizeBytes' in job['backupJobSummary']:
            dataWritten = job['backupJobSummary']['totalPhysicalBackupSizeBytes']
        slaViolated = 'Pass'
        if 'slaViolated' in job['backupJobSummary']['lastProtectionRun']['backupRun']['base']:
            slaViolated = slaViolation[job['backupJobSummary']['lastProtectionRun']['backupRun']['base']['slaViolated']]
        lastRunStatus = job['backupJobSummary']['lastProtectionRun']['backupRun']['base']['publicStatus'][1:]
        if lastRunStatus == 'Warning':
            message = job['backupJobSummary']['lastProtectionRun']['backupRun']['base']['warnings'][0]['errorMsg']
        elif(lastRunStatus == 'Failure'):
            message = job['backupJobSummary']['lastProtectionRun']['backupRun']['base']['error']['errorMsg']
        else:
            message = ''
        if len(message) > 100:
            message = message[0:100]
        lastRunDate = usecsToDate(job['backupJobSummary']['lastProtectionRun']['backupRun']['base']['startTimeUsecs'])
        lastRunSuccessObjects = job['backupJobSummary']['lastProtectionRun']['backupRun']['numSuccessfulTasks']
        lastRunFailedObjects = job['backupJobSummary']['lastProtectionRun']['backupRun']['numFailedTasks']
        f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, jobType, source, successfulRuns, failedRuns, lastRunSuccessObjects, lastRunFailedObjects, round(dateRead / multiplier, 2), round(dataWritten / multiplier, 2), slaViolated, lastRunStatus, lastRunDate, message))

print('\nOutput saved to %s\n' % outfile)
