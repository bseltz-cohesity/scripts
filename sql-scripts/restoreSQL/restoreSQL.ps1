### v6.1 - added support for log replay
### usage (Cohesity 5.x): ./restore-SQL61.ps1 -vip bseltzve01 -username admin -domain local -sourceServer sql2012 -sourceDB proddb -targetServer w2012a -targetDB bseltz-test-restore -overWrite -mdfFolder c:\sqldata -ldfFolder c:\sqldata\logs -ndfFolder c:\sqldata\ndf

### usage (Cohesity 6.x): ./restore-SQL61.ps1 -vip bseltzve01 -username admin -domain local -sourceServer sql2012 -sourceDB cohesitydb -targetDB cohesitydb-restore -overWrite -mdfFolder c:\SQLData -ldfFolder c:\SQLData\logs -ndfFolders @{'*1.ndf'='E:\sqlrestore\ndf1'; '*2.ndf'='E:\sqlrestore\ndf2'}
###                        ./restore-SQL61.ps1 -vip bseltzve01 -username admin -domain local -sourceServer sql2012 -sourceDB cohesitydb -targetDB cohesitydb-restore -overWrite -mdfFolder c:\SQLData -ldfFolder c:\SQLData\logs -logTime '2019-01-18 03:01:15'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,          #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,     #username (local or AD)
    [Parameter()][string]$domain = 'local',              #local or AD domain
    [Parameter(Mandatory = $True)][string]$sourceServer, #protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$sourceDB,     #name of the source DB we want to restore
    [Parameter()][string]$targetServer,                  #where to restore the DB to
    [Parameter()][string]$targetDB = $sourceDB,          #desired restore DB name
    [Parameter()][switch]$overWrite,                     #overwrite existing DB
    [Parameter(Mandatory = $True)][string]$mdfFolder,    #path to restore the mdf
    [Parameter()][string]$ldfFolder = $mdfFolder,        #path to restore the ldf
    [Parameter()][hashtable]$ndfFolders,                 #paths to restore the ndfs (requires Cohesity 6.0x)
    [Parameter()][string]$ndfFolder,                     #single path to restore ndfs (Cohesity 5.0x)
    [Parameter()][string]$logTime,                       #date time to replay logs to e.g. '2019-01-20 02:01:47'
    [Parameter()][switch]$wait,                          #wait for completion
    [Parameter()][string]$targetInstance = 'MSSQLSERVER' #SQL instance name on the targetServer
)

### handle 6.0x alternate secondary data file locations
if($ndfFolders){
    if($ndfFolders -is [hashtable]){
        $secondaryFileLocation = @()
        foreach ($key in $ndfFolders.Keys){
            $secondaryFileLocation += @{'filePattern' = $key; 'targetDirectory' = $ndfFolders[$key]}
        }
    }
}else{
    $secondaryFileLocation = @()
}

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for database to clone
$searchresults = api get /searchvms?environment=SQL`&entityTypes=kSQL`&entityTypes=kVMware`&vmName=$sourceDB

### handle source instance name e.g. instance/dbname
if($sourceDB.Contains('/')){
    $sourceDB = $sourceDB.Split('/')[1]
}

### narrow the search results to the correct source server
$dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer }
if($null -eq $dbresults){
    write-host "Server $sourceServer Not Found" -foregroundcolor yellow
    exit
}

### narrow the search results to the correct source database
$dbresults = $searchresults.vms | Where-Object { $_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $sourceDB }
if($null -eq $dbresults){
    write-host "Database $sourceDB Not Found" -foregroundcolor yellow
    exit
}

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

if($null -eq $latestdb){
    write-host "Database Not Found" -foregroundcolor yellow
    exit 1
}

### identify physical or vm
$entityType = $latestdb.registeredSource.type

### search for source server
$entities = api get /appEntities?appEnvType=3`&envType=$entityType
$sourceEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $sourceServer }
if($null -eq $sourceEntity){
    Write-Host "Source Server Not Found" -ForegroundColor Yellow
    exit 1
}

### handle log replay
$versionNum = 0
$validLogTime = $False

