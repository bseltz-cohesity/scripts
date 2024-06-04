#!/usr/bin/env python
"""Restore an Oracle DB Using python"""

# version: 2024-02-27

# import pyhesity wrapper module
from pyhesity import *
import codecs
import json
from datetime import datetime
from time import sleep


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
parser.add_argument('-ss', '--sourceserver', type=str, required=True)  # name of source oracle server
parser.add_argument('-sd', '--sourcedb', type=str, required=True)  # name of source oracle DB
parser.add_argument('-ts', '--targetserver', type=str, default=None)  # name of target oracle server
parser.add_argument('-td', '--targetdb', type=str, default=None)  # name of target oracle DB
parser.add_argument('-tc', '--targetcdb', type=str, default=None)  # name of target oracle DB
parser.add_argument('-pn', '--pdbnames', type=str, action='append')
parser.add_argument('-oh', '--oraclehome', type=str, default=None)  # oracle home path on target
parser.add_argument('-ob', '--oraclebase', type=str, default=None)  # oracle base path on target
parser.add_argument('-od', '--oracledata', type=str, default=None)  # oracle data path on target
parser.add_argument('-ch', '--channels', type=int, default=1)  # number of restore channels
parser.add_argument('-cn', '--channelnode', type=str, default=None)  # oracle data path on target
parser.add_argument('-sh', '--shellvariable', type=str, action='append')  # alternate ctl file path
parser.add_argument('-pf', '--pfileparameter', type=str, action='append')  # alternate ctl file path
parser.add_argument('-lt', '--logtime', type=str, default=None)  # pit to recover to
parser.add_argument('-l', '--latest', action='store_true')  # recover to latest available pit
parser.add_argument('-o', '--overwrite', action='store_true')  # overwrite existing DB
parser.add_argument('-n', '--norecovery', action='store_true')  # leave DB in recovering mode
parser.add_argument('-nf', '--nofilenamecheck', action='store_true')  # skip filename check
parser.add_argument('-na', '--noarchivelogmode', action='store_true')  # disable archive log mode on target DB
parser.add_argument('-nt', '--numtempfiles', type=int, default=0)   # number of temp files
parser.add_argument('-nc', '--newnameclause', type=str, default='')  # new name clause
parser.add_argument('-nr', '--numredologs', type=int, default=None)  # number of redo log groups
parser.add_argument('-rs', '--redologsizemb', type=int, default=20)  # number of redo log groups
parser.add_argument('-rp', '--redologprefix', type=str, default=None)  # redo log prefix
parser.add_argument('-bc', '--bctfilepath', type=str, default=None)  # alternate bct file path
parser.add_argument('-dbg', '--dbg', action='store_true')  # debug output
parser.add_argument('-w', '--wait', action='store_true')  # wait for completion
parser.add_argument('-pr', '--progress', action='store_true')  # display progress
parser.add_argument('-inst', '--instant', action='store_true')  # instant recovery
parser.add_argument('-cpf', '--clearpfileparameters', action='store_true')  # clear existing pfile parameters
parser.add_argument('-pi', '--printinfo', action='store_true')  # clear existing pfile parameters

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
sourceserver = args.sourceserver
sourcedb = args.sourcedb
targetcdb = args.targetcdb
pdbnames = args.pdbnames
progress = args.progress
instant = args.instant
printinfo = args.printinfo

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
channelnode = args.channelnode
shellvars = args.shellvariable
pfileparams = args.pfileparameter
clearpfileparameters = args.clearpfileparameters
overwrite = args.overwrite
logtime = args.logtime
latest = args.latest
norecovery = args.norecovery
wait = args.wait
nofilenamecheck = args.nofilenamecheck
noarchivelogmode = args.noarchivelogmode
numtempfiles = args.numtempfiles
newnameclause = args.newnameclause
numredologs = args.numredologs
redologsizemb = args.redologsizemb
redologprefix = args.redologprefix
bctfilepath = args.bctfilepath
dbg = args.dbg

if shellvars is None:
    shellvars = []
if pfileparams is None:
    pfileparams = []

# boolean switches
bool_noFilenameCheck = False
if nofilenamecheck:
    bool_noFilenameCheck = True

bool_archiveLogMode = True
if noarchivelogmode:
    bool_archiveLogMode = False

bool_noRecovery = False
if norecovery:
    bool_noRecovery = True

# validate arguments
if targetserver != sourceserver or targetdb != sourcedb:
    if oraclehome is None or oraclebase is None or oracledata is None:
        print('--oraclehome, --oraclebase, and --oracledata are required when restoring to another server/database')
        exit(1)

