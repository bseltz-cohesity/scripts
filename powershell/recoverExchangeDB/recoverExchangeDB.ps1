### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter(Mandatory = $True)][string]$dbName,                       # name of mailbox DB to recover
    [Parameter(Mandatory = $True)][string]$targetServer,                 # server to mount to
    [Parameter()][datetime]$recoverDate,                # e.g. '2021-08-18 23:30:00' (will use most recent at or before this date)
    [Parameter()][switch]$teardown,                     # tear down existing recovery view
    [Parameter()][int]$teardownSearchDays = 7,          # days back to search to recovery views to teardown
    [Parameter()][switch]$teardownAfter,                # tear down after user defined commands
    [Parameter()][string]$destination = ''              # destination directory
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

if($teardown){
    $teardowns = 0
    $startTimeUsecs = timeAgo $teardownSearchDays days
    $recoveries = api get -v2 "data-protect/recoveries?startTimeUsecs=$startTimeUsecs&snapshotEnvironments=kExchange&recoveryActions=RecoverApps,CloneAppView&includeTenants=true"
    foreach($recovery in $recoveries.recoveries){
        $restoreTaskId = ($recovery.id -split ':')[2]
        $restoreTask = api get /restoretasks/$restoreTaskId
        if($restoreTask.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].appEntity.displayName -eq $dbName){
            if(!$restoreTask.restoreTask.PSObject.Properties['destroyClonedTaskStateVec'] -and $restoreTask.restoreTask.performRestoreTaskState.canTeardown -eq $True){
                Write-Host $restoreTask.restoreTask.performRestoreTaskState.base.taskId
                Write-Host "Tearing down $($restoreTask.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.exchangeRestoreParams.viewOptions.mountPoint)"
                $null = api post /destroyclone/$($restoreTask.restoreTask.performRestoreTaskState.base.taskId)
                $teardowns += 1
            }
        }
    }
    if($teardowns -eq 0){
        Write-Host "Nothing to tear down"
    }
    exit
}

$targetServers = api get "protectionSources/registrationInfo?environments=kPhysical"
$targetServerObj = $targetServers.rootNodes | Where-Object {$_.rootNode.name -eq $targetServer}
if(!$targetServerObj){
    Write-Host "Target server $targetServer not fouund" -ForegroundColor Yellow
    exit
}

$dbs = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverApps&searchString=$dbName&environments=kExchange"
$exactDB = $dbs.objects | Where-Object name -eq $dbName
if(! $exactDB){
    Write-Host "Exchange DB $dbName not found" -ForegroundColor Yellow
    exit
}

$latestsnapshot = ($exactDB | Sort-Object -Property @{Expression={$_.latestSnapshotsInfo[0].protectionRunStartTimeUsecs}; Ascending = $False})[0]

if($recoverDate){
    $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))

    $snapshots = api get -v2 "data-protect/objects/$($latestsnapshot.id)/snapshots?protectionGroupIds=$($latestsnapshot.latestSnapshotsInfo.protectionGroupId)"
    $snapshots = $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending | Where-Object runStartTimeUsecs -lt $recoverDateUsecs
    if($snapshots -and $snapshots.Count -gt 0){
        $snapshot = $snapshots[0]
        $snapshotId = $snapshot.id
    }else{
        Write-Host "No snapshots available for $dbName"
        exit
    }
}else{
    $snapshot = $latestsnapshot.latestSnapshotsInfo[0].localSnapshotInfo
    $snapshotId = $snapshot.snapshotId
}

$recoverDateString = (get-date).ToString('yyyy-MM-dd_hh-mm-ss')

$viewName = $dbName.replace(' ','-')

$restoreParams = @{
    "name" = "Recover_Exchange_$recoverDateString";
    "snapshotEnvironment" = "kExchange";
    "exchangeParams" = @{
        "recoveryAction" = "RecoverApps";
        "recoverAppParams" = @{
            "targetEnvironment" = "kExchange";
            "exchangeTargetParams" = @{
                "object" = @{
                    "snapshotId" = $snapshotId;
                    "appObjects" = @(
                        @{
                            "recoverToNewSource" = $true;
                            "restoreType" = "RestoreView";
                            "databaseSource" = @{
                                "id" = $exactDB.id
                            };
                            "viewOptions" = @{
                                "viewName" = $viewName
                            };
                            "recoveryTargetConfig" = @{
                                "source" = @{
                                    "id" = $targetServerObj.rootNode.id
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

Write-Host "Recovering $dbName to view $viewName..."
$recovery = api post -v2 data-protect/recoveries $restoreParams

# wait for restores to complete
$finishedStates = @('Canceled', 'Succeeded', 'kFailed')
$pass = 0
do{
    Start-Sleep 5
    $recoveryTask = api get -v2 data-protect/recoveries/$($recovery.id)?includeTenants=true
    $status = $recoveryTask.status

} until ($status -in $finishedStates)
Write-Host "Restore task finished with status: $status"

if($status -eq 'Succeeded'){
    $restoreTaskId = ($recovery.id -split ':')[2]
    $restoreTask = api get /restoretasks/$restoreTaskId
    $mountPoint = $restoreTask.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.exchangeRestoreParams.viewOptions.mountPoint
    $restoreTaskId = ($recovery.id -split ':')[2]
    $restoreTask = api get /restoretasks/$restoreTaskId
    Write-Host "Mount point is $mountPoint"

    # BEGIN USER DEFINED RECOVERY STEPS =================================

    # stop exchange
    # COPY-ITEM -Path $mountPoint\* -Destination $destination
    # check db
    # start exchange

    # END USER DEFINED RECOVERY STEPS ===================================

    if($teardownAfter){
        Write-Host "Tearing down $mountPoint..."
        $null = api post -v2 "data-protect/recoveries/$($recovery.id)/tearDown"
        exit
    }
}





