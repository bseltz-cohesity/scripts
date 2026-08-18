#!/usr/bin/env python
"""Clone a SQL DB Using python"""

## version 2026-08-18

### import pyhesity wrapper module
from pyhesity import *
import json
from time import sleep

### command line arguments
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
parser.add_argument('-ss', '--sourceserver', type=str, required=True)  # protection source where the DB was backed up
parser.add_argument('-sd', '--sourcedb', type=str, required=True)  # name of the source DB we want to clone
parser.add_argument('-ts', '--targetserver', type=str, default=None)  # where to attach the clone DB
parser.add_argument('-td', '--targetdb', type=str, default=None)  # desired clone DB name
parser.add_argument('-ti', '--targetinstance', type=str, default='MSSQLSERVER')  # SQL instance name on the targetserver
parser.add_argument('-lt', '--logtime', type=str, default=None)  # point in time log replay like '2019-09-29 17:51:01'
parser.add_argument('-nl', '--nologs', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')  # wait for clone to finish
parser.add_argument('-l', '--latest', action='store_true')  # very latest point in time log replay
parser.add_argument('-st', '--sleeptime', type=int, default=15)
parser.add_argument('-dbg', '--dbg', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
tenant = args.tenant
mfacode = args.mfacode
emailmfacode = args.emailmfacode
sourceserver = args.sourceserver
sourcedb = args.sourcedb

if args.targetserver is None:
    targetserver = sourceserver
else:
    targetserver = args.targetserver

if args.targetdb is None:
    targetdb = sourcedb
else:
    targetdb = args.targetdb

targetinstance = args.targetinstance
logtime = args.logtime
nologs = args.nologs
wait = args.wait
latest = args.latest
sleeptime = args.sleeptime
dbg = args.dbg

if dbg:
    enableCohesityAPIDebugger()

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

### search for database to clone
searchresults = api('get', '/searchvms?environment=SQL&entityTypes=kSQL&entityTypes=kVMware&vmName=%s&runTypes=kRegular,kFull' % sourcedb)

### handle source instance name e.g. instance/dbname
if '/' in sourcedb:
    sourcedb = sourcedb.split('/')[1]

### narrow the search results to the correct source server
dbresults = [vm for vm in searchresults['vms'] if sourceserver.lower() in [a.lower() for a in vm['vmDocument']['objectAliases']]]
if len(dbresults) == 0:
    print('Server %s Not Found' % sourceserver)
    exit(1)

### narrow the search results to the correct source database
dbresults = [vm for vm in dbresults if vm['vmDocument']['objectId']['entity']['sqlEntity']['databaseName'].lower() == sourcedb.lower()]
if len(dbresults) == 0:
    print('Database %s Not Found' % sourcedb)
    exit(1)

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot
latestdb = sorted(dbresults, key=lambda vm: vm['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]

if latestdb is None:
    print('Database Not Found')
    exit(1)

### identify physical or vm
entityType = latestdb['registeredSource']['type']

### search for source and target servers
entities = api('get', '/appEntities?appEnvType=3&envType=%s' % entityType)
ownerId = latestdb['vmDocument']['objectId']['entity']['sqlEntity']['ownerId']
targetEntity = None
for entity in entities:
    if entity['appEntity']['entity']['displayName'] == targetserver:
        targetEntity = entity

if targetEntity is None:
    print('Target Server Not Found')
    exit(1)

### handle log replay
versionNum = 0
validLogTime = False
logStart = None
logEnd = None

if logtime is not None or latest is True:
    if logtime is not None:
        logusecs = dateToUsecs(logtime)

    dbVersions = latestdb['vmDocument']['versions']

    for version in dbVersions:
        ### find db date before log time
        GetRestoreAppTimeRangesArg = {
            'type': 3,
            'restoreAppObjectVec': [
                {
                    'appEntity': latestdb['vmDocument']['objectId']['entity'],
                    'restoreParams': {
                        'sqlRestoreParams': {
                            'captureTailLogs': False,
                            'newDatabaseName': sourcedb,
                            'alternateLocationParams': {},
                            'secondaryDataFileDestinationVec': [{}]
                        },
                        'oracleRestoreParams': {
                            'alternateLocationParams': {}
                        }
                    }
                }
            ],
            'ownerObjectVec': [
                {
                    'jobUid': latestdb['vmDocument']['objectId']['jobUid'],
                    'jobId': latestdb['vmDocument']['objectId']['jobId'],
                    'jobInstanceId': version['instanceId']['jobInstanceId'],
                    'startTimeUsecs': version['instanceId']['jobStartTimeUsecs'],
                    'entity': {
                        'id': ownerId
                    },
                    'attemptNum': version['instanceId']['attemptNum']
                }
            ]
        }
        logTimeRange = api('post', '/restoreApp/timeRanges', GetRestoreAppTimeRangesArg)
        if latest is True:
            if 'timeRangeVec' not in logTimeRange['ownerObjectTimeRangeInfoVec'][0]:
                logtime = None
                latest = None
                break
        if 'timeRangeVec' not in logTimeRange['ownerObjectTimeRangeInfoVec'][0]:
            continue
        logStart = logTimeRange['ownerObjectTimeRangeInfoVec'][0]['timeRangeVec'][0]['startTimeUsecs']
        logEnd = logTimeRange['ownerObjectTimeRangeInfoVec'][0]['timeRangeVec'][0]['endTimeUsecs']
        if latest is True:
            logusecs = logEnd - 1000000
            validLogTime = True
            break
        if logStart <= logusecs and logusecs <= logEnd:
            validLogTime = True
            break
        versionNum += 1

taskName = 'CloneSQL-%s-%s-%s' % (targetserver, targetinstance, targetdb)

if validLogTime is False:
    versionNum = 0

### create new clone task (RestoreAppArg Object)
cloneTask = {
    'name': taskName,
    'action': 'kCloneApp',
    'restoreAppParams': {
        'type': 3,
        'ownerRestoreInfo': {
            'ownerObject': {
                'attemptNum': latestdb['vmDocument']['versions'][versionNum]['instanceId']['attemptNum'],
                'jobUid': latestdb['vmDocument']['objectId']['jobUid'],
                'jobId': latestdb['vmDocument']['objectId']['jobId'],
                'jobInstanceId': latestdb['vmDocument']['versions'][versionNum]['instanceId']['jobInstanceId'],
                'startTimeUsecs': latestdb['vmDocument']['versions'][versionNum]['instanceId']['jobStartTimeUsecs'],
                'entity': {
                    'id': ownerId
                }
            },
            'ownerRestoreParams': {
                'action': 'kCloneVMs',
                'powerStateConfig': {}
            },
            'performRestore': False
        },
        'restoreAppObjectVec': [
            {
                'appEntity': latestdb['vmDocument']['objectId']['entity'],
                'restoreParams': {
                    'sqlRestoreParams': {
                        'captureTailLogs': False,
                        'instanceName': targetinstance,
                        'newDatabaseName': targetdb
                    },
                    'targetHost': targetEntity['appEntity']['entity']
                    # 'targetHostParentSource': {
                    #     'id': targetEntity['appEntity']['entity']['parentId']
                    # }
                }
            }
        ]
    }
}

### apply log replay time
if validLogTime is True:
    if not nologs:
        cloneTask['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['sqlRestoreParams']['restoreTimeSecs'] = int(logusecs / 1000000)
else:
    if logtime is not None:
        print('LogTime of %s is out of range' % logtime)
        print('Available range is %s to %s' % (usecsToDate(logStart), usecsToDate(logEnd)))
        exit(1)

if dbg:
    with open('clone-sql.json', 'w') as f:
        json.dump(cloneTask, f, indent=4)
    # exit(0)

### execute the clone task (post /cloneApplication api call)
response = api('post', '/cloneApplication', cloneTask)

if response:
    taskId = response['restoreTask']['performRestoreTaskState']['base']['taskId']
    print('Cloning %s to %s as %s (task name: %s)' % (sourcedb, targetserver, targetdb, taskName))
else:
    print('No Response')
    exit(1)

if wait is True:
    status = 'started'
    finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
    publicStatus = None
    while status != 'completed':
        task = api('get', '/restoretasks/%s' % taskId)
        publicStatus = task[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus']
        if publicStatus in finishedStates:
            status = 'completed'
        else:
            sleep(sleeptime)
    print('Clone task completed with status: %s' % publicStatus)
    if publicStatus == 'kFailure':
        print('Error Message: %s' % task['restoreTask']['performRestoreTaskState']['base']['error']['errorMsg'])
        exit(1)

exit(0)
