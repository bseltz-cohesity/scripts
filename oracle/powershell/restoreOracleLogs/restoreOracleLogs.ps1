# version 2024-12-01

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$sourceServer,
    [Parameter(Mandatory = $True)][string]$sourceDB,
    [Parameter()][string]$targetServer = $sourceServer,
    [Parameter()][string]$targetDB = $sourceDB,
    [Parameter()][string]$oracleHome,
    [Parameter()][string]$oracleBase,
    [Parameter()][int]$channels,
    [Parameter()][string]$channelNode,
    [Parameter()][ValidateSet('lsn', 'scn', 'time')][string]$rangeType = 'lsn',
    [Parameter()][string]$startTime,
    [Parameter()][string]$endTime,
    [Parameter()][Int64]$startOfRange,
    [Parameter()][Int64]$endOfRange,
    [Parameter()][Int64]$threadId,
    [Parameter()][Int64]$incarnationId,
    [Parameter()][Int64]$resetLogId,
    [Parameter(Mandatory = $True)][string]$path,
    [Parameter()][switch]$showRanges,
    [Parameter()][switch]$wait,
    [Parameter()][switch]$progress,
    [Parameter()][switch]$dbg
)

# validate arguments
if($targetServer -ne $sourceServer){
    if(! $oracleHome -or ! $oracleBase){
        Write-Warning "-oracleHome and -oracleBase are required when restoring to another server"
        exit 1
    }
}

$sameServer = $false
if($targetServer -eq $sourceServer){
    $sameServer = $True
}

$rangetypeinfos = @{
    'lsn' = 'SequenceRangeInfo';
    'scn' = 'ScnRangeInfo';
    'time' = 'TimeRangeInfo'
}
$rangetypeinfo = $rangetypeinfos[$rangetype]
$rangetypes = @{
    'lsn' = 'Sequence';
    'scn' = 'Scn';
    'time'=  'Time'
}

$rtype = $rangetypes[$rangetype]