if ($logTime) {
    $logUsecs = dateToUsecs $logTime
    $dbVersions = $latestdb.vmDocument.versions

    foreach ($version in $dbVersions) {
        ### find db date before log time
        $GetRestoreAppTimeRangesArg = @{
            'type'                = 3;
            'restoreAppObjectVec' = @(
                @{
                    'appEntity'     = $latestdb.vmDocument.objectId.entity;
                    'restoreParams' = @{
                        'sqlRestoreParams'    = @{
                            'captureTailLogs'                 = $false;
                            'newDatabaseName'                 = $sourceDB;
                            'alternateLocationParams'         = @{};
                            'secondaryDataFileDestinationVec' = @(@{})
                        };
                        'oracleRestoreParams' = @{
                            'alternateLocationParams' = @{}
                        }
                    }
                }
            );
            'ownerObjectVec'      = @(
                @{
                    'jobUid'         = $latestdb.vmDocument.objectId.jobUid;
                    'jobId'          = $latestdb.vmDocument.objectId.jobId;
                    'jobInstanceId'  = $version.instanceId.jobInstanceId;
                    'startTimeUsecs' = $version.instanceId.jobStartTimeUsecs;
                    'entity'         = $sourceEntity.appEntity.entity;
                    'attemptNum'     = 1
                }
            )
        }
        $logTimeRange = api post /restoreApp/timeRanges $GetRestoreAppTimeRangesArg
        $logStart = $logTimeRange.ownerObjectTimeRangeInfoVec[0].timeRangeVec[0].startTimeUsecs
        $logEnd = $logTimeRange.ownerObjectTimeRangeInfoVec[0].timeRangeVec[0].endTimeUsecs
        if ($logStart -le $logUsecs -and $logUsecs -le $logEnd) {
            $validLogTime = $True
            break
        }
        $versionNum += 1
    }
}

### create new clone task (RestoreAppArg Object)
$restoreTask = @{
    "name" = "dbRestore-$(dateToUsecs (get-date))";
    'action' = 'kRecoverApp';
    'restoreAppParams' = @{
        'type' = 3;
        'ownerRestoreInfo' = @{
            "ownerObject" = @{
                "jobUid" = $latestdb.vmDocument.objectId.jobUid;
                "jobId" = $latestdb.vmDocument.objectId.jobId;
                "jobInstanceId" = $latestdb.vmDocument.versions[$versionNum].instanceId.jobInstanceId;
                "startTimeUsecs" = $latestdb.vmDocument.versions[$versionNum].instanceId.jobStartTimeUsecs;
                "entity" = $sourceEntity.appEntity.entity;
            }
            'ownerRestoreParams' = @{
                'action' = 'kRecoverVMs';
                'powerStateConfig' = @{}
            };
            'performRestore' = $false
        };
        'restoreAppObjectVec' = @(
            @{
                "appEntity" = $latestdb.vmDocument.objectId.entity;
                'restoreParams' = @{
                    'sqlRestoreParams' = @{
                        'captureTailLogs' = $false;
                        'dataFileDestination' = $mdfFolder;
                        'logFileDestination' = $ldfFolder;
                        'secondaryDataFileDestinationVec' = $secondaryFileLocation
                        "newDatabaseName" = $targetDB;
                        'alternateLocationParams' = @{};
                    };
                }
            }
        )
    }
}

### apply log replay time
if($validLogTime -eq $True){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['restoreTimeSecs'] = $([int64]($logUsecs/1000000))
}else{
    if($logTime){
        Write-Host "LogTime of $logTime is out of range" -ForegroundColor Yellow
        Write-Host "Available range is $(usecsToDate $logStart) to $(usecsToDate $logEnd)" -ForegroundColor Yellow
        exit 1
    }
}

### search for target server
if($targetServer){
    $targetEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $targetServer }
    if($null -eq $targetEntity){
        Write-Host "Target Server Not Found" -ForegroundColor Yellow
        exit 1
    }
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHost'] = $targetEntity.appEntity.entity;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHostParentSource'] = @{ 'id' = $targetEntity.appEntity.entity.parentId }
    if($targetInstance){
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = $targetInstance
    }else{
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = 'MSSQLSERVER'
    }
}else{
    $targetServer = $sourceServer
}

### handle 5.0x secondary file location
if($ndfFolder){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['secondaryDataFileDestination'] = $ndfFolder
}

### overWrite existing DB
if($overWrite){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['dbRestoreOverwritePolicy'] = 1
}

### execute the recovery task (post /recoverApplication api call)
$response = api post /recoverApplication $restoreTask

if($response){
    "Restoring $sourceDB to $targetServer as $targetDB"
}

if($wait){
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    $finishedStates = @('kSuccess','kFailed','kCanceled', 'kFailure')
    while($True){
        $status = (api get /restoretasks/$taskId).restoreTask.performRestoreTaskState.base.publicStatus
        if ($status -in $finishedStates){
            break
        }
        sleep 5
    }
    "restore ended with $status"
    if($status -eq 'kSuccess'){
        exit 0
    }else{
        exit 1
    }
}

exit 0
