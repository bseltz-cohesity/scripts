#!/usr/bin/env python
"""replication report"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs
import os

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
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-n', '--numruns', type=int, default=100)
parser.add_argument('-y', '--days', type=int, default=7)
parser.add_argument('-o', '--outpath', type=str, default='.')
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')
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
jobnames = args.jobname
joblist = args.joblist
numruns = args.numruns
days = args.days
outpath = args.outpath
units = args.units

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

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
daysBackUsecs = timeAgo(days, 'days')

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")

objectFileName = os.path.join(outpath, 'replicationReport-perObject-%s-%s.csv' % (cluster['name'], dateString))
of = codecs.open(objectFileName, 'w')
of.write('"Job Name","Job Type","Run Start Time","Source Name","Replication Delay Sec","Replication Duration Sec","Logical Replicated %s","Physical Replicated %s","Status","Target Cluster","Percent Completed"\n' % (units, units))
runFileName = os.path.join(outpath, 'replicationReport-perRun-%s-%s.csv' % (cluster['name'], dateString))
rf = codecs.open(runFileName, 'w')
rf.write('"Job Name","Job Type","Run Start Time","Replication Start Time","Replication End Time","Replication Duration (Sec)","Entries Changed","Logical Replicated %s","Physical Replicated %s","Status","Target Cluster"\n' % (units, units))
dayFileName = os.path.join(outpath, 'replicationReport-perDay-%s-%s.csv' % (cluster['name'], dateString))
df = codecs.open(dayFileName, 'w')
df.write('"Job Name","Job Type","Day","Replication Duration (Sec)","Logical Replicated %s","Physical Replicated %s","Target Cluster"\n' % (units, units))
jobFileName = os.path.join(outpath, 'replicationReport-perJob-%s-%s.csv' % (cluster['name'], dateString))
jf = codecs.open(jobFileName, 'w')
jf.write('"Job Name","Job Type","Max Replication Duration (Sec)","Avg Replication Duration (Sec)","Max Logical Replicated %s","Avg Logical Replicated %s","Max Physical Replicated %s","Avg Physical Replicated %s","Target Cluster"\n' % (units, units, units, units))

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

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

if jobs['protectionGroups'] is None:
    print('no jobs found')
    exit()

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:

        if len(job['permissions']) > 0 and 'name' in job['permissions'][0]:
            tenant = job['permissions'][0]['name']
            print('%s (%s)' % (job['name'], tenant))
        else:
            tenant = ''
            print('%s' % job['name'])

        endUsecs = nowUsecs
        lastRunId = '0'
        jobId = job['id']
        jobName = job['name']
        jobType = job['environment'][1:]
        # per day stats
        perDayRepls = {}
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&startTimeUsecs=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true' % (job['id'], numruns, daysBackUsecs, endUsecs), v=2)
            if lastRunId != '0':
                runs['runs'] = [r for r in runs['runs'] if r['id'] < lastRunId]
            for run in runs['runs']:
                if 'isLocalSnapshotsDeleted' not in run or run['isLocalSnapshotsDeleted'] is not True:
                    if 'localBackupInfo' in runs['runs'][-1]:
                        runStartTimeUsecs = run['localBackupInfo']['startTimeUsecs']
                        status = run['localBackupInfo']['status']
                    elif 'originalBackupInfo' in runs['runs'][-1]:
                        runStartTimeUsecs = run['originalBackupInfo']['startTimeUsecs']
                        status = run['originalBackupInfo']['status']
                    else:
                        continue
                    if runStartTimeUsecs < daysBackUsecs:
                        break
                    # per run stats
                    repls = {}
                    if 'replicationInfo' not in run:
                        continue
                    for repl in run['replicationInfo']['replicationTargetResults']:
                        if 'endTimeUsecs' in repl:
                            endTimeUsecs = repl['endTimeUsecs']
                        else:
                            endTimeUsecs = nowUsecs
                        repls[repl['clusterName']] = {
                            'startTimeUsecs': None,
                            'endTimeUsecs': endTimeUsecs,
                            'entriesChanged': repl['entriesChanged'],
                            'logicalReplicated': 0,
                            'physicalReplicated': 0,
                            'status': repl['status']
                        }
                    # per object stats
                    for server in run['objects']:
                        sourceName = server['object']['name']
                        if not (run['environment'] == 'kAD' and server['object']['objectType'] == 'kDomainController'):
                            if 'replicationInfo' in server:
                                for target in server['replicationInfo']['replicationTargetResults']:
                                    status = target['status']
                                    if 'percentageCompleted' in target:
                                        percentCompleted = target['percentageCompleted']
                                    else:
                                        percentCompleted = 0
                                    remoteCluster = target['clusterName']
                                    replicaQueuedTime = target['queuedTimeUsecs']
                                    if 'startTimeUsecs' in target:
                                        replicaStartTime = target['startTimeUsecs']
                                    else:
                                        replicaStartTime = nowUsecs
                                    if 'endTimeUsecs' in target:
                                        replicaEndTime = target['endTimeUsecs']
                                    else:
                                        replicaEndTime = nowUsecs
                                    replicaDelay = round((replicaStartTime - replicaQueuedTime) / 1000000)
                                    replicaDuration = round((replicaEndTime - replicaStartTime) / 1000000)
                                    logicalReplicated = round(target['stats']['logicalBytesTransferred'] / multiplier, 1)
                                    physicalReplicated = round(target['stats']['physicalBytesTransferred'] / multiplier, 1)
                                    repls[remoteCluster]['logicalReplicated'] += logicalReplicated
                                    repls[remoteCluster]['physicalReplicated'] += physicalReplicated
                                    if repls[remoteCluster]['startTimeUsecs'] is None or replicaStartTime < repls[remoteCluster]['startTimeUsecs']:
                                        repls[remoteCluster]['startTimeUsecs'] = replicaStartTime
                                    of.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, jobType, usecsToDate(runStartTimeUsecs), sourceName, replicaDelay, replicaDuration, logicalReplicated, physicalReplicated, status, remoteCluster, percentCompleted))
                    if repls[repl['clusterName']]['startTimeUsecs'] is None:
                        repls[repl['clusterName']]['startTimeUsecs'] = runStartTimeUsecs
                    # per run stats
                    for remoteCluster in repls.keys():
                        if repls[remoteCluster]['status'] == 'Succeeded' and repls[remoteCluster]['startTimeUsecs'] is not None:
                            replicaDuration = round((repls[remoteCluster]['endTimeUsecs'] - repls[remoteCluster]['startTimeUsecs']) / 1000000, 0)
                            rf.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, jobType, usecsToDate(runStartTimeUsecs), usecsToDate(repls[remoteCluster]['startTimeUsecs']), usecsToDate(repls[remoteCluster]['endTimeUsecs']), replicaDuration, repls[remoteCluster]['entriesChanged'], repls[remoteCluster]['logicalReplicated'], repls[remoteCluster]['physicalReplicated'], repls[remoteCluster]['status'], remoteCluster))
                            # per day stats
                            replDay = usecsToDate(uedate=repls[remoteCluster]['startTimeUsecs'], fmt='%Y-%m-%d')
                            if remoteCluster not in perDayRepls:
                                perDayRepls[remoteCluster] = {}
                            if replDay not in perDayRepls[remoteCluster]:
                                perDayRepls[remoteCluster][replDay] = {
                                    'duration': 0,
                                    'logicalReplicated': 0,
                                    'physicalReplicated': 0
                                }
                            perDayRepls[remoteCluster][replDay]['duration'] += replicaDuration
                            perDayRepls[remoteCluster][replDay]['logicalReplicated'] += repls[remoteCluster]['logicalReplicated']
                            perDayRepls[remoteCluster][replDay]['physicalReplicated'] += repls[remoteCluster]['physicalReplicated']
                        else:
                            if repls[remoteCluster]['startTimeUsecs'] is None:
                                print('hello')
                                replStartTime = nowUsecs
                            else:
                                replStartTime = repls[remoteCluster]['startTimeUsecs']
                            replicaDuration = round((repls[remoteCluster]['endTimeUsecs'] - replStartTime) / 1000000, 0)
                            
                            endTime = usecsToDate(repls[remoteCluster]['endTimeUsecs'])
                            if repls[remoteCluster]['status'] in ['Accepted', 'Running']:
                                endTime = ''
                            rf.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, jobType, usecsToDate(runStartTimeUsecs), usecsToDate(replicaStartTime), endTime, replicaDuration, repls[remoteCluster]['entriesChanged'], repls[remoteCluster]['logicalReplicated'], repls[remoteCluster]['physicalReplicated'], repls[remoteCluster]['status'], remoteCluster))
            if len(runs['runs']) == 0 or runs['runs'][-1]['id'] == lastRunId:
                break
            else:
                lastRunId = runs['runs'][-1]['id']
                if 'localBackupInfo' in runs['runs'][-1]:
                    endUsecs = runs['runs'][-1]['localBackupInfo']['endTimeUsecs']
                else:
                    continue
        # per day stats
        for remoteCluster in perDayRepls.keys():
            # per job stats
            maxDuration = 0
            totalDuration = 0
            days = 0
            maxLogical = 0
            totalLogical = 0
            maxPhysical = 0
            totalPhysical = 0
            for day in perDayRepls[remoteCluster].keys():
                # per day stats
                df.write('"%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, jobType, day, perDayRepls[remoteCluster][day]['duration'], perDayRepls[remoteCluster][day]['logicalReplicated'],perDayRepls[remoteCluster][day]['physicalReplicated'], remoteCluster))
                # per job stats
                totalDuration += perDayRepls[remoteCluster][day]['duration']
                totalLogical += perDayRepls[remoteCluster][day]['logicalReplicated']
                totalPhysical += perDayRepls[remoteCluster][day]['physicalReplicated']
                if perDayRepls[remoteCluster][day]['duration'] > maxDuration:
                    maxDuration = perDayRepls[remoteCluster][day]['duration']
                if perDayRepls[remoteCluster][day]['logicalReplicated'] > maxLogical:
                    maxLogical = perDayRepls[remoteCluster][day]['logicalReplicated']
                if perDayRepls[remoteCluster][day]['physicalReplicated'] > maxPhysical:
                    maxPhysical = perDayRepls[remoteCluster][day]['physicalReplicated']
                days += 1
            # per job stats
            avgDuration = round(totalDuration / days, 0)
            avgLogical = round(totalLogical / days, 1)
            avgPhysical = round(totalPhysical / days, 1)
            jf.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, jobType, maxDuration, avgDuration, maxLogical, avgLogical, maxPhysical, avgPhysical, remoteCluster))
jf.close()
df.close()
rf.close()
of.close()

print('\nPer Job Output saved to %s' % jobFileName)
print('Per Day Output saved to %s' % dayFileName)
print('Per Run Output saved to %s' % runFileName)
print('Per Object Output saved to %s\n' % objectFileName)
