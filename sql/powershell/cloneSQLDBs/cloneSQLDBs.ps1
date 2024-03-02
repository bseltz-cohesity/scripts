# 2023-02-01

### usage: ./cloneSQL.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -sourceServer 'SQL2012' -sourceDB 'CohesityDB' [ -targetServer 'SQLDEV01' ] [ -targetDB 'CohesityDB-Dev' ] [ -targetInstance 'MSSQLSERVER' ] [ -wait ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key for authentication
    [Parameter()][string]$password,                      # optional password
    [Parameter()][switch]$noPrompt,                      # do not prompt for password
    [Parameter()][string]$tenant,                        # org to impersonate
    [Parameter()][switch]$mcm,                           # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,               # MFA code
    [Parameter()][switch]$emailMfaCode,                  # email MFA code
    [Parameter()][string]$clusterName = $null,           # helios cluster to access
    [Parameter(Mandatory = $True)][string]$sourceServer, # protection source where the DB was backed up
    [Parameter()][array]$sourceDB, # name of the source DB we want to clone
    [Parameter()][string]$sourceDBList, # text file of DB names
    [Parameter()][string]$targetServer = $sourceServer, # where to attach the clone DB
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][string]$targetInstance = 'MSSQLSERVER', # SQL instance name on the targetServer
    [Parameter()][string]$logTime, # point in time log replay like '2019-09-29 17:51:01'
    [Parameter()][switch]$latest # very latest point in time log replay
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$dbNames = @(gatherList -Param $sourceDB -FilePath $sourceDBList -Name 'jobs' -Required $True)

foreach($dbName in $dbNames){

    ### search for database to clone
    $searchresults = api get /searchvms?environment=SQL`&entityTypes=kSQL`&entityTypes=kVMware`&vmName=$dbName

    ### handle source instance name e.g. instance/dbname
    if($dbName.Contains('/')){
        $dbName = $dbName.Split('/')[1]
    }

    ### narrow the search results to the correct source server
    $dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer }
    if($null -eq $dbresults){
        write-host "Server $sourceServer Not Found" -foregroundcolor yellow
        exit
    }

    ### narrow the search results to the correct source database
    $dbresults = $dbresults | Where-Object { $_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $dbName }
    if($null -eq $dbresults){
        write-host "Database $dbName Not Found" -foregroundcolor yellow
        continue
    }

    ### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
    $latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

    if($null -eq $latestdb){
        write-host "Database $dbName Not Found" -foregroundcolor yellow
        continue
    }

    ### identify physical or vm
    $entityType = $latestdb.registeredSource.type

    ### search for source and target servers
    $entities = api get /appEntities?appEnvType=3`&envType=$entityType
    $ownerId = $latestdb.vmDocument.objectId.entity.sqlEntity.ownerId
    $targetEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $targetServer }

    if($null -eq $targetEntity){
        Write-Host "Target Server $targetServer Not Found" -ForegroundColor Yellow
        exit
    }

    ### handle log replay
    $versionNum = 0
    $validLogTime = $False

    if ($logTime -or $latest) {
        if($logTime){
            $logUsecs = dateToUsecs $logTime
        }
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
                                'newDatabaseName'                 = $dbName;
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
                        'attemptNum' = $version.instanceId.attemptNum;
                        'jobUid'         = $latestdb.vmDocument.objectId.jobUid;
                        'jobId'          = $latestdb.vmDocument.objectId.jobId;
                        'jobInstanceId'  = $version.instanceId.jobInstanceId;
                        'startTimeUsecs' = $version.instanceId.jobStartTimeUsecs;
                        "entity" = @{
                            "id" = $ownerId
                        };
                    }
                )
            }
            $logTimeRange = api post /restoreApp/timeRanges $GetRestoreAppTimeRangesArg
            if($latest){
                if(! $logTimeRange.ownerObjectTimeRangeInfoVec[0].PSobject.Properties['timeRangeVec']){
                    $logTime = $null
                    $latest = $null
                    break
                }
            }
            $logStart = $logTimeRange.ownerObjectTimeRangeInfoVec[0].timeRangeVec[0].startTimeUsecs
            $logEnd = $logTimeRange.ownerObjectTimeRangeInfoVec[0].timeRangeVec[0].endTimeUsecs
            if($latest){
                $logUsecs = $logEnd - 1000000
                $validLogTime = $True
                break
            }
            if ($logStart -le $logUsecs -and $logUsecs -le $logEnd) {
                $validLogTime = $True
                break
            }
            $versionNum += 1
        }
    }

    $taskName = "CloneSQL-$($targetServer)-$($targetInstance)-{0}{1}{2}" -f $prefix, $dbName, $suffix

    ### create new clone task (RestoreAppArg Object)
    $cloneTask = @{
        "name" = $taskName;
        "action" = "kCloneApp";
        "restoreAppParams" = @{
            "type" = 3;
            "ownerRestoreInfo" = @{
                "ownerObject" = @{
                    "attemptNum" = $latestdb.vmDocument.versions[0].instanceId.attemptNum;
                    "jobUid" = $latestdb.vmDocument.objectId.jobUid;
                    "jobId" = $latestdb.vmDocument.objectId.jobId;
                    "jobInstanceId" = $latestdb.vmDocument.versions[0].instanceId.jobInstanceId;
                    "startTimeUsecs" = $latestdb.vmDocument.versions[0].instanceId.jobStartTimeUsecs;
                    "entity" = @{
                        "id" = $ownerId
                    }
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
                            "newDatabaseName" = "{0}{1}{2}" -f $prefix, $dbName, $suffix;
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

    ### apply log replay time
    if($validLogTime -eq $True){
        $cloneTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['restoreTimeSecs'] = $([int64]($logUsecs/1000000))
    }else{
        if($logTime){
            Write-Host "LogTime of $logTime is out of range" -ForegroundColor Yellow
            Write-Host "Available range is $(usecsToDate $logStart) to $(usecsToDate $logEnd)" -ForegroundColor Yellow
            continue
        }
    }
    ### execute the clone task (post /cloneApplication api call)
    $response = api post /cloneApplication $cloneTask

    if($response){
        $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
        "Cloning $dbName to $targetServer as $targetDB (task name: $taskName)"
    }else{
        Write-Warning "No Response"
        continue
    }

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
