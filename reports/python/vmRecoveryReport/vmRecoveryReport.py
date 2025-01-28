#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
import codecs
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
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-y', '--daysback', type=int, default=7)
parser.add_argument('-n', '--task', action='append', type=str)
parser.add_argument('-l', '--tasklist', type=str)
parser.add_argument('-f', '--outfilename', type=str, default='vmRecoveryReport.csv')

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
emailmfacode = args.emailmfacode
daysback = args.daysback
task = args.task
tasklist = args.tasklist
outfilename = args.outfilename

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

tasks = gatherList(task, tasklist, name='tasks', required=False)

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

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
nowusecs = dateToUsecs()
midnight = datetime.combine(now, datetime.min.time())
midnightusecs = dateToUsecs(midnight)
tonightusecs = midnightusecs + 86399000000
beforeusecs = midnightusecs - (daysback * 86400000000) + 86400000000

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
f = codecs.open(outfilename, 'w')
f.write('"Cluster","Recovery Task Name","Recovery Task ID","Recovery Task Start Time","Recovery Type","Source VM Name","Target VM Name","VM Logical Size (GiB)","VM Used Size (GiB)","VM Status","VM Start Time","VM End Time","VM Recovery Duration (Sec)","VM Percent","Instant Recovery Start Time","Instant Recovery End Time","Instant Recovery Duration (Sec)","Instant Recovery Percent","Datastore Migration Start Time","Datastore Migration End Time","Datastore Migration Duration (Sec)","Datastore Migration Percent"\n')
recoveries = api('get', 'data-protect/recoveries?startTimeUsecs=%s&recoveryActions=RecoverVMs&includeTenants=true&endTimeUsecs=%s' % (beforeusecs, tonightusecs), v=2)
if len(tasks) > 0:
    recoveries['recoveries'] = [r for r in recoveries['recoveries'] if r['name'].lower() in [n.lower() for n in tasks] or r['id'].lower() in [i.lower() for i in tasks]]
    notFoundTasks = [t for t in tasks if t.lower() not in [r['name'].lower() for r in recoveries['recoveries']] and t.lower() not in [r['id'].lower() for r in recoveries['recoveries']]]
    if len(notFoundTasks) > 0:
        for task in notFoundTasks:
            print('Recovery task %s not found' % task)
        exit(1)
if recoveries is None or 'recoveries' not in recoveries or recoveries['recoveries'] is None or len(recoveries['recoveries']) == 0:
    print('No recoveries found')
    exit(1)

for recovery in recoveries['recoveries']:
    thisRecovery = api('get', 'data-protect/recoveries/%s?includeTenants=true' % recovery['id'], v=2)
    print(thisRecovery['name'])
    renameParams = {}
    if 'renameRecoveredVmsParams' in thisRecovery['vmwareParams']['recoverVmParams']['vmwareTargetParams']:
        renameParams = thisRecovery['vmwareParams']['recoverVmParams']['vmwareTargetParams']['renameRecoveredVmsParams']
    recoveryStart = usecsToDate(thisRecovery['startTimeUsecs'])
    recoveryStatus = thisRecovery['status']
    recoveryType = thisRecovery['vmwareParams']['recoverVmParams']['vmwareTargetParams']['recoveryProcessType']
    for object in thisRecovery['vmwareParams']['objects']:
        objectStatus = object['status']
        objectStart = object['startTimeUsecs']
        objectEnd = ''
        if 'endTimeUsecs' in object and object['endTimeUsecs'] is not None and object['endTimeUsecs'] > 0:
            objectEnd = object['endTimeUsecs']
            objectDuration = round((objectEnd - objectStart)/1000000, 0)
            objectEnd = usecsToDate(objectEnd)
            objectPct = 100
        else:
            objectEnd = ''
            objectDuration= round((nowusecs - objectStart)/1000000, 0)
            progress = api('get', '/progressMonitors?taskPathVec=%s&excludeSubTasks=true&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0' % object['progressTaskId'])
            try:
                objectPct = progress['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
            except Exception:
                objectPct = 0
        objectStart = usecsToDate(objectStart)
        objectName = object['objectInfo']['name']
        targetName = objectName
        if 'prefix' in renameParams:
            targetName = '%s%s' % (renameParams['prefix'], targetName)
        if 'suffix' in renameParams:
            targetName = '%s%s' % (targetName, renameParams['suffix'])
        try:
            search = api('get','/searchvms?entityIds=%s' % object['objectInfo']['id'])
            logicalSize = round(search['vms'][0]['vmDocument']['versions'][0]['logicalSizeBytes']/(1024*1024*1024), 1)
            size = round(search['vms'][0]['vmDocument']['objectId']['entity']['vmwareEntity']['frontEndSizeInfo']['sizeBytes']/(1024*1024*1024), 1)
            if size > logicalSize:
                size = logicalSize
        except Exception:
            size = ''
        instantDuration = ''
        instantStart = ''
        instantEnd = ''
        instantPct = ''
        migrateDuration = ''
        migrateStart = ''
        migrateEnd = ''
        migratePct = ''
        if recoveryType == 'InstantRecovery':
            try:
                instantInfo = object['instantRecoveryInfo']
                instantStatus = instantInfo['status']
                instantStart = instantInfo['startTimeUsecs']
                if 'endTimeUsecs' in instantInfo and instantInfo['endTimeUsecs'] is not None and instantInfo['endTimeUsecs'] > 0:
                    instantEnd = instantInfo['endTimeUsecs']
                    instantDuration = round((instantEnd - instantStart)/1000000, 0)
                    instantPct = 100
                    instantEnd = usecsToDate(instantEnd)
                else:
                    instantDuration = round((nowusecs - instantStart)/1000000, 0)
                    progress = api('get', '/progressMonitors?taskPathVec=%s&excludeSubTasks=True&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0' % instantInfo['progressTaskId'])
                    try:
                        instantPct = progress['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                    except Exception:
                        instantPct = 0
                instantStart = usecsToDate(instantStart)
            except Exception:
                pass
            try:
                migrateInfo = object['datastoreMigrationInfo']
                migrateStatus = migrateInfo['status']
                migrateStart = migrateInfo['startTimeUsecs']
                if 'endTimeUsecs' in migrateInfo and migrateInfo['endTimeUsecs'] is not None and migrateInfo['endTimeUsecs'] > 0:
                    migrateEnd = migrateInfo['endTimeUsecs']
                    migrateDuration = round((migrateEnd - migrateStart)/1000000, 0)
                    migrateEnd = usecsToDate(migrateEnd)
                    migratePct = 100
                else:
                    migrateDuration = round((nowusecs - migrateStart)/1000000, 0)
                    progress = api('get', '/progressMonitors?taskPathVec=%s&excludeSubTasks=True&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0' % migrateInfo['progressTaskId'])
                    try:
                        migratePct = progress['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                    except Exception:
                        migratePct = 0
                migrateStart = usecsToDate(migrateStart)
            except Exception:
                pass
        print('    %s %s %s%%' % (objectName, objectStatus, objectPct))
        f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], thisRecovery['name'], thisRecovery['id'], recoveryStart, recoveryType, objectName, targetName, logicalSize, size, objectStatus, objectStart, objectEnd, objectDuration, objectPct, instantStart, instantEnd, instantDuration, instantPct, migrateStart, migrateEnd, migrateDuration, migratePct))# ,"Instant Recovery Start Time","Instant Recovery End Time","Instant Recovery Duration","Instant Recovery Percent","Datastore Migration Start Time","Datastore Migration End Time","Datastore Migration Duration","Datastore Migration Percent"\n')
