#!/usr/bin/env python
"""Restore an Oracle DB Using python"""

# usage: ./restoreOracle.py -v mycluster \
#                           -u myuser \
#                           -d mydomain.net \
#                           -ss oracleprod.mydomain.net \
#                           -ts oracledev.mydomain.net \
#                           -sd proddb \
#                           -td resdb \
#                           -oh /home/oracle/app/oracle/product/11.2.0/dbhome_1 \
#                           -ob /home/oracle/app/oracle \
#                           -od /home/oracle/app/oracle/oradata/resdb
#                           -l -w

# import pyhesity wrapper module
from pyhesity import *
from time import sleep

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-ss', '--sourceserver', type=str, required=True)  # name of source oracle server
parser.add_argument('-sd', '--sourcedb', type=str, required=True)  # name of source oracle DB
parser.add_argument('-ts', '--targetserver', type=str, default=None)  # name of target oracle server
parser.add_argument('-td', '--targetdb', type=str, default=None)  # name of target oracle DB
parser.add_argument('-oh', '--oraclehome', type=str, default=None)  # oracle home path on target
parser.add_argument('-ob', '--oraclebase', type=str, default=None)  # oracle base path on target
parser.add_argument('-od', '--oracledata', type=str, default=None)  # oracle data path on target
parser.add_argument('-c', '--channels', type=int, default=None)  # number of restore channels
parser.add_argument('-cf', '--controlfile', type=str, action='append')  # alternate ctl file path
parser.add_argument('-r', '--redologpath', type=str, action='append')  # alternate redo log path
parser.add_argument('-a', '--auditpath', type=str, default=None)  # alternate audit path
parser.add_argument('-dp', '--diagpath', type=str, default=None)  # alternate diag path
parser.add_argument('-f', '--frapath', type=str, default=None)  # alternate fra path
parser.add_argument('-fs', '--frasizeMB', type=int, default=None)  # alternate fra path
parser.add_argument('-b', '--bctfile', type=str, default=None)  # alternate bct file path
parser.add_argument('-lt', '--logtime', type=str, default=None)  # pit to recover to
parser.add_argument('-l', '--latest', action='store_true')  # recover to latest available pit
parser.add_argument('-o', '--overwrite', action='store_true')  # overwrite existing DB
parser.add_argument('-n', '--norecovery', action='store_true')  # leave DB in recovering mode
parser.add_argument('-w', '--wait', action='store_true')  # wait for completion

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
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

oraclehome = args.oraclehome
oraclebase = args.oraclebase
oracledata = args.oracledata
channels = args.channels
controlfile = args.controlfile
redologpath = args.redologpath
auditpath = args.auditpath
diagpath = args.diagpath
frapath = args.frapath
frasizeMB = args.frasizeMB
bctfile = args.bctfile
overwrite = args.overwrite
logtime = args.logtime
latest = args.latest
norecovery = args.norecovery
wait = args.wait

# validate arguments
if targetserver != sourceserver or targetdb != sourcedb:
    if oraclehome is None or oraclebase is None or oracledata is None:
        print('--oraclehome, --oraclebase, and --oracledata are required when restoring to another server/database')
        exit(1)

# overwrite warning
if targetdb == sourcedb and targetserver == sourceserver:
    if overwrite is not True:
        print('Please use the --overwrite parameter to confirm overwrite of the source database!')
        exit(1)

# authenticate
apiauth(vip, username, domain)

# search for view to clone
searchResults = api('get', '/searchvms?entityTypes=kOracle&vmName=%s' % sourcedb)
if len(searchResults) == 0:
    print("SourceDB %s not found" % sourcedb)
    exit()

# narrow search results to the correct server
searchResults = [searchResult for searchResult in searchResults['vms'] if sourceserver.lower() in [x.lower() for x in searchResult['vmDocument']['objectAliases']]]
if len(searchResults) == 0:
    print("SourceDB %s on Server %s not found" % (sourcedb, sourceserver))
    exit()

# find latest snapshot
latestdb = sorted(searchResults, key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]
version = latestdb['vmDocument']['versions'][0]

# find target host
targetEntity = None
entities = api('get', '/appEntities?appEnvType=19')
for entity in entities:
    if entity['appEntity']['entity']['displayName'].lower() == targetserver.lower():
        targetEntity = entity
if targetEntity is None:
    print("target server not found")
    exit()

# version
version = latestdb['vmDocument']['versions'][0]
ownerId = latestdb['vmDocument']['objectId']['entity']['oracleEntity']['ownerId']

# handle log replay
versionNum = 0
validLogTime = False

