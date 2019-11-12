### usage: ./cloneOracle.ps1 -vip mycluster -username myusername -domain mydomain.net `
#                            -sourceServer oracle.mydomain.net -sourceDB cohesity `
#                            -targetServer oracle2.mydomain.net -targetDB clonedb `
#                            -oracleHome /home/oracle/app/oracle/product/11.2.0/dbhome_1 ` 
#                            -oracleBase /home/oracle/app/oracle

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$sourceServer, # protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$sourceDB, # name of the source DB we want to clone
    [Parameter()][string]$targetServer = $sourceServer, # where to attach the clone DB
    [Parameter()][string]$targetDB = $sourceDB, # desired clone DB name
    [Parameter(Mandatory = $True)][string]$oracleHome,
    [Parameter(Mandatory = $True)][string]$oracleBase,
    [Parameter()][switch]$wait, # wait for clone to finish
    [Parameter()][string]$password = $null # optional! clear text password
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

### search for database to clone
$searchresults = api get "/searchvms?entityTypes=kSQL&entityTypes=kOracle&showAll=false&onlyLatestVersion=true&vmName=$sourceDB"

### narrow the search results to the correct source server
$dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer }
if($null -eq $dbresults){
    write-host "Server $sourceServer Not Found" -foregroundcolor yellow
    exit
}

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

if($null -eq $latestdb){
    write-host "Database Not Found" -foregroundcolor yellow
    exit
}

### find target server
$targetEntity = api get /appEntities?appEnvType=19 | Where-Object { $_.appEntity.entity.displayName -eq $targetServer }
if($null -eq $targetEntity){
    Write-Host "Target Server Not Found" -ForegroundColor Yellow
    exit
}

### version
$version = $latestdb.vmDocument.versions[0]

### create clone task
$taskName = "Clone-Oracle_$(dateToUsecs (get-date))"

$cloneParams = @{
    "name" = "$taskName";
    "action" = "kCloneApp";
    "restoreAppParams" = @{
        "type" = 19;
        "ownerRestoreInfo" = @{
            "ownerObject" = @{
                "jobUid" = $latestdb.vmDocument.objectId.jobUid;
                "jobId" = $latestdb.vmDocument.objectId.jobId;
                "jobInstanceId" = $version.instanceId.jobInstanceId;
                "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                "entity" = @{
                    "id" = $latestdb.vmDocument.objectId.entity.parentId
                }
            };
            "ownerRestoreParams" = @{
                "action" = "kCloneVMs";
                "powerStateConfig" = @{}
            };
            "performRestore" = $false
        };
        "restoreAppObjectVec" = @(
            @{
                "appEntity" = $latestdb.vmDocument.objectId.entity;
                "restoreParams" = @{
                    "oracleRestoreParams" = @{
                        "alternateLocationParams" = @{
                            "newDatabaseName" = $targetDB;
                            "homeDir" = $oracleHome;
                            "baseDir" = $oracleBase
                        };
                        "captureTailLogs" = $false;
                        "secondaryDataFileDestinationVec" = @(
                            @{}
                        )
                    };
                    "targetHost" = $targetEntity[0].appEntity.entity;
                    "targetHostParentSource" = @{
                        "id" = $targetEntity[0].appEntity.entity.id
                    }
                }
            }
        )
    }
}

### execute the clone task (post /cloneApplication api call)
$response = api post /cloneApplication $cloneParams

if($response){
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    "Cloning $sourceDB to $targetServer as $targetDB (task name: $taskName)"
}else{
    Write-Warning "No Response"
    exit(1)
}

if($wait){
    $status = 'started'
    $finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
    while($status -ne 'completed'){
        $task = api get "/restoretasks/$($taskId)"
        $publicStatus = $task.restoreTask.performRestoreTaskState.base.publicStatus
        if($publicStatus -in $finishedStates){
            $status = 'completed'
        }else{
            sleep 3
        }
    }
    write-host "Clone task completed with status: $publicStatus"
    if($publicStatus -eq 'kFailure'){
        write-host "Error Message: $($task.restoreTask.performRestoreTaskState.base.error.errorMsg)"
    }
}