# parse CDB/PDB name
isPDB = False
originalSourceDB = sourcedb
if '/' in sourcedb:
    isPDB = True
    (sourceCDB, sourcedb) = sourcedb.split('/')
    if targetdb == originalSourceDB:
        targetdb = sourcedb

# overwrite warning
sameDB = False
if targetdb == sourcedb and targetserver == sourceserver and instant is not True:
    sameDB = True
    if overwrite is not True:
        print('Please use the --overwrite parameter to confirm overwrite of the source database!')
        exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit(1)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# search for database to recover
search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverObjects&searchString=%s&environments=kOracle' % sourceserver, v=2)
objects = None
if search is not None and 'objects' in search:
    # narrow to the correct oracle host
    objects = [o for o in search['objects'] if o['oracleParams']['hostInfo']['name'].lower() == sourceserver.lower()]

# narrow to the correct DB name
if objects is not None and len(objects) > 0:
    if isPDB is True:
        cdbObjects = [o for o in objects if o['objectType'] != 'kPDB' and o['name'].lower() == sourceCDB.lower()]
        if cdbObjects is not None and len(cdbObjects) > 0:
            cdbUuid = cdbObjects[0]['uuid']
            objects = [o for o in objects if o['name'].lower() == sourcedb.lower() and o['uuid'] == cdbUuid]
    else:
        objects = [o for o in objects if o['name'].lower() == sourcedb.lower()]

if objects is None or len(objects) == 0:
    print('No backups found for oracle DB %s/%s' % (sourceserver, originalSourceDB))
    exit()

# find best snapshot
latestSnapshot = None
latestSnapshotTimeStamp = 0
latestSnapshotObject = None
pit = None
if logtime is not None:
    desiredPIT = dateToUsecs(logtime)
else:
    now = datetime.now()
    desiredPIT = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