$configurechannels = $false
if($channelnode -or $channels){
    $configurechannels = True
    if($channels -and ! $channelNode){
        $channelNode = $targetServer
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# search for database to recover
$search = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverObjects&searchString=$sourceDB&environments=kOracle"
$objects = $search.objects | Where-Object {$_.oracleParams.hostInfo.name -eq $sourceServer}
$objects = $objects | Where-Object {$_.name -eq $sourceDB}

if($null -eq $objects){
    write-host "No backups found for oracle DB $sourceServer/$originalSourceDB" -foregroundcolor yellow
    exit 1
}

# find best snapshot
$latestSnapshot = $null
$latestSnapshotTimeStamp = 0
$latestSnapshotObject = $null

foreach($object in $objects){
    $sourceDB = $object.name
    $availableJobInfos = $object.latestSnapshotsInfo | Sort-Object -Property protectionRunStartTimeUsecs -Descending
    foreach($jobInfo in $availableJobInfos){
        $snapshots = api get -v2 "data-protect/objects/$($object.id)/snapshots?protectionGroupIds=$($jobInfo.protectionGroupId)"
        $snapshots = $snapshots.snapshots
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
    write-host "No snapshots found for oracle entity $sourceServer" -foregroundcolor yellow
    exit 1
}

$midnight = (Get-Date -Hour 0 -Minute 0).AddDays(1).AddSeconds(-1)
$midnightUsecs = dateToUsecs $midnight
$ranges = api get -v2 "data-protect/objects/$($latestSnapshotObject.id)/pit-ranges?toTimeUsecs=$midnightUsecs&protectionGroupIds=$($latestSnapshot.protectionGroupId)&fromTimeUsecs=0"
$ranges = $ranges.oracleRestoreRangeInfo.$rangetypeinfo

if($startTime){
    $startTimeUsecs = dateToUsecs $startTime
}
if($endTime){
    $endTimeUsecs = dateToUsecs $endTime
}

if($rangeType -eq 'time'){
    if($startTime){
        $ranges = $ranges | Where-Object {$_.startOfRange -le $startTimeUsecs -and $_.endOfRange -gt $startTimeUsecs}
    }
    if($endTime){
        $ranges = $ranges | Where-Object {$_.endOfRange -ge $endTimeUsecs}
    }
}else{
    if($incarnationId){
        $ranges = $ranges | Where-Object incarnationId -eq $incarnationId
    }
    if($threadId){
        $ranges = $ranges | Where-Object threadId -eq $threadId
    }
    if($resetLogId){
        $ranges = $ranges | Where-Object resetLogId -eq $resetLogId
    }
    if($startOfRange){
        $ranges = $ranges | Where-Object {$_.startOfRange -le $startOfRange -and $_.endOfRange -gt $startOfRange}
    }
    if($endOfRange){
        $ranges = $ranges | Where-Object {$_.endOfRange -ge $endOfRange}
    }
}

if(!$ranges){
    Write-Host "no ranges meet the specified parameters" -ForegroundColor Yellow
    exit 1
}

# display ranges
if($showRanges){
    if($rangeType -eq 'lsn'){
        $ranges | Format-Table -Property startOfRange, endOfRange, resetLogId, incarnationId, threadId
    }elseif($rangeType -eq 'scn'){
        $ranges | Format-Table -Property startOfRange, endOfRange, resetLogId, incarnationId
    }else{
        $ranges | Format-Table -Property @{label='startOfRange'; expression={usecsToDate $_.startOfRange -format 'yyyy-MM-dd hh:mm:ss'}}, @{label='endOfRange'; expression={usecsToDate $_.endOfRange -format 'yyyy-MM-dd hh:mm:ss'}}
    }
    exit
}

# select range
if($rangeType -eq 'time'){
    $range = $ranges[-1]
    if($startTime){
        $range.startOfRange = $startTimeUsecs
    }
    if($endTime){
        $range.endOfRange = $endTimeUsecs
    }
}else{
    $range = $ranges[-1]
    if($startOfRange){
        $range.startOfRange = $startOfRange
    }
    if($endOfRange){
        $range.endOfRange = $endOfRange
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
$taskName = "Recover_Oracle_Logs_{0}_{1}_{2}" -f $sourceServer, $sourceDB, $(get-date -UFormat '%b_%d_%Y_%H-%M%p')

$recoveryParams = @{
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
                "recoverToNewSource" = $false;
            }
        }
    }
}

if($sameServer -eq $True){
    $recoveryParams.oracleParams.recoverAppParams.oracleTargetParams["originalSourceConfig"] = @{
        "dbChannels" = $null;
        "granularRestoreInfo" = $null;
        "oracleArchiveLogInfo" = @{
            "archiveLogRestoreDest" = $path;
            "rangeType" = $rtype;
            "rangeInfoVec" = @(
                $range
            )
        };
        "rollForwardLogPathVec" = $null;
        "rollForwardTimeMsecs" = $null;
        "attemptCompleteRecovery" = $false
    }
}else{
    $recoveryParams.oracleParams.recoverAppParams.oracleTargetParams["newSourceConfig"] = @{
        "host" = @{
            "id" = $targetSource[0].protectionSource.id
        };
        "recoveryTarget" = "RecoverDatabase";
        "recoverDatabaseParams" = @{
            "bctFilePath" = $null;
            "databaseName" = $targetDB;
            "enableArchiveLogMode" = $True;
            "numTempfiles" = $null;
            "oracleBaseFolder" = $oracleBase;
            "oracleHomeFolder" = $oracleHome;
            "pfileParameterMap" = $null;
            "redoLogConfig" = @{
                "groupMembers" = @()
            };
            "newPdbName" = $null;
            "nofilenameCheck" = $false;
            "newNameClause" = $null;
            "oracleSid" = $targetDB;
            "systemIdentifier" = $null;
            "dbChannels" = $null;
            "granularRestoreInfo" = $null;
            "oracleArchiveLogInfo" = @{
                "archiveLogRestoreDest" = $path;
                "rangeType" = $rtype;
                "rangeInfoVec" = @(
                    $range
                )
            };
            "oracleUpdateRestoreOptions" = $null;
            "isMultiStageRestore" = $false;
            "rollForwardLogPathVec" = $null;
            "disasterRecoveryOptions" = $null;
            "restoreToRac" = $false
        }
    }
    $recoveryParams.oracleParams.recoverAppParams.oracleTargetParams.recoverToNewSource = $True
}

# handle channels
$channelConfig = $null
if($configurechannels -eq $True){
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
    if($channelConfig -ne $null){
        if($sameServer -eq $True){
            $recoveryParams.oracleParams.recoverAppParams.oracleTargetParams.originalSourceConfig.dbChannels = $channelConfig
        }else{
            $recoveryParams.oracleParams.recoverAppParams.oracleTargetParams.newSourceConfig.recoverDatabaseParams.dbChannels = $channelConfig
        }
    }
}

# debug output API payload
if($dbg){
    $recoveryParams | ConvertTo-Json -Depth 99
    exit
}

Write-Host "Performing recovery..."
$response = api post -v2 data-protect/recoveries $recoveryParams

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
