#!/usr/bin/env python
"""base V2 example"""

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
parser.add_argument('-m', '--mfacode', type=str, default=None)
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

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

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

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
# dateString = now.strftime("%Y-%m-%d")
outfile = 'jobReport-%s.csv' % (cluster['name'])
f = codecs.open(outfile, 'w')

# headings
f.write('Job Name,Tenant,Run Date,Duration Secs,Success Count,Error Count,SLA Violated,Status,Replica Status,Archive Status\n')

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true', v=2)

if jobs['protectionGroups'] is None:
    print('no jobs found')
    exit()

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):

    if len(job['permissions']) > 0 and 'name' in job['permissions'][0]:
        tenant = job['permissions'][0]['name']
        print('%s (%s)' % (job['name'], tenant))
    else:
        tenant = ''
        print('%s' % job['name'])
    if 'lastRun' in job:
        replicaStatus = ''
        archivalStatus = ''
        run = job['lastRun']
        cad = False
        if 'localBackupInfo' in run:
            backupInfo = run['localBackupInfo']
        elif 'originalBackupInfo' in run:
            backupInfo = run['originalBackupInfo']
        else:
            backupInfo = run['archivalInfo']['archivalTargetResults'][0]
            cad = True
        runStartTime = usecsToDate(backupInfo['startTimeUsecs'])
        status = backupInfo['status']
        pstatus = backupInfo['status']
        if cad is True:
            archivalStatus = backupInfo['status']
            status = ''                
        isSlaViolated = backupInfo['isSlaViolated']
        durationSecs = '-'
        if 'endTimeUsecs' in backupInfo:
            durationSecs = round((backupInfo['endTimeUsecs'] - backupInfo['startTimeUsecs']) / 1000000, 0)
        successfulObjectsCount = backupInfo['successfulObjectsCount']
        if backupInfo['successfulAppObjectsCount'] > successfulObjectsCount:
            successfulObjectsCount = backupInfo['successfulAppObjectsCount']
        failedObjectsCount = backupInfo['failedObjectsCount']
        if backupInfo['failedAppObjectsCount'] > failedObjectsCount:
            failedObjectsCount = backupInfo['failedAppObjectsCount']
        if cad is False:
            if 'replicationInfo' in run:
                replicaStatus = 'Succeeded'
                for reptarget in run['replicationInfo']['replicationTargetResults']:
                    if reptarget['status'] != 'Succeeded':
                        replicaStatus = reptarget['status']
            
            if 'archivalInfo' in run:
                archivalStatus = 'Succeeded'
                for archtarget in run['archivalInfo']['archivalTargetResults']:
                    if archtarget['status'] != 'Succeeded':
                        archivalStatus = archtarget['status']
        print("    %s  %s" % (runStartTime, pstatus))
        f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (job['name'], tenant, runStartTime, durationSecs, successfulObjectsCount, failedObjectsCount, isSlaViolated, status, replicaStatus, archivalStatus))

f.close()
print('\nOutput saved to %s\n' % outfile)