pdblist = []
isCDB = False
granularRestore = False
for object in objects:
    sourcedb = object['name']
    if object['objectType'] == 'kPDB':
        if isPDB is not True:
            print('-sourceDB should be in the form CDBNAME/PDBNAME')
            exit(1)
        granularRestore = True
        pdblist = [o for o in cdbObjects[0]['oracleParams']['databaseEntityInfo']['containerDatabaseInfo']['pluggableDatabaseList'] if o['databaseName'] == sourcedb]
        if targetcdb is None and sameDB is False:
            print('--targetcdb is required when restoring a PDB to an alternate location')
            exit(1)
    else:
        if object['oracleParams']['databaseEntityInfo']['containerDatabaseInfo']['pluggableDatabaseList'] is not None:
            isCDB = True
            # granularRestore = True
            pdblist = object['oracleParams']['databaseEntityInfo']['containerDatabaseInfo']['pluggableDatabaseList']
            if pdbnames is not None and len(pdbnames) > 0 and sameDB is False:
                granularRestore = True
                pdblist = [p for p in pdblist if p['databaseName'].lower() in [n.lower() for n in pdbnames]]
                missingPDBs = [p for p in pdbnames if p.lower() not in [n['databaseName'].lower() for n in pdblist]]
                if len(missingPDBs) > 0:
                    print('PDBs not found: %s' % (', '.join(missingPDBs)))
                    exit(1)

    if granularRestore is True:
        newPdbList = []
        for pdb in pdblist:
            newPdbList.append({
                "dbId": pdb['databaseId'],
                "dbName": pdb['databaseName']
            })

    availableJobInfos = sorted(object['latestSnapshotsInfo'], key=lambda o: o['protectionRunStartTimeUsecs'], reverse=True)
    for jobInfo in availableJobInfos:
        snapshots = api('get', 'data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (object['id'], jobInfo['protectionGroupId']), v=2)
        snapshots = [s for s in snapshots['snapshots'] if s['snapshotTimestampUsecs'] <= desiredPIT]
        if snapshots is not None and len(snapshots) > 0:
            localsnapshots = [s for s in snapshots if s['snapshotTargetType'] == 'Local']
            if localsnapshots is not None and len(localsnapshots) > 0:
                snapshots = localsnapshots
            if snapshots[-1]['snapshotTimestampUsecs'] > latestSnapshotTimeStamp:
                latestSnapshot = snapshots[-1]
                latestSnapshotTimeStamp = snapshots[-1]['snapshotTimestampUsecs']
                latestSnapshotObject = object

if latestSnapshotObject is None:
    if logtime is not None:
        print('No snapshots found for oracle entity %s from before %s' % (sourceserver, logtime))
    else:
        print('No snapshots found for oracle entity %s' % sourceserver)
    exit(1)

# find log range for desired PIT
if logtime is not None or latest:
    latestLogPIT = 0
    logStart = latestSnapshotTimeStamp
    if logtime is not None:
        logEnd = desiredPIT + 60000000
    else:
        logEnd = desiredPIT
    (clusterId, clusterIncarnationId, protectionGroupId) = latestSnapshot['protectionGroupId'].split(':')
    logParams = {
        "jobUids": [
            {
                "clusterId": int(clusterId),
                "clusterIncarnationId": int(clusterIncarnationId),
                "id": int(protectionGroupId)
            }
        ],
        "environment": "kOracle",
        "protectionSourceId": latestSnapshotObject['id'],
        "startTimeUsecs": int(logStart),
        "endTimeUsecs": int(logEnd)
    }
    logRanges = api('post', 'restore/pointsForTimeRange', logParams)
    if logRanges is not None and len(logRanges) > 0:
        if not isinstance(logRanges, list):
            logRanges = [logRanges]
        for logRange in logRanges:
            if 'timeRanges' in logRange:
                if logRange['timeRanges'][0]['endTimeUsecs'] > latestLogPIT:
                    latestLogPIT = logRange['timeRanges'][0]['endTimeUsecs']
                    if desiredPIT > latestLogPIT:
                        pit = latestLogPIT
                if latest:
                    pit = logRange['timeRanges'][0]['endTimeUsecs']
                    break
                elif logRange['timeRanges'][0]['endTimeUsecs'] > desiredPIT and logRange['timeRanges'][0]['startTimeUsecs'] <= desiredPIT:
                    pit = desiredPIT
                    break
    if pit is None and logtime is not None:
        print('Warning: best available point in time is %s' % usecsToDate(latestSnapshotTimeStamp))
    elif desiredPIT != pit and not latest:
        print('Warning: best available point in time is %s' % usecsToDate(pit))

# find target server
targetEntity = [e for e in api('get', 'protectionSources/registrationInfo?environments=kOracle')['rootNodes'] if e['rootNode']['name'].lower() == targetserver.lower()]
if targetEntity is None or len(targetEntity) == 0:
    print('Target Server %s Not Found' % targetserver)
    exit(1)
targetSource = api('get', 'protectionSources?useCachedData=false&id=%s&allUnderHierarchy=false' % targetEntity[0]['rootNode']['id'])

taskName = "Recover-Oracle-%s-%s-%s" % (sourceserver, sourcedb, datetime.now().strftime("%Y-%m-%d_%H-%M-%S"))

restoreParams = {
    "name": taskName,
    "snapshotEnvironment": "kOracle",
    "oracleParams": {
        "objects": [
            {
                "snapshotId": latestSnapshot['id']
            }
        ],
        "recoveryAction": "RecoverApps",
        "recoverAppParams": {
            "targetEnvironment": "kOracle",
            "oracleTargetParams": {
                "recoverToNewSource": False
            }
        }
    }
}

if sameDB is True:
    sourceConfig = {
        "dbChannels": None,
        "recoveryMode": None,
        "shellEvironmentVars": None,
        "restoreSpfileOrPfileInfo": None,
        "useScnForRestore": None,
        "rollForwardLogPathVec": None,
        "rollForwardTimeMsecs": None,
        "attemptCompleteRecovery": False
    }  # "granularRestoreInfo": None,
    if granularRestore is True:
        # restore to same cdb
        sourceConfig['granularRestoreInfo'] = {
            "granularityType": "kPDB",
            "pdbRestoreParams": {
                "restoreToExistingCdb": True,
                "pdbObjects": newPdbList
            }
        }
else:
    sourceConfig = {
        "host": {
            "id": targetEntity[0]['rootNode']['id']
        },
        "recoveryTarget": "RecoverDatabase",
        "recoverDatabaseParams": {
            "databaseName": targetdb,
            "dbFilesDestination": oracledata,
            "enableArchiveLogMode": bool_archiveLogMode,
            "numTempfiles": numtempfiles,
            "oracleBaseFolder": oraclebase,
            "oracleHomeFolder": oraclehome,
            "pfileParameterMap": [],
            "redoLogConfig": {
                "groupMembers": [],
                "memberPrefix": redologprefix,
                "numGroups": numredologs,
                "sizeMBytes": redologsizemb
            },
            "newPdbName": None,
            "nofilenameCheck": bool_noFilenameCheck,
            "newNameClause": newnameclause,
            "oracleSid": None,
            "systemIdentifier": None,
            "dbChannels": None,
            "recoveryMode": bool_noRecovery,
            "shellEvironmentVars": None,
            "restoreSpfileOrPfileInfo": None,
            "useScnForRestore": None,
            "oracleUpdateRestoreOptions": None,
            "isMultiStageRestore": False,
            "rollForwardLogPathVec": None
        }  # "granularRestoreInfo": None,
    }
    if instant is True:
        sourceConfig['recoverDatabaseParams']['isMultiStageRestore'] = True
        sourceConfig['recoverDatabaseParams']['oracleUpdateRestoreOptions'] = {
            "delaySecs": 0,
            "targetPathVec": [
                oracledata
            ]
        }
    if granularRestore is True:
        # restore to alternate cdb
        sourceConfig['recoverDatabaseParams']['granularRestoreInfo'] = {
            "granularityType": "kPDB",
            "pdbRestoreParams": {
                "restoreToExistingCdb": True,
                "pdbObjects": newPdbList,
                "renamePdbMap": None
            }
        }
        if isPDB is True:
            sourceConfig['recoverDatabaseParams']['databaseName'] = targetcdb
            if targetdb.lower() != sourcedb.lower():
                sourceConfig['recoverDatabaseParams']['granularRestoreInfo']['pdbRestoreParams']['renamePdbMap'] = [
                    {
                        "key": sourcedb,
                        "value": targetdb
                    }
                ]
        if isCDB is True:
            sourceConfig['recoverDatabaseParams']['granularRestoreInfo']['pdbRestoreParams']['restoreToExistingCdb'] = False
    if bctfilepath is not None:
        sourceConfig['recoverDatabaseParams']['bctFilePath'] = bctfilepath

if sameDB is True:
    restoreParams['oracleParams']['recoverAppParams']['oracleTargetParams']['originalSourceConfig'] = sourceConfig
else:
    restoreParams['oracleParams']['recoverAppParams']['oracleTargetParams']['newSourceConfig'] = sourceConfig
    restoreParams['oracleParams']['recoverAppParams']['oracleTargetParams']['recoverToNewSource'] = True
    metaParams = {
        "environment": "kOracle",
        "oracleParams": {
            "baseDir": oraclebase,
            "dbFileDestination": oracledata,
            "dbName": targetdb,
            "homeDir": oraclehome,
            "isClone": False,
            "isGranularRestore": False,
            "isRecoveryValidation": False
        }
    }
    # get pfile parameters
    if not clearpfileparameters:
        metaInfo = api('post', 'data-protect/snapshots/%s/metaInfo' % latestSnapshot['id'], metaParams, v=2)
        sourceConfig['recoverDatabaseParams']['pfileParameterMap'] = metaInfo['oracleParams']['restrictedPfileParamMap'] + metaInfo['oracleParams']['inheritedPfileParamMap'] + metaInfo['oracleParams']['cohesityPfileParamMap']
    # handle pfile parameters
    if len(pfileparams) > 0:
        for pfileparam in pfileparams:
            paramparts = pfileparam.split('=', 1)
            if len(paramparts) < 2:
                print('pfile parameter is invalid')
                exit(1)
            else:
                paramname = paramparts[0].strip()
                paramval = paramparts[1].strip()
            if len(paramparts) == 3:
                paramval = paramval + "=" + paramparts[2].strip()
            existingParam = False
            # for pfileparam in sourceConfig['recoverDatabaseParams']['pfileParameterMap']:
            #     if pfileparam['key'].lower() == paramname.lower():
            #         existingParam = True
            #         pfileparam['value'] = paramval
            if existingParam is False:
                sourceConfig['recoverDatabaseParams']['pfileParameterMap'].append({
                    "key": paramname,
                    "value": paramval
                })

    if len(shellvars) > 0:
        sourceConfig['recoverDatabaseParams']['shellEvironmentVars'] = []
        for shellvar in shellvars:
            varparts = shellvar.split('=')
            if len(varparts) < 2:
                print('invalid shell variable')
                exit(1)
            else:
                varname = varparts[0].strip()
                varval = varparts[1].strip()
                sourceConfig['recoverDatabaseParams']['shellEvironmentVars'].append({
                    "key": varname,
                    "value": varval
                })

# set pit
if pit is not None:
    restoreParams['oracleParams']['objects'][0]['pointInTimeUsecs'] = pit
    if sameDB is True:
        sourceConfig['restoreTimeUsecs'] = pit
    else:
        sourceConfig['recoverDatabaseParams']['restoreTimeUsecs'] = pit
    recoverTime = usecsToDate(pit)
else:
    recoverTime = usecsToDate(latestSnapshotTimeStamp)

# handle channels

channelConfig = None
if channelnode is not None and 'networkingInfo' in targetSource[0]['protectionSource']['physicalProtectionSource']:
    channelNodes = [n for n in targetSource[0]['protectionSource']['physicalProtectionSource']['networkingInfo']['resourceVec'] if n['type'] == 'kServer']
    channelNodes = [n for n in channelNodes if channelnode.lower() in [e['fqdn'].lower() for e in n['endpoints']]]
    if channelNodes is None or len(channelNodes) == 0:
        print('%s not found' % channelnode)
        exit(1)
    endPoint = [e for e in channelNodes[0]['endpoints'] if 'ipv4Addr' in e and e['ipv4Addr'] is not None][0]
    agent = [a for a in targetSource[0]['protectionSource']['physicalProtectionSource']['agents'] if a['name'] == endPoint['fqdn']][0]
    channelConfig = {
        "databaseUniqueName": latestSnapshotObject['name'],
        "databaseUuid": latestSnapshotObject['uuid'],
        "databaseNodeList": [
            {
                "hostAddress": endPoint['ipv4Addr'],
                "hostId": str(agent['id']),
                "fqdn": endPoint['fqdn'],
                "channelCount": channels,
                "port": None
            }
        ],
        "enableDgPrimaryBackup": True,
        "rmanBackupType": "kImageCopy",
        "credentials": None
    }
else:
    if channels > 1:
        agent = [a for a in targetSource[0]['protectionSource']['physicalProtectionSource']['agents'] if a['name'] == targetSource[0]['protectionSource']['name']][0]
        channelConfig = {
            "databaseUniqueName": latestSnapshotObject['name'],
            "databaseUuid": latestSnapshotObject['uuid'],
            "databaseNodeList": [
                {
                    "hostAddress": targetSource[0]['protectionSource']['name'],
                    "hostId": str(agent['id']),
                    "fqdn": targetSource[0]['protectionSource']['physicalProtectionSource']['hostName'],
                    "channelCount": channels,
                    "port": None
                }
            ],
            "enableDgPrimaryBackup": True,
            "rmanBackupType": "kImageCopy",
            "credentials": None
        }

if sameDB is True:
    if channelConfig is not None:
        sourceConfig['dbChannels'] = [channelConfig]
else:
    if channelConfig is not None:
        sourceConfig['recoverDatabaseParams']['dbChannels'] = [channelConfig]

# perform the restore
reportTarget = targetdb
if targetcdb is not None:
    reportTarget = '%s/%s' % (targetcdb, targetdb)

if printinfo is True:
    print('\nYou are Connected to: %s' % vip)
    print('Source Server: %s' % sourceserver)
    print('Source Database: %s' % originalSourceDB)
    print('Target Server: %s' % targetserver)
    print('Target Database: %s\n' % reportTarget)

# debug output API payload
if dbg:
    display(restoreParams)
    dbgoutput = codecs.open('./ora-restore.json', 'w')
    json.dump(restoreParams, dbgoutput)
    dbgoutput.close()
    print('\nWould restore %s/%s to %s/%s (Point in time: %s)' % (sourceserver, originalSourceDB, targetserver, reportTarget, recoverTime))
    exit(0)

print('Restoring %s/%s to %s/%s (Point in time: %s)' % (sourceserver, originalSourceDB, targetserver, reportTarget, recoverTime))
response = api('post', 'data-protect/recoveries', restoreParams, v=2)

if 'errorCode' in response or 'id' not in response:
    exit(1)

if wait is True or progress is True:
    lastProgress = -1
    taskId = response['id'].split(':')[2]
    status = api('get', '/restoretasks/%s' % taskId)
    finishedStates = ['kSuccess', 'kFailed', 'kCanceled', 'kFailure']
    while status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates:
        sleep(15)
        status = api('get', '/restoretasks/%s' % taskId)
        if progress:
            progressMonitor = api('get', '/progressMonitors?taskPathVec=restore_sql_%s&includeFinishedTasks=true&excludeSubTasks=false' % taskId)
            try:
                percentComplete = progressMonitor['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                percentComplete = int(round(percentComplete, 0))
                if percentComplete > lastProgress:
                    print('%s percent complete' % percentComplete)
                    lastProgress = percentComplete
            except Exception:
                pass
    if status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess':
        print('Restore Completed Successfully')
        exit(0)
    else:
        print('Restore Ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
exit(0)
