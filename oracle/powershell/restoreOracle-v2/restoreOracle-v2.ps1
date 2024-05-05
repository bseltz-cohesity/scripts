# version 2024-04-30

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$sourceServer, # protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$sourceDB,     # name of the source DB we want to clone
    [Parameter()][string]$targetServer = $sourceServer,  # where to attach the clone DB
    [Parameter()][string]$targetDB = $sourceDB,          # desired clone DB name
    [Parameter()][array]$pdbNames,                       # PDBs to include in a CDB restore
    [Parameter()][string]$targetCDB,                     # Alternate CDB for a PDB restore
    [Parameter()][string]$oracleHome = $null,            # oracle home location
    [Parameter()][string]$oracleBase = $null,            # oracle base location
    [Parameter()][string]$oracleData = $null,            # destination for data files
    [Parameter()][string]$logTime,                       # PIT to replay logs to e.g. '2019-01-20 02:01:47'
    [Parameter()][switch]$latest,                        # replay to latest available log PIT
    [Parameter()][switch]$noRecovery,                    # leave the restored DB in noRecovery mode
    [Parameter()][switch]$overWrite,                     # overwrite existing DB
    [Parameter()][int]$channels = $null,                 # number of restore channels
    [Parameter()][string]$channelNode = $null,           # destination for data files
    [Parameter()][switch]$noFilenameCheck,               # skip filename check
    [Parameter()][switch]$noArchiveLogMode,              # enable archive log mode on target DB
    [Parameter()][int]$numTempFiles = 0,                 # number of temp files
    [Parameter()][string]$newNameClause = $null,         # new name clause
    [Parameter()][int]$numRedoLogs = $null,              # number of redo log groups
    [Parameter()][int]$redoLogSizeMB = 20,               # size of redo log groups
    [Parameter()][string]$redoLogPrefix = $null,         # redo log prefix
    [Parameter()][string]$bctFilePath = $null,           # alternate bct file path
    [Parameter()][array]$pfileParameterName,             # pfile parameter names
    [Parameter()][array]$pfileParameterValue,            # pfile parameter values
    [Parameter()][array]$shellVarName,                   # shell variable names
    [Parameter()][array]$shellVarValue,                  # shell variable values
    [Parameter()][switch]$wait,                          # wait for restore to finish
    [Parameter()][switch]$progress,                      # display progress
    [Parameter()][switch]$dbg,
    [Parameter()][switch]$instant,
    [Parameter()][switch]$windows
)

# validate arguments
if($targetServer -ne $sourceServer -or $targetDB -ne $sourceDB -or $instant){
    if($oracleHome -eq $null -or $oracleBase -eq $null -or $oracleData -eq $null){
        Write-Warning "-oracleHome, -oracleBase, and -oracleData are required when restoring to another server/database"
        exit 1
    }
}

# parse CDB/PDB name
$isPDB = $false
$originalSourceDB = $sourceDB
if($sourceDB -match '/'){
    $isPDB = $True
    $sourceCDB, $sourceDB = $sourceDB -split '/'
    if($targetDB -eq $originalSourceDB){
        $targetDB = $sourceDB
    }
}

# overwrite warning
$sameDB = $false
if($targetDB -eq $sourceDB -and $targetServer -eq $sourceServer -and ! $instant){
    $sameDB = $True
    if(! $overWrite){
        write-host "Please use the -overWrite parameter to confirm overwrite of the source database!" -ForegroundColor Yellow
        exit 1
    }
}

# boolean switches
$bool_noFilenameCheck = $false
if($noFilenameCheck){
    $bool_noFilenameCheck = $True 
}

$bool_archiveLogMode = $True
if($noArchiveLogMode){
    $bool_archiveLogMode = $false
}

