# version 2022-02-20
# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory = $True)][string]$sourceServer,
    [Parameter()][string]$targetServer = $sourceServer,
    [Parameter()][array]$objectName,
    [Parameter()][string]$prefix,
    [Parameter()][switch]$overWrite,
    [Parameter()][string]$logTime,
    [Parameter()][switch]$wait,
    [Parameter()][switch]$latest,
    [Parameter()][switch]$progress,
    [Parameter()][int]$concurrency = 1,
    [Parameter()][int]$mounts = 1,
    [Parameter()][string]$recoveryArgs = ''
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($mcm){
    apiauth -vip $vip -username $username -domain $domain -helios -password $password
}else{
    if($useApiKey){
        apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password
    }
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

# verify overwrite
if($targetServer -eq $sourceServer -and ($objectName.Count -eq 0 -and $prefix -eq $null)){
    if(!$overWrite){
        Write-Host "-overWrite required if restoring to original location" -foregroundcolor Yellow
        exit
    }
}

# search for target server
$targetEntity = api get protectionSources/rootNodes?environments=kUDA | Where-Object {$_.protectionSource.name -eq $targetServer}

if(!$targetEntity){
    Write-Host "Target server $targetServer not found" -foregroundcolor Yellow
    exit
}

# search for UDA backups to recover
$search = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverObjects&searchString=$sourceServer&environments=kUDA"

$objects = $search.objects | Where-Object {$_.sourceInfo.name -eq $sourceServer}

if($null -eq $objects){
    write-host "No backups found for UDA entity $sourceServer" -foregroundcolor yellow
    exit
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
foreach($object in $objects){
    $availableJobInfos = $object.latestSnapshotsInfo | Sort-Object -Property protectionRunStartTimeUsecs -Descending
    foreach($jobInfo in $availableJobInfos){
        $snapshots = api get -v2 "data-protect/objects/$($object.id)/snapshots?protectionGroupIds=$($jobInfo.protectionGroupId)"
        $snapshots = $snapshots.snapshots | Where-Object {$_.snapshotTimestampUsecs -le $desiredPIT}
        if($snapshots.Count -gt 0){
            if($snapshots[0].snapshotTimestampUsecs -gt $latestSnapshotTimeStamp){
                $latestSnapshot = $snapshots[0]
                $latestSnapshotTimeStamp = $snapshots[0].snapshotTimestampUsecs
                $latestSnapshotObject = $object
            }
        }else{
            if($logTime){
                write-host "No snapshots found for UDA entity $sourceServer from before $logTime" -foregroundcolor yellow
                exit
            }else{
                write-host "No snapshots found for UDA entity $sourceServer" -foregroundcolor yellow
                exit
            }
        }
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
        "environment" = "kUDA";
        "protectionSourceId" = $latestSnapshotObject.id;
        "startTimeUsecs" = [int64]$logStart;
        "endTimeUsecs" = [int64]$logEnd
    }
    $logRanges = api post restore/pointsForTimeRange $logParams
    foreach($logRange in $logRanges){
        if($logRange.PSObject.Properties['timeRanges']){
            if($logRange.timeRanges[0].endTimeUsecs -gt $latestLogPIT){
                $latestLogPIT = $logRange.timeRanges[0].endTimeUsecs
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
    if(!$pit){
        $pit = $latestLogPIT
        Write-Host "Warning: best available point in time is $(usecsToDate $pit)" -foregroundcolor Yellow
    }
}

# define restore parameters
$restoreTaskName = "Recover-UDA-{0}_{1}" -f $sourceServer, $(get-date -UFormat '%b_%d_%Y_%H-%M%p')
$restoreParams = @{
    "name" = $restoreTaskName;
    "snapshotEnvironment" = "kUDA";
    "udaParams" = @{
        "recoveryAction" = "RecoverObjects";
        "recoverUdaParams" = @{
            "concurrency" = $concurrency;
            "mounts" = $mounts;
            "recoverTo" = $null;
            "snapshots" = @(
                @{
                    "snapshotId" = $latestSnapshot.id;
                    "objects" = @()
                }
            );
            "recoveryArgs" = $recoveryArgs
        }
    }
}

# add objects to restore
if($objectName.Count -eq 0){
    $objectName = @($latestSnapshot.objectName)
}

foreach($o in $objectName){
    if($prefix -ne $null){
        $renameTo = "{0}-{1}" -f $prefix, $o
    }else{
        $renameTo = $null
    }
    $restoreParams.udaParams.recoverUdaParams.snapshots[0].objects = @($restoreParams.udaParams.recoverUdaParams.snapshots[0].objects + @{"objectName" = $o;
                                                                                                        "overwrite" = $True;
                                                                                                        "renameTo" = $renameTo})
}

# specify target host ID
if($targetServer -ne $sourceServer){
    $restoreParams.udaParams.recoverUdaParams.recoverTo = $targetEntity.protectionSource.id
}

# specify point in time
if($pit){
    $restoreParams.udaParams.recoverUdaParams.snapshots[0]['pointInTimeUsecs'] = $pit
    $recoverTime = usecsToDate $pit
}else{
    $recoverTime = usecsToDate $latestSnapshotTimeStamp
}

# perform restore
Write-Host "Restoring $sourceServer to $targetServer (Point in time: $recoverTime)..."
$response = api post -v2 data-protect/recoveries $restoreParams

# wait for completion
if($wait -or $progress){
    $lastProgress = -1
    $taskId = ($response.id -split(':'))[2]
    $finishedStates = @('kSuccess','kFailed','kCanceled', 'kFailure')
    while($True){
        $status = (api get /restoretasks/$taskId).restoreTask.performRestoreTaskState.base.publicStatus
        if($progress){
            $progressMonitor = api get "/progressMonitors?taskPathVec=recover_$($taskId)&includeFinishedTasks=true&excludeSubTasks=false"
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
    "restore ended with status: $($status.subString(1))"
    if($status -eq 'kSuccess'){
        exit 0
    }else{
        exit 1
    }
}else{
    exit 0
}
