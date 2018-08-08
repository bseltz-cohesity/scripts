### usage: ./sqlClone.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -sourceServer 'SQL2012' -sourceDB 'CohesityDB' [ -targetServer 'SQLDEV01' ] [ -targetDB 'CohesityDB-Dev' ] [ -targetInstance 'MSSQLSERVER' ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$sourceServer, #protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$sourceDB, #name of the source DB we want to clone
    [Parameter()][string]$targetServer = $sourceServer, #where to attach the clone DB
    [Parameter()][string]$targetDB = $sourceDB, #desired clone DB name
    [Parameter()][string]$targetInstance = 'MSSQLSERVER' #SQL instance name on the targetServer
)

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

### search for source and target servers
$entities = api get /appEntities?appEnvType=3`&envType=$entityType
$sourceEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $sourceServer }
$targetEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $targetServer }

if($sourceEntity -eq $null){
    Write-Host "Source Server Not Found" -ForegroundColor Yellow
    exit
}

if($targetEntity -eq $null){
    Write-Host "Target Server Not Found" -ForegroundColor Yellow
    exit
}

### create new clone task (RestoreAppArg Object)
$cloneTask = @{
    "name" = "dbClone-$(dateToUsecs (get-date))";
    "action" = "kCloneApp";
    "restoreAppParams" = @{
        "type" = 3;
        "ownerRestoreInfo" = @{
            "ownerObject" = @{
                "jobUid" = $latestdb.vmDocument.objectId.jobUid;
                "jobId" = $latestdb.vmDocument.objectId.jobId;
                "jobInstanceId" = $latestdb.vmDocument.versions[0].instanceId.jobInstanceId;
                "startTimeUsecs" = $latestdb.vmDocument.versions[0].instanceId.jobStartTimeUsecs;
                "entity" = $sourceEntity.appEntity.entity;
            }
            "ownerRestoreParams" = @{
                "action" = "kCloneVMs";
                "powerStateConfig" = @{}
            };
            "performRestore" = $false
        }
        "restoreAppObjectVec" = @(
            @{
                "appEntity" = $latestdb.vmDocument.objectId.entity;
                "restoreParams" = @{
                    "sqlRestoreParams" = @{
                        "captureTailLogs" = $false;
                        "instanceName" = $targetInstance;
                        "newDatabaseName" = $targetDB;
                    }
                    'targetHost' = $targetEntity.appEntity.entity;
                    'targetHostParentSource' = @{
                        'id' = $targetEntity.appEntity.entity.parentId;
                    }
                }
            }
        )
    }
}

### execute the clone task (post /cloneApplication api call)
$response = api post /cloneApplication $cloneTask

if($response){
    "Cloning $sourceDB to $targetServer as $targetDB"
}
