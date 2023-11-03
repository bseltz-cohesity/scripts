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
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--numruns', type=int, default=100)
parser.add_argument('-y', '--days', type=int, default=1)
parser.add_argument('-o', '--lastrunonly', action='store_true')
parser.add_argument('-l', '--includelogs', action='store_true')
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='MiB')  # units

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
emailmfacode = args.emailmfacode
numruns = args.numruns
days = args.days
lastrunonly = args.lastrunonly
includelogs = args.includelogs
units = args.units

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

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
outfile = 'oracleBackupReport-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Job Name,Host Name,Database Name,UUID,Run Type,Start Time,End Time,Duration (Sec),DB Size (%s),Data Read (%s),Status,DB Type,DG Role\n' % (units, units))

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kOracle', v=2)

daysAgo = timeAgo(days, 'days')

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):

    print(job['name'])
    endUsecs = nowUsecs
    while 1:
        runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&startTimeUsecs=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true' % (job['id'], numruns, daysAgo, endUsecs), v=2)
        if len(runs['runs']) > 0:
            endUsecs = runs['runs'][-1]['localBackupInfo']['startTimeUsecs'] - 1
        else:
            break
        for run in runs['runs']:
            runtype = run['localBackupInfo']['runType'][1:]
            if runtype == 'Regular':
                runtype = 'Incremental'
            if runtype != 'Log' or includelogs:
                runStartTime = usecsToDate(run['localBackupInfo']['startTimeUsecs'])
                if 'endTimeUsecs' in run['localBackupInfo']:
                    if 'objects' in run:
                        for object in run['objects']:
                            if object['object']['objectType'] == 'kDatabase':
                                dgRole = ''
                                dbSource = api('get', 'protectionSources?id=%s' % object['object']['id'])
                                dbType = dbSource[0]['protectionSource']['oracleProtectionSource']['dbType']
                                if 'dataGuardInfo' in dbSource[0]['protectionSource']['oracleProtectionSource']:
                                    dgRole = dbSource[0]['protectionSource']['oracleProtectionSource']['dataGuardInfo']['role']
                                hostobject = [o for o in run['objects'] if o['object']['id'] == object['object']['sourceId']]
                                hostname = hostobject[0]['object']['name']
                                dbname = object['object']['name']
                                uuid = object['object']['uuid']
                                snapinfo = object['localSnapshotInfo']['snapshotInfo']
                                status = snapinfo['status'][1:]
                                starttime = usecsToDate(snapinfo['startTimeUsecs'])
                                endtime = usecsToDate(snapinfo['endTimeUsecs'])
                                duration = round((snapinfo['endTimeUsecs'] - snapinfo['startTimeUsecs']) / 1000000)
                                dbsize = round(snapinfo['stats']['logicalSizeBytes'] / multiplier, 2)
                                dataread = round(snapinfo['stats']['bytesRead'] / multiplier, 2)
                                print("    %s  %s/%s  (%s)  %s" % (runStartTime, hostname, dbname, runtype, status))
                                f.write('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' % (job['name'], hostname, dbname, uuid, runtype, starttime, endtime, duration, dbsize, dataread, status, dbType, dgRole))
                    if lastrunonly:
                        break
f.close()
print('\nOutput saved to %s\n' % outfile)
