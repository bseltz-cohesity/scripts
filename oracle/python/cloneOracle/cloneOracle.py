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
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-ss', '--sourceserver', type=str, required=True)  # name of source oracle server
parser.add_argument('-sd', '--sourcedb', type=str, required=True)  # name of source oracle DB
parser.add_argument('-ts', '--targetserver', type=str, default=None)  # name of target oracle server
parser.add_argument('-td', '--targetdb', type=str, default=None)  # name of target oracle DB
parser.add_argument('-oh', '--oraclehome', type=str, required=True)  # oracle home path on target
parser.add_argument('-ob', '--oraclebase', type=str, required=True)  # oracle base path on target
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
wait = args.wait

### authenticate
apiauth(vip, username, domain)

### search for view to clone
searchResults = api('get', '/searchvms?entityTypes=kSQL&entityTypes=kOracle&showAll=false&onlyLatestVersion=true&vmName=%s' % sourcedb)
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

### find target host
entities = api('get', '/appEntities?appEnvType=19')
for entity in entities:
    if entity['appEntity']['entity']['displayName'].lower() == targetserver.lower():
        targetEntity = entity
if targetEntity is None:
    print "target server not found"
    exit()

cloneParams = {
    "name": "Clone-Oracle",
    "action": "kCloneApp",
    "restoreAppParams": {
        "type": 19,
        "ownerRestoreInfo": {
            "ownerObject": {
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


### execute the clone task
response = api('post', '/cloneApplication', cloneParams)

if 'errorCode' in response:
    exit(1)

print("Cloning DB %s as %s..." % (sourcedb, targetdb))
taskId = response['restoreTask']['performRestoreTaskState']['base']['taskId']
status = api('get', '/restoretasks/%s' % taskId)

if wait is True:
    finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
    while(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates):
        sleep(1)
        status = api('get', '/restoretasks/%s' % taskId)
    if(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess'):
        print('Cloned View Successfully')
        exit(0)
    else:
        print('Clone View ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
