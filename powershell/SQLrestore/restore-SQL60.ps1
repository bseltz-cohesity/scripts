### usage (Cohesity 5.0x): ./sqlRestoreMulti60.ps1 -vip bseltzve01 -username admin -domain local -sourceServer sql2012 -sourceDB proddb -targetServer w2012a -targetDB bseltz-test-restore -overWrite -mdfFolder c:\sqldata -ldfFolder c:\sqldata\logs -ndfFolder c:\sqldata\ndf

### usage (Cohesity 6.0x): ./sqlRestoreMulti60.ps1 -vip bseltzve01 -username admin -domain local -sourceServer vRA-IAAS -sourceDB bseltz-test -targetDB bseltz-test-restore -overWrite -mdfFolder E:\sqlrestore\mdf -ldfFolder E:\sqlrestore\ldf -ndfFolders @{'*1.ndf'='E:\sqlrestore\ndf1'; '*2.ndf'='E:\sqlrestore\ndf2'}

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

### narrow the search results to the correct source server
$dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer } | Where-Object { $_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $sourceDB }

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

if($latestdb -eq $null){
    write-host "Database Not Found" -foregroundcolor yellow
    exit
}

### identify physical or vm
$entityType = $latestdb.registeredSource.type

### search for source server
$entities = api get /appEntities?appEnvType=3`&envType=$entityType
$sourceEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $sourceServer }

if($sourceEntity -eq $null){
    Write-Host "Source Server Not Found" -ForegroundColor Yellow
    exit
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
                "jobInstanceId" = $latestdb.vmDocument.versions[0].instanceId.jobInstanceId;
                "startTimeUsecs" = $latestdb.vmDocument.versions[0].instanceId.jobStartTimeUsecs;
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

### search for target server
if($targetServer){
    $targetEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $targetServer }
    if($targetEntity -eq $null){
        Write-Host "Target Server Not Found" -ForegroundColor Yellow
        exit
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

### execute the clone task (post /cloneApplication api call)
$response = api post /recoverApplication $restoreTask

if($response){
    "Restoring $sourceDB to $targetServer as $targetDB"
}
