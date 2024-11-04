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
parser.add_argument('-j', '--jobname', type=str, default=None)
parser.add_argument('-N', '--dbname', type=str, default=None)
parser.add_argument('-U', '--dbuuid', type=str, default=None)

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
jobname=args.jobname
argdbname=args.dbname
argdbuuid=args.dbuuid

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
f.write('Job Name,Host Name,Database Name,UUID,Run Type,Start Time,End Time,Duration (Sec),DB Size (%s),Data Read (%s),Status,DB Type,DG Role,PulseUpdate,Attempts\n' % (units, units))

def PrintDBRunSummary(localSnapshotInfo, jobname, hostname, dbname, uuid, runtype, dbType, dgRole, latestPulseUpdate) :
  if localSnapshotInfo is None:
    f.write('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' % (jobname, hostname, dbname, uuid, runtype, 'NA', 'NA', 'NA', 'NA', 'NA','NA', dbType, dgRole, latestPulseUpdate))
    return
  snapinfo = localSnapshotInfo['snapshotInfo']
  status = snapinfo['status'][1:]
  starttime = -1
  if 'startTimeUsecs' in snapinfo:
    starttime = usecsToDate(snapinfo['startTimeUsecs'])

  summary = '%s,%s,%s,%s,%s,%s' % (jobname, hostname, dbname, uuid, runtype, starttime)

  endtime=-1
  duration=-1
  dbsize=-1
  dataread=-1
  if status == "Successful":
    endtime = usecsToDate(snapinfo['endTimeUsecs'])
    duration = round((snapinfo['endTimeUsecs'] - snapinfo['startTimeUsecs']) / 1000000)
    dbsize = round(snapinfo['stats']['logicalSizeBytes'] / multiplier, 2)
    dataread = round(snapinfo['stats']['bytesRead'] / multiplier, 2)
  summary += ',%s,%s,%s,%s,%s,%s,%s,%s' % (endtime, duration, dbsize, dataread,status, dbType, dgRole, latestPulseUpdate)
  attemptsummary=''
  if localSnapshotInfo['failedAttempts'] != None:
    for idx, failedAttempt in enumerate(localSnapshotInfo['failedAttempts']) :
      # print(idx)
      if 'endTimeUsecs' in failedAttempt:
        attemptsummary += '#AttemptNum:%s#Endtime:%s' % (idx, usecsToDate(failedAttempt['endTimeUsecs']))
      if 'status' in failedAttempt:
        attemptsummary += '#status%s' % failedAttempt['status']
      if 'message' in failedAttempt:
        attemptsummary += '#message%s' % failedAttempt['message']
  if attemptsummary != '':
    summary += ',' + attemptsummary
  summary += '\n'
  f.write(summary)



jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kOracle', v=2)

daysAgo = timeAgo(days, 'days')

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if jobname != None and jobname != job['name']:
        #print("Skipping job %s" % jobname)
        continue
    print(job['name'])
    endUsecs = -1
    while 1:
        if endUsecs == -1 :
          runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&startTimeUsecs=%s&includeTenants=true&includeObjectDetails=true' % (job['id'], numruns, daysAgo), v=2)
        else :
          runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&startTimeUsecs=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true' % (job['id'], numruns, daysAgo, endUsecs), v=2)
        if len(runs['runs']) > 0:
            endUsecs = runs['runs'][-1]['localBackupInfo']['startTimeUsecs'] - 1
        else:
            break
        for run in runs['runs']:
            runStartTime = usecsToDate(run['localBackupInfo']['startTimeUsecs'])
            runtype = run['localBackupInfo']['runType'][1:]
            if runtype == 'Regular':
                runtype = 'Incremental'
            if runtype != 'Log' or includelogs:
                if 'objects' in run:
                    for object in run['objects']:
                        if object['object']['objectType'] == 'kDatabase':
                            dgRole = 'NA'
                            objectid = object['object']['id']
                            dbSource = api('get', 'protectionSources?id=%s' % objectid)
                            dbname = object['object']['name']
                            uuid = object['object']['uuid']
                            if argdbname != None and dbname != argdbname:
                              continue
                            if argdbuuid != None and uuid != argdbuuid:
                              continue
                            if isinstance(dbSource, list) == False:
                              print("Skipping entity %s:%s:%s" % (objectid, dbname, uuid))
                              PrintDBRunSummary(None, job['name'], 'NA', dbname, uuid, runtype, 'NA', dgRole, 'NA')
                              continue
                            latestPulseUpdate='NA'
                            if 'progressTaskId' in run['localBackupInfo'] and 'progressTaskId' in object['localSnapshotInfo']['snapshotInfo']:
                              progress = api('get', 'data-protect/runs/%s/progress?runTaskPath=%s&objects=%s&objectTaskPaths=%s&includeEventLogs=true' % (job['id'], run['localBackupInfo']['progressTaskId'], objectid, object['localSnapshotInfo']['snapshotInfo']['progressTaskId']), v=2)
                            #print(progress)
                              latestPulseUpdate='PulseStatus:%s#%s' % (progress['localRun']['objects'][0]['status'], progress['localRun']['objects'][0]['events'][-1]['message'])
                            dbType = dbSource[0]['protectionSource']['oracleProtectionSource']['dbType']
                            if 'dataGuardInfo' in dbSource[0]['protectionSource']['oracleProtectionSource']:
                                dgRole = dbSource[0]['protectionSource']['oracleProtectionSource']['dataGuardInfo']['role']
                            hostobject = [o for o in run['objects'] if o['object']['id'] == object['object']['sourceId']]
                            hostname = hostobject[0]['object']['name']
                            PrintDBRunSummary(object['localSnapshotInfo'],job['name'], hostname, dbname, uuid, runtype, dbType, dgRole, latestPulseUpdate)
                            snapinfo = object['localSnapshotInfo']['snapshotInfo']
                            status = snapinfo['status'][1:]
                            print("    %s  %s/%s  (%s)  %s" % (runStartTime, hostname, dbname, runtype, status))
                    if lastrunonly:
                        break
f.close()
print('\nOutput saved to %s\n' % outfile)