$bool_noRecovery = $false
if($noRecovery){
    $bool_noRecovery = $True
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# search for database to recover
$search = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverObjects&searchString=$sourceDB&environments=kOracle"

# narrow to the correct oracle host
$objects = $search.objects | Where-Object {$_.oracleParams.hostInfo.name -eq $sourceServer}

# narrow to the correct DB name
if($isPDB){
    $cdbObjects = $objects | Where-Object {$_.objectType -ne 'kPDB' -and $_.name -eq $sourceCDB}
    $objects = $objects | Where-Object {$_.name -eq $sourceDB -and $_.uuid -eq $cdbObjects.uuid}
}else{
    $objects = $objects | Where-Object {$_.name -eq $sourceDB}
}

if($null -eq $objects){
    write-host "No backups found for oracle DB $sourceServer/$originalSourceDB" -foregroundcolor yellow
    exit 1
}

# find best snapshot
$latestSnapshot = $null
$latestSnapshotTimeStamp = 0
$latestSnapshotObject = $null
$pit = $null
if($logTime){
    $desiredPIT = dateToUsecs $logTime
}else{
    $desiredPIT = dateToUsecs (Get-Date)
}

$pdbList = @()
$isCDB = $false
$granularRestore = $false

foreach($object in $objects){
    $sourceDB = $object.name
    if($object.objectType -eq 'kPDB'){
        if($isPDB -ne $True){
            Write-Host "-sourceDB should be in the form CDBNAME/PDBNAME" -ForegroundColor Yellow
            exit 1
        }
        $granularRestore = $True
        $pdbList = $cdbObjects.oracleParams.databaseEntityInfo.containerDatabaseInfo.pluggableDatabaseList | Where-Object {$_.databaseName -eq $sourceDB}
        if(! $targetCDB -and ($sameDB -eq $false)){
            Write-Host "-targetCDB is required when restoring a PDB to an alternate location" -ForegroundColor Yellow
            exit 1
        }
    }else{
        if($object.oracleParams.databaseEntityInfo.containerDatabaseInfo.pluggableDatabaseList -ne $null){
            $isCDB = $True
            $pdbList = $object.oracleParams.databaseEntityInfo.containerDatabaseInfo.pluggableDatabaseList
            if($pdbNames -and ($sameDB -eq $false)){
                $granularRestore = $True
                $pdbList = $pdbList | Where-Object {$_.databaseName -in $pdbNames}
            }
        }
        $missingPDBs = $pdbNames | Where-Object {$_ -notin $pdbList.databaseName}
        if($missingPDBs){
            Write-Host "PDBs not found: $($missingPDBs)" -ForegroundColor Yellow
            exit 1
        }
    }
    if($granularRestore){
        $newPdbList = @()
        foreach($pdb in $pdbList){
            $newPdbList = @($newPdbList + @{
                "dbId" = $pdb.databaseId;
                "dbName" = $pdb.databaseName
            })
        }
    }
    $availableJobInfos = $object.latestSnapshotsInfo | Sort-Object -Property protectionRunStartTimeUsecs -Descending
    foreach($jobInfo in $availableJobInfos){
        $snapshots = api get -v2 "data-protect/objects/$($object.id)/snapshots?protectionGroupIds=$($jobInfo.protectionGroupId)"
        $snapshots = $snapshots.snapshots | Where-Object {$_.snapshotTimestampUsecs -le $desiredPIT}
        if($snapshots.Count -gt 0){
            $localSnapshots = $snapshots | Where-Object snapshotTargetType -eq 'Local'
            if($localSnapshots.Count -gt 0){
                $snapshots = $localSnapshots
            }
            if($snapshots[-1].snapshotTimestampUsecs -gt $latestSnapshotTimeStamp){
                $latestSnapshot = $snapshots[-1]
                $latestSnapshotTimeStamp = $snapshots[-1].snapshotTimestampUsecs
                $latestSnapshotObject = $object
            }
        }
    }
}

if(! $latestSnapshotObject){
    if($logTime){
        write-host "No snapshots found for oracle entity $sourceServer from before $logTime" -foregroundcolor yellow
        exit 1
    }else{
        write-host "No snapshots found for oracle entity $sourceServer" -foregroundcolor yellow
        exit 1
    }
}

# find log range for desired PIT
if($logTime -or $latest){
    $latestLogPIT = 0
    $logStart = $latestSnapshotTimeStamp
    if($logTime){
        $logEnd = $desiredPIT + 60000000
    }else{
        $logEnd = $desiredPIT
    }
    $clusterId, $clusterIncarnationId, $protectionGroupId = $latestSnapshot.protectionGroupId -split(':')
    $logParams = @{
        "jobUids" = @(
            @{
                "clusterId" = [int64]$clusterId;
                "clusterIncarnationId" = [int64]$clusterIncarnationId;
                "id" = [int64]$protectionGroupId
            }
        );
        "environment" = "kOracle";
        "protectionSourceId" = $latestSnapshotObject.id;
        "startTimeUsecs" = [int64]$logStart;
        "endTimeUsecs" = [int64]$logEnd
    }
    $logRanges = api post restore/pointsForTimeRange $logParams
    foreach($logRange in $logRanges){
        if($logRange.PSObject.Properties['timeRanges']){
            if($logRange.timeRanges[0].endTimeUsecs -gt $latestLogPIT){
                $latestLogPIT = $logRange.timeRanges[0].endTimeUsecs
                if($desiredPIT -gt $latestLogPIT){
                    $pit = $latestLogPIT
                }                        
            }
            if($latest){
                $pit = $logRange.timeRanges[0].endTimeUsecs
                break
            }else{
                if($logRange.timeRanges[0].endTimeUsecs -ge $desiredPIT -and $logRange.timeRanges[0].startTimeUsecs -le $desiredPIT){
                    $pit = $desiredPIT
                    break
                }
            }
        }
    }
    if(! $pit -and $logtime){
        Write-Host "Warning: best available point in time is $(usecsToDate $latestSnapshotTimeStamp)" -foregroundcolor Yellow
    }elseif($desiredPIT -ne $pit -and ! $latest){
        Write-Host "Warning: best available point in time is $(usecsToDate $pit)" -foregroundcolor Yellow
    }
}

# find target server
$targetEntity = (api get protectionSources/registrationInfo?environments=kOracle).rootNodes | Where-Object { $_.rootNode.name -eq $targetServer }
if($null -eq $targetEntity){
    Write-Host "Target Server $targetServer Not Found" -ForegroundColor Yellow
    exit 1
}
$targetSource = api get "protectionSources?useCachedData=false&id=$($targetEntity.rootNode.id)&allUnderHierarchy=false"

# create restore task
$taskName = "Recover_Oracle_{0}_{1}_{2}" -f $sourceServer, $sourceDB, $(get-date -UFormat '%b_%d_%Y_%H-%M%p')

$restoreParams = @{
    "name" = $taskName;
    "snapshotEnvironment" = "kOracle";
    "oracleParams" = @{
        "objects" = @(
            @{
                "snapshotId" = $latestSnapshot.id
            }
        );
        "recoveryAction" = "RecoverApps";
        "recoverAppParams" = @{
            "targetEnvironment" = "kOracle";
            "oracleTargetParams" = @{
                "recoverToNewSource" = $false
            }
        }
    }
}

if($sameDB){
    $sourceConfig = @{
        "dbChannels" = $null;
        "recoveryMode" = $null;
        "shellEvironmentVars" = $null;
        "restoreSpfileOrPfileInfo" = $null;
        "useScnForRestore" = $null;
        "rollForwardLogPathVec" = $null;
        "rollForwardTimeMsecs" = $null;
        "attemptCompleteRecovery" = $false
    }
    if($granularRestore -eq $True){
        # restore to same cdb
        $sourceConfig['granularRestoreInfo'] = @{
            "granularityType" = "kPDB";
            "pdbRestoreParams" = @{
                "restoreToExistingCdb" = $True;
                "pdbObjects" = @($newPdbList)
            }
        }
    }
    if($noRecovery){
        $sourceConfig['recoveryMode'] = $True
    }
}else{
    $sourceConfig = @{
        "host" = @{
            "id" = $targetEntity.rootNode.id
        };
        "recoveryTarget" = "RecoverDatabase";
        "recoverDatabaseParams" = @{
            "databaseName" = $targetDB;
            "dbFilesDestination" = $oracleData;
            "enableArchiveLogMode" = $bool_archiveLogMode;
            "numTempfiles" = $numTempFiles;
            "oracleBaseFolder" = $oracleBase;
            "oracleHomeFolder" = $oracleHome;
            "pfileParameterMap" = @();
            "redoLogConfig" = @{
                "groupMembers" = @();
                "memberPrefix" = $null;
                "numGroups" = $numRedoLogs;
                "sizeMBytes" = $redoLogSizeMB
            };
            "newPdbName" = $null;
            "nofilenameCheck" = $bool_noFilenameCheck;
            "oracleSid" = $null;
            "systemIdentifier" = $null;
            "dbChannels" = $null;
            "recoveryMode" = $null;
            "shellEvironmentVars" = $null;
            "restoreSpfileOrPfileInfo" = $null;
            "useScnForRestore" = $null;
            "oracleUpdateRestoreOptions" = $null;
            "isMultiStageRestore" = $false;
            "rollForwardLogPathVec" = $null
        }
    }
    if($newNameClause){
        $sourceConfig['recoverDatabaseParams']['newNameClause'] = $newNameClause
    }
    if($redoLogPrefix){
        $sourceConfig['recoverDatabaseParams']['redoLogConfig']['memberPrefix'] = $redoLogPrefix
    }
    if($bctFilePath){
        $sourceConfig['recoverDatabaseParams']['bctFilePath'] = $bctFilePath
    }
    if($noRecovery){
        $sourceConfig['recoverDatabaseParams']['recoveryMode'] = $True
    }
    if($instant){
        $sourceConfig.recoverDatabaseParams.isMultiStageRestore = $True
        $sourceConfig.recoverDatabaseParams['oracleUpdateRestoreOptions'] = @{
            "delaySecs" = 0;
            "targetPathVec" = @(
                $oracleData
            )
        }
    }
    if($granularRestore){
        # restore to alternate cdb
        $sourceConfig.recoverDatabaseParams['granularRestoreInfo'] = @{
            "granularityType" = "kPDB";
            "pdbRestoreParams" = @{
                "restoreToExistingCdb" = $True;
                "pdbObjects" = @($newPdbList);
                "renamePdbMap" = $null
            }
        }
        if($isPDB){
            $sourceConfig.recoverDatabaseParams.databaseName = $targetCDB
            if($targetDB -ne $sourceDB){
                $sourceConfig.recoverDatabaseParams.granularRestoreInfo.pdbRestoreParams.renamePdbMap = @(
                    @{
                        "key" = "$sourceDB";
                        "value" = "$targetDB"
                    }
                )
            }
        }
        if($isCDB){
            $sourceConfig.recoverDatabaseParams.granularRestoreInfo.pdbRestoreParams.restoreToExistingCdb = $false
        }
    }
}

if($sameDB){
    $restoreParams.oracleParams.recoverAppParams.oracleTargetParams['originalSourceConfig'] = $sourceConfig
}else{
    $restoreParams.oracleParams.recoverAppParams.oracleTargetParams['newSourceConfig'] = $sourceConfig
    $restoreParams.oracleParams.recoverAppParams.oracleTargetParams.recoverToNewSource = $True
    $metaParams = @{
        "environment" = "kOracle";
        "oracleParams" = @{
            "baseDir" = $oracleBase;
            "dbFileDestination" = $oracleData;
            "dbName" = $targetDB;
            "homeDir" = $oracleHome;
            "isClone" = $false;
            "isGranularRestore" = $false;
            "isRecoveryValidation" = $false
        }
    }
    # get pfile parameters
    if(! $windows){
        $metaInfo = api post -v2 data-protect/snapshots/$($latestSnapshot.id)/metaInfo $metaParams
        $sourceConfig.recoverDatabaseParams.pfileParameterMap = @(
            $metaInfo.oracleParams.restrictedPfileParamMap + 
            $metaInfo.oracleParams.inheritedPfileParamMap + 
            $metaInfo.oracleParams.cohesityPfileParamMap)
    }
}

# set pit
if($pit){
    $restoreParams.oracleParams.objects[0]['pointInTimeUsecs'] = $pit
    if($sameDB -eq $True){
        $sourceConfig['restoreTimeUsecs'] = $pit
    }else{
        $sourceConfig.recoverDatabaseParams['restoreTimeUsecs'] = $pit
    }
    
    $recoverTime = usecsToDate $pit
}else{
    $recoverTime = usecsToDate $latestSnapshotTimeStamp
}

# handle pfile parameters
if($pfileParameterName.Count -ne $pfileParameterValue.Count){
    Write-Host "Number of pfile parameter names and values do not match" -ForegroundColor Yellow
    exit 1
}else{
    if(! $windows -and $pfileParameterName.Count -gt 0){
        0..($pfileParameterName.Count - 1) | ForEach-Object {
            $pfKey = [string]$pfileParameterName[$_]
            $pfValue = [string]$pfileParameterValue[$_]
            $sourceConfig.recoverDatabaseParams.pfileParameterMap = @(($sourceConfig.recoverDatabaseParams.pfileParameterMap | Where-Object key -ne $pfKey) + @{
                "key" = $pfKey;
                "value" = $pfValue
            })
        }
    }
}

# handle shell variables
if($shellVarName.Count -ne $shellVarValue.Count){
    Write-Host "Number of shell variable names and values do not match" -ForegroundColor Yellow
    exit 1
}else{
    if($shellVarName.Count -gt 0){
        $sourceConfig.recoverDatabaseParams.shellEvironmentVars = @()
        0..($shellVarName.Count - 1) | ForEach-Object {
            $svKey = [string]$shellVarName[$_]
            $svValue = [string]$shellVarValue[$_]
            $sourceConfig.recoverDatabaseParams.shellEvironmentVars = @($sourceConfig.recoverDatabaseParams.shellEvironmentVars + @{
                "key" = $svKey;
                "value" = $svValue
            })
        }
    }
}

# handle channels
if($channels){
    if($channelNode -and $targetSource.protectionSource.physicalProtectionSource.PSObject.Properties['networkingInfo']){
        $channelNodes = $targetSource.protectionSource.physicalProtectionSource.networkingInfo.resourceVec # | Where-Object type -eq 'kServer'
        $channelNodes = $channelNodes | Where-Object {$channelNode -in $_.endpoints.fqdn}
        if(! $channelNodes){
            Write-Host "$channelNode not found" -foregroundcolor Yellow
            exit 1
        }
        $endPoint = ($channelNodes[0].endpoints | Where-Object {$_.ipv4Addr -ne $null})[0]
        $agent = $targetSource.protectionSource.physicalProtectionSource.agents | Where-Object name -eq $endPoint.fqdn
        $channelConfig  = @{
            "databaseUniqueName" = $latestSnapshotObject.name;
            "databaseUuid" = $latestSnapshotObject.uuid;
            "databaseNodeList" = @(
                @{
                    "hostAddress" = $endPoint.ipv4Addr;
                    "hostId" = [string]$agent.id;
                    "fqdn" = $endPoint.fqdn;
                    "channelCount" = $channels;
                    "port" = $null
                }
            );
            "enableDgPrimaryBackup" = $true;
            "rmanBackupType" = "kImageCopy";
            "credentials" = $null
        }
    }else{
        $agent = $targetSource.protectionSource.physicalProtectionSource.agents | Where-Object name -eq $targetServer
        $channelConfig = @{
            "databaseUniqueName" = $latestSnapshotObject.name;
            "databaseUuid" = $latestSnapshotObject.uuid;
            "databaseNodeList" = @(
                @{
                    "hostAddress" = $targetSource.protectionSource.name;
                    "hostId" = [string]$agent.id;
                    "fqdn" = $targetSource.protectionSource.physicalProtectionSource.hostName;
                    "channelCount" = $channels;
                    "port" = $null
                }
            );
            "enableDgPrimaryBackup" = $true;
            "rmanBackupType" = "kImageCopy";
            "credentials" = $null
        }
    }
    if($sameDB){
        $sourceConfig.dbChannels = @($channelConfig)
    }else{
        $sourceConfig.recoverDatabaseParams.dbChannels = @($channelConfig)
    }
}

# perform the restore
$reportTarget = $targetDB
if($targetCDB){
    $reportTarget = "$targetCDB/$targetDB"
}

# debug output API payload
if($dbg){
    $restoreParams | ConvertTo-Json -Depth 99 | Tee-Object -FilePath "./ora-restore.json"
    Write-Host "Would restore $sourceServer/$originalSourceDB to $targetServer/$reportTarget (Point in time: $recoverTime)"
    exit
}

Write-Host "Restoring $sourceServer/$originalSourceDB to $targetServer/$reportTarget (Point in time: $recoverTime)"
$response = api post -v2 data-protect/recoveries $restoreParams

# wait for completion
if($wait -or $progress){
    $lastProgress = -1
    $taskId = ($response.id -split(':'))[2]
    $finishedStates = @('kSuccess','kFailed','kCanceled', 'kFailure')
    while($True){
        $restoreTask = api get /restoretasks/$taskId
        $status = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
        if($progress){
            $progressMonitor = api get "/progressMonitors?taskPathVec=restore_sql_$($taskId)&includeFinishedTasks=true&excludeSubTasks=false"
            try{
                $percentComplete = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
                if($percentComplete -gt $lastProgress){
                    "{0} percent complete" -f [math]::Round($percentComplete, 0)
                    $lastProgress = $percentComplete
                }
            }catch{
            }
        }
        if ($status -in $finishedStates){
            break
        }
        Start-Sleep 15
    }
    
    if($status -eq 'kSuccess'){
        Write-Host "restore ended with status: $($status.subString(1))" -ForegroundColor Green
        exit 0
    }else{
        Write-Host "restore ended with status: $($status.subString(1))" -ForegroundColor Yellow
        if($restoreTask.restoreTask.performRestoreTaskState.base.PSObject.Properties['error']){
            Write-Host "$($restoreTask.restoreTask.performRestoreTaskState.base.error.errorMsg)" -ForegroundColor Red
        }
        exit 1
    }
}else{
    exit 0
}