if logtime is not None or latest is True:
    if logtime is not None:
        logusecs = dateToUsecs(logtime)
    dbversions = latestdb['vmDocument']['versions']

    for version in dbversions:
        # find db date before log time
        GetRestoreAppTimeRangesArg = {
            "type": 19,
            "restoreAppObjectVec": [
                {
                    "appEntity": latestdb['vmDocument']['objectId']['entity'],
                    "restoreParams": {
                        "sqlRestoreParams": {
                            "captureTailLogs": True
                        },
                        "oracleRestoreParams": {
                            "alternateLocationParams": {
                                "oracleDBConfig": {
                                    "controlFilePathVec": [],
                                    "enableArchiveLogMode": True,
                                    "redoLogConf": {
                                        "groupMemberVec": [],
                                        "memberPrefix": "redo",
                                        "sizeMb": 20
                                    },
                                    "fraSizeMb": 2048
                                }
                            },
                            "captureTailLogs": False,
                            "secondaryDataFileDestinationVec": [
                                {}
                            ]
                        }
                    }
                }
            ],
            "ownerObjectVec": [
                {
                    "jobUid": latestdb['vmDocument']['objectId']['jobUid'],
                    "jobId": latestdb['vmDocument']['objectId']['jobId'],
                    "jobInstanceId": version['instanceId']['jobInstanceId'],
                    "startTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
                    "entity": {
                        "id": ownerId
                    },
                    "attemptNum": 1
                }
            ]
        }
        logTimeRange = api('post', '/restoreApp/timeRanges', GetRestoreAppTimeRangesArg)

        if latest is True:
            if 'timeRangeVec' not in logTimeRange['ownerObjectTimeRangeInfoVec'][0]:
                logTime = None
                latest = None
                break

        if 'timeRangeVec' in logTimeRange['ownerObjectTimeRangeInfoVec'][0]:
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

taskName = "Restore-Oracle"

restoreParams = {
    "name": taskName,
    "action": "kRecoverApp",
    "restoreAppParams": {
        "type": 19,
        "ownerRestoreInfo": {
            "ownerObject": {
                "jobUid": latestdb['vmDocument']['objectId']['jobUid'],
                "jobId": latestdb['vmDocument']['objectId']['jobId'],
                "jobInstanceId": version['instanceId']['jobInstanceId'],
                "startTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
                "entity": {
                    "id": latestdb['vmDocument']['objectId']['entity']['parentId']
                }
            },
            "ownerRestoreParams": {
                "action": "kRecoverVMs",
                "powerStateConfig": {}
            },
            "performRestore": False
        },
        "restoreAppObjectVec": [
            {
                "appEntity": latestdb['vmDocument']['objectId']['entity'],
                "restoreParams": {
                    "oracleRestoreParams": {
                        "captureTailLogs": False,
                        "secondaryDataFileDestinationVec": [
                            {}
                        ]
                    }
                }
            }
        ]
    }
}

# allow cloud retrieve
localreplica = [v for v in version['replicaInfo']['replicaVec'] if v['target']['type'] == 1]
archivereplica = [v for v in version['replicaInfo']['replicaVec'] if v['target']['type'] == 3]

if localreplica is None or len(localreplica) == 0:
    if archivereplica is not None and len(archivereplica) > 0:
        restoreParams['restoreAppParams']['ownerRestoreInfo']['ownerObject']['archivalTarget'] = archivereplica[0]['target']['archivalTarget']

# configure channels
if channels is not None:
    restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['oracleTargetParams'] = {
        "additionalOracleDbParamsVec": [
            {
                "appEntityId": latestdb['vmDocument']['objectId']['entity']['id'],
                "dbInfoChannelVec": [
                    {
                        "hostInfoVec": [
                            {
                                "host": targetserver,
                                "numChannels": channels
                            }
                        ],
                        "dbUuid": latestdb['vmDocument']['objectId']['entity']['oracleEntity']['uuid']
                    }
                ]
            }
        ]
    }

# alternate location params
if targetserver != sourceserver or targetdb != sourcedb:
    restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams'] = {
        "newDatabaseName": targetdb,
        "homeDir": oraclehome,
        "baseDir": oraclebase,
        "oracleDBConfig": {
            "controlFilePathVec": [],
            "enableArchiveLogMode": True,
            "redoLogConf": {
                "groupMemberVec": [],
                "memberPrefix": "redo",
                "sizeMb": 20
            },
            "fraSizeMb": 2048
        },
        "databaseFileDestination": oracledata
    }
    restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['targetHost'] = targetEntity['appEntity']['entity']
    if controlfile is not None:
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['controlFilePathVec'] = controlfile
    if redologpath is not None:
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['redoLogConf']['groupMemberVec'] = redologpath
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['redoLogConf']['numGroups'] = len(redologpath)
    if frasizeMB is not None:
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['fraSizeMb'] = frasizeMB
    if bctfile is not None:
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['bctFilePath'] = bctfile
    if auditpath is not None:
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['auditLogDest'] = auditpath
    if diagpath is not None:
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['diagDest'] = diagpath
    if frapath is not None:
        restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDBConfig']['fraDest'] = frapath

# apply log replay time
if validLogTime is True:
    print(logusecs)
    restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['restoreTimeSecs'] = int(logusecs / 1000000)
else:
    if logtime is not None:
        print('LogTime of %s is out of range' % logtime)
        print('Available range is %s to %s' % (usecsToDate(logStart), usecsToDate(logEnd)))
        exit(1)

# no recovery mode
if norecovery is True:
    restoreParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['noOpenMode'] = True

# perform restore
# display(restoreParams)
# exit()
response = api('post', '/recoverApplication', restoreParams)

if 'errorCode' in response:
    exit(1)

print("Restoring DB %s to %s as %s..." % (sourcedb, targetserver, targetdb))
taskId = response['restoreTask']['performRestoreTaskState']['base']['taskId']
status = api('get', '/restoretasks/%s' % taskId)

if wait is True:
    finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
    while(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates):
        sleep(1)
        status = api('get', '/restoretasks/%s' % taskId)
    if(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess'):
        print('Restore Completed Successfully')
        exit(0)
    else:
        print('Restore Ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
