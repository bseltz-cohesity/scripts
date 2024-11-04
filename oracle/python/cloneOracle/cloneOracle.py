#!/usr/bin/env python
"""Clone an Oracle DB Using python"""

### usage: ./cloneOracle.py -v mycluster \
#                           -u myuser \
#                           -d mydomain.net \
#                           -ss oracleprod.mydomain.net \
#                           -ts oracledev.mydomain.net \
#                           -sd proddb \
#                           -td devdb \
#                           -oh /home/oracle/app/oracle/product/11.2.0/dbhome_1 \
#                           -ob /home/oracle/app/oracle \
#                           -w

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-ss', '--sourceserver', type=str, required=True)  # name of source oracle server
parser.add_argument('-sd', '--sourcedb', type=str, required=True)  # name of source oracle DB
parser.add_argument('-ts', '--targetserver', type=str, default=None)  # name of target oracle server
parser.add_argument('-td', '--targetdb', type=str, default=None)  # name of target oracle DB
parser.add_argument('-oh', '--oraclehome', type=str, required=True)  # oracle home path on target
parser.add_argument('-ob', '--oraclebase', type=str, required=True)  # oracle base path on target
parser.add_argument('-lt', '--logtime', type=str, default=None)  # oracle base path on target
parser.add_argument('-ch', '--channels', type=int, default=2)  # number of restore channels
parser.add_argument('-cn', '--channelnode', type=str, default=None)  # oracle data path on target
parser.add_argument('-l', '--latest', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')  # wait for completion
parser.add_argument('-sh', '--shellvariable', type=str, action='append')
parser.add_argument('-pf', '--pfileparameter', type=str, action='append')
parser.add_argument('-vlan', '--vlan', type=int, default=0)  # use alternate vlan
parser.add_argument('-prescript', '--prescript', type=str, default=None)  # pre script
parser.add_argument('-postscript', '--postscript', type=str, default=None)  # post script
parser.add_argument('-prescriptargs', '--prescriptargs', type=str, default='')  # pre script arguments
parser.add_argument('-postscriptargs', '--postscriptargs', type=str, default='')  # post script arguments
parser.add_argument('-t', '--scripttimeout', type=int, default=900)  # pre post script timeout

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
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
logtime = args.logtime
channels = args.channels
channelnode = args.channelnode
latest = args.latest
wait = args.wait
shellvars = args.shellvariable
pfileparams = args.pfileparameter
vlan = args.vlan
prescript = args.prescript
postscript = args.postscript
prescriptargs = args.prescriptargs
postscriptargs = args.postscriptargs
scripttimeout = args.scripttimeout

if shellvars is None:
    shellvars = []
if pfileparams is None:
    pfileparams = []

### authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

### if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

### search for view to clone
searchResults = api('get', '/searchvms?entityTypes=kOracle&vmName=%s' % sourcedb)
if len(searchResults) == 0:
    print("SourceDB %s not found" % sourcedb)
    exit()

### narrow search results to the correct server
searchResults = [searchResult for searchResult in searchResults['vms'] if sourceserver.lower() in [x.lower() for x in searchResult['vmDocument']['objectAliases']]]
if len(searchResults) == 0:
    print("SourceDB %s on Server %s not found" % (sourcedb, sourceserver))
    exit()

### find latest snapshot

latestdb = sorted(searchResults, key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]
version = latestdb['vmDocument']['versions'][0]
ownerId = latestdb['vmDocument']['objectId']['entity']['oracleEntity']['ownerId']

### find target host
targetEntity = None
entities = api('get', '/appEntities?appEnvType=19')
for entity in entities:
    if entity['appEntity']['entity']['displayName'].lower() == targetserver.lower():
        targetEntity = entity
if targetEntity is None:
    print("target server %s not found" % targetserver)
    exit()

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
                    "attemptNum": version['instanceId']['attemptNum']
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

cloneParams = {
    "name": "Clone-Oracle-%s" % sourcedb,
    "action": "kCloneApp",
    "restoreAppParams": {
        "type": 19,
        "ownerRestoreInfo": {
            "ownerObject": {
                "attemptNum": version['instanceId']['attemptNum'],
                "jobUid": latestdb['vmDocument']['objectId']['jobUid'],
                "jobId": latestdb['vmDocument']['objectId']['jobId'],
                "jobInstanceId": version['instanceId']['jobInstanceId'],
                "startTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
                "entity": {
                    "id": latestdb['vmDocument']['objectId']['entity']['parentId'],
                }
            },
            "ownerRestoreParams": {
                "action": "kCloneVMs",
                "powerStateConfig": {}
            },
            "performRestore": False
        },
        "restoreAppObjectVec": [
            {
                "appEntity": latestdb['vmDocument']['objectId']['entity'],
                "restoreParams": {
                    "oracleRestoreParams": {
                        "alternateLocationParams": {
                            "newDatabaseName": targetdb,
                            "homeDir": oraclehome,
                            "baseDir": oraclebase
                        },
                        "captureTailLogs": False,
                        "secondaryDataFileDestinationVec": [
                            {}
                        ]
                    },
                    "targetHost": targetEntity['appEntity']['entity'],
                    "targetHostParentSource": {
                        "id": targetEntity['appEntity']['entity']['id']
                    }
                }
            }
        ]
    }
}

# configure channels
if channelnode is not None:
    uuid = latestdb['vmDocument']['objectId']['entity']['oracleEntity']['uuid']
    endpoints = [e for e in targetEntity['appEntity']['entity']['physicalEntity']['networkingInfo']['resourceVec'] if e['type'] == 0]
    channelNodeObj = None
    for endpoint in endpoints:
        preferredEndPoint = [e for e in endpoint['endpointVec'] if e['isPreferredEndpoint'] is True]
        if preferredEndPoint[0]['fqdn'].lower() == channelnode.lower() or preferredEndPoint[0]['ipv4Addr'] == channelnode.lower():
            channelNodeObj = preferredEndPoint[0]
    if channelNodeObj is not None:
        channelNodeAgent = [a for a in targetEntity['appEntity']['entity']['physicalEntity']['agentStatusVec'] if a['displayName'].lower() == channelNodeObj['fqdn'].lower() or a['displayName'].lower() == channelNodeObj['ipv4Addr']]
        if channelNodeAgent is not None and len(channelNodeAgent) > 0:
            channelNodeId = channelNodeAgent[0]['id']
        else:
            print('channelnode %s not found' % channelnode)
            exit(1)
else:
    channelNodeId = targetEntity['appEntity']['entity']['physicalEntity']['agentStatusVec'][0]['id']
    uuid = latestdb['vmDocument']['objectId']['entity']['oracleEntity']['uuid']

cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['oracleTargetParams'] = {
    "additionalOracleDbParamsVec": [
        {
            "appEntityId": latestdb['vmDocument']['objectId']['entity']['id'],
            "dbInfoChannelVec": [
                {
                    "hostInfoVec": [
                        {
                            "host": str(channelNodeId),
                            "numChannels": channels
                        }
                    ],
                    "dbUuid": uuid
                }
            ]
        }
    ]
}

# vlan config
if vlan > 0:
    vlanObj = [v for v in api('get', 'vlans') if v['id'] == vlan]
    if vlanObj is not None and len(vlanObj) > 0:
        vlanObj = vlanObj[0]
    else:
        print('VLAN %s not found' % vlan)
        exit(1)
    cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['targetHost']['physicalEntity']['vlanParams'] = {
        "vlanId": vlanObj['id'],
        "interfaceName": vlanObj['ifaceGroupName']
    }

# apply log replay time
if validLogTime is True:
    cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['restoreTimeSecs'] = int(logusecs / 1000000)
else:
    if logtime is not None:
        print('LogTime of %s is out of range' % logtime)
        print('Available range is %s to %s' % (usecsToDate(logStart), usecsToDate(logEnd)))
        exit(1)

if len(pfileparams) > 0:
    if 'oracleDbConfig' not in cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']:
        cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDbConfig'] = {}
        cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDbConfig']['pfileParameterMap'] = []
    for pfileparam in pfileparams:
        paramparts = pfileparam.split('=', 1)
        if len(paramparts) != 2:
            print('pfile parameter is invalid')
            exit(1)
        else:
            paramname = paramparts[0].strip()
            paramval = paramparts[1].strip()
            cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['oracleDbConfig']['pfileParameterMap'].append({"key": paramname, "value": paramval})

if len(shellvars) > 0:
    cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['shellEnvironmentVec'] = []
    for shellvar in shellvars:
        varparts = shellvar.split('=')
        if len(varparts) < 2:
            print('invalid shell variable')
            exit(1)
        else:
            varname = varparts[0].strip()
            varval = varparts[1].strip()
            cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['shellEnvironmentVec'].append({"xKey": varname, "xValue": varval})

# handle pre script
if prescript is not None or postscript is not None:
    cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['additionalParams'] = {}
    if prescript is not None:
        cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['additionalParams']['preScript'] = {
            "script": {
                "continueOnError": False,
                "scriptPath": prescript,
                "scriptParams": prescriptargs,
                "timeoutSecs": scripttimeout
            }
        }
    if postscript is not None:
        cloneParams['restoreAppParams']['restoreAppObjectVec'][0]['additionalParams']['postScript'] = {
            "script": {
                "continueOnError": False,
                "scriptPath": postscript,
                "scriptParams": postscriptargs,
                "timeoutSecs": scripttimeout
            }
        }

### execute the clone task
response = api('post', '/cloneApplication', cloneParams)
if 'errorCode' in response or 'error' in response:
    exit(1)

print("Cloning DB %s as %s..." % (sourcedb, targetdb))
taskId = response['restoreTask']['performRestoreTaskState']['base']['taskId']

if wait is True:
    finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
    status = 'unknown'
    while status not in finishedStates:
        sleep(20)
        try:
            statusquery = api('get', '/restoretasks/%s' % taskId)
            status = statusquery[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus']
        except Exception:
            pass
    if status == 'kSuccess':
        print('Clone Completed Successfully')
        exit(0)
    else:
        print('Clone ended with state: %s' % status)
        exit(1)
