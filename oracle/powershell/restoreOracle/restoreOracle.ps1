### usage: ./restoreOracle.ps1 -vip mycluster -username myusername -domain mydomain.net `
#                              -sourceServer oracle.mydomain.net -sourceDB cohesity `
#                              -targetServer oracle2.mydomain.net -targetDB testdb `
#                              -oracleHome /home/oracle/app/oracle/product/11.2.0/dbhome_1 `
#                              -oracleBase /home/oracle/app/oracle `
#                              -oracleData /home/oracle/app/oracle/oradata/testdb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,          # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,     # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key authentication
    [Parameter(Mandatory = $True)][string]$sourceServer, # protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$sourceDB,     # name of the source DB we want to clone
    [Parameter()][string]$targetServer = $sourceServer,  # where to attach the clone DB
    [Parameter()][string]$targetDB = $sourceDB,          # desired clone DB name
    [Parameter()][string]$oracleHome = $null,            # oracle home location
    [Parameter()][string]$oracleBase = $null,            # oracle base location
    [Parameter()][string]$oracleData = $null,            # destination for data files
    [Parameter()][int]$channels = $null,                 # number of restore channels
    [Parameter()][string]$channelNode = $null,           # destination for data files
    [Parameter()][array]$controlfile,                    # alternate ctl file path
    [Parameter()][array]$redologpath,                    # alternate redo log path
    [Parameter()][string]$auditpath = $null,             # alternate audit path
    [Parameter()][string]$diagpath = $null,              # alternate diag path
    [Parameter()][string]$frapath = $null,               # alternate fra path
    [Parameter()][int]$frasizeMB = $null,                # alternate fra path
    [Parameter()][string]$bctfile = $null,               # alternate bct file path
    [Parameter()][switch]$wait,                          # wait for restore to finish
    [Parameter()][switch]$progress,                      # display progress
    [Parameter()][string]$logTime,                       # PIT to replay logs to e.g. '2019-01-20 02:01:47'
    [Parameter()][switch]$latest,                        # replay to latest available log PIT
    [Parameter()][switch]$noRecovery,                    # leave the restored DB in noRecovery mode
    [Parameter()][switch]$overWrite,                     # overwrite existing DB
    [Parameter()][string]$password = $null,              # optional! clear text password
    [Parameter()][array]$pfileParameterName,
    [Parameter()][array]$pfileParameterValue
)

### validate arguments
if($targetServer -ne $sourceServer -or $targetDB -ne $sourceDB){
    if($oracleHome -eq $null -or $oracleBase -eq $null -or $oracleData -eq $null){
        Write-Warning "-oracleHome, -oracleBase, and -oracleData are required when restoring to another server/database"
        exit
    }
}

### overwrite warning
if($targetDB -eq $sourceDB -and $targetServer -eq $sourceServer){
    if(! $overWrite){
        write-host "Please use the -overWrite parameter to confirm overwrite of the source database!" -ForegroundColor Yellow
        exit 1
    }
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

### search for database to clone
$searchresults = api get "/searchvms?entityTypes=kOracle&vmName=$sourceDB"

### narrow the search results to the correct source server
$dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer }
if($null -eq $dbresults){
    write-host "Server $sourceServer Not Found" -foregroundcolor yellow
    exit 1
}

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

if($null -eq $latestdb){
    write-host "Database Not Found" -foregroundcolor yellow
    exit 1
}

### find target server
$targetEntity = api get /appEntities?appEnvType=19 | Where-Object { $_.appEntity.entity.displayName -eq $targetServer }
if($null -eq $targetEntity){
    Write-Host "Target Server Not Found" -ForegroundColor Yellow
    exit 1
}

### version
$version = $latestdb.vmDocument.versions[0]
$ownerId = $latestdb.vmDocument.objectId.entity.oracleEntity.ownerId

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
            "type"                = 19;
            "restoreAppObjectVec" = @(
                @{
                    "appEntity"     = $latestdb.vmDocument.objectId.entity; ;
                    "restoreParams" = @{
                        "sqlRestoreParams"    = @{
                            "captureTailLogs" = $true
                        };
                        "oracleRestoreParams" = @{
                            "alternateLocationParams"         = @{
                                "oracleDBConfig" = @{
                                    "controlFilePathVec"   = @();
                                    "enableArchiveLogMode" = $true;
                                    "redoLogConf"          = @{
                                        "groupMemberVec" = @();
                                        "memberPrefix"   = "redo";
                                        "sizeMb"         = 20
                                    };
                                    "fraSizeMb"            = 2048
                                }
                            };
                            "captureTailLogs"                 = $false;
                            "secondaryDataFileDestinationVec" = @(
                                @{ }
                            )
                        }
                    }
                }
            );
            "ownerObjectVec"      = @(
                @{
                    'jobUid'         = $latestdb.vmDocument.objectId.jobUid;
                    'jobId'          = $latestdb.vmDocument.objectId.jobId;
                    'jobInstanceId'  = $version.instanceId.jobInstanceId;
                    'startTimeUsecs' = $version.instanceId.jobStartTimeUsecs;
                    "entity"         = @{
                        "id" = $ownerId
                    }
                    'attemptNum'     = $version.instanceId.attemptNum
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

        if($logTimeRange.ownerObjectTimeRangeInfoVec[0].PSobject.Properties['timeRangeVec']){
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
        }

        $versionNum += 1
    }
}



### create restore task
$taskName = "Restore-Oracle_$(dateToUsecs (get-date))"

$restoreParams = @{
    "name"             = $taskName;
    "action"           = "kRecoverApp";
    "restoreAppParams" = @{
        "type"                = 19;
        "ownerRestoreInfo"    = @{
            "ownerObject" = @{
                "attemptNum" = $version.instanceId.attemptNum;
                "jobUid" = $latestdb.vmDocument.objectId.jobUid;
                "jobId" = $latestdb.vmDocument.objectId.jobId;
                "jobInstanceId" = $version.instanceId.jobInstanceId;
                "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                "entity" = @{
                    "id" = $latestdb.vmDocument.objectId.entity.parentId
                }
            };
            "ownerRestoreParams" = @{
                "action"           = "kRecoverVMs";
                "powerStateConfig" = @{ }
            };
            "performRestore"     = $false
        };
        "restoreAppObjectVec" = @(
            @{
                "appEntity"     = $latestdb.vmDocument.objectId.entity;
                "restoreParams" = @{
                    "oracleRestoreParams"    = @{
                        "captureTailLogs"                 = $false;
                        "secondaryDataFileDestinationVec" = @(
                            @{ }
                        )
                    }
                }
            }
        )
    }
}

# allow cloudRetrieve
$localreplica = $version.replicaInfo.replicaVec | Where-Object {$_.target.type -eq 1}
$archivereplica = $version.replicaInfo.replicaVec | Where-Object {$_.target.type -eq 3}

if(! $localreplica -and $archivereplica){
    $restoreParams.restoreAppParams.ownerRestoreInfo.ownerObject['archivalTarget'] = $archivereplica[0].target.archivalTarget
}

### configure channels
if($channels){
    if($channelNode){
        $uuid = $latestdb.vmDocument.objectId.entity.oracleEntity.uuid
        $endpoints = $targetEntity.appEntity.entity.physicalEntity.networkingInfo.resourceVec | Where-Object {$_.type -eq 0}
        foreach($endpoint in $endpoints){
            $preferredEndPoint = $endpoint.endpointVec | Where-Object isPreferredEndpoint -eq $true
            if($preferredEndPoint.fqdn -eq $channelNode -or $preferredEndPoint.ipv4Addr -eq $channelNode){
                $channelNodeObj = $preferredEndPoint
            }
        }
        if($channelNodeObj){
            $channelNodeAgent = $targetEntity.appEntity.entity.physicalEntity.agentStatusVec | Where-Object {$_.displayName -eq $channelNodeObj.fqdn -or $_.displayName -eq $channelNodeObj.ipv4Addr}
            if($channelNodeAgent){
                $channelNodeId = $channelNodeAgent[0].id
            }else{
                Write-Host "Channel Node $channelNode not found" -foregroundcolor Yellow
                exit 1
            }
        }else{
            Write-Host "Channel Node $channelNode not found" -foregroundcolor Yellow
            exit 1
        }
    }else{
        $channelNodeId = $targetServer
        $uuid = $latestdb.vmDocument.objectId.entity.oracleEntity.uuid
    }
    $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams['oracleTargetParams'] = @{
        "additionalOracleDbParamsVec" = @(
            @{
                "appEntityId"      = $latestdb.vmDocument.objectId.entity.id;
                "dbInfoChannelVec" = @(
                    @{
                        "hostInfoVec" = @(
                            @{
                                "host"        = [string]$channelNodeId;
                                "numChannels" = $channels;
                            }
                        );
                        "dbUuid"      = $uuid
                    }
                )
            }
        )
    }
}

### alternate location params
if($targetServer -ne $sourceServer -or $targetDB -ne $sourceDB){
    $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams = @{
        "newDatabaseName"         = $targetDB;
        "homeDir"                 = $oracleHome;
        "baseDir"                 = $oracleBase;
        "oracleDBConfig"          = @{
            "controlFilePathVec"   = @();
            "enableArchiveLogMode" = $true;
            "redoLogConf"          = @{
                "groupMemberVec" = @();
                "memberPrefix"   = "redo";
                "sizeMb"         = 20
            };
            "fraSizeMb"            = 2048
        };
        "databaseFileDestination" = $oracleData
    }
    $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost = $targetEntity[0].appEntity.entity;
    if($controlfile){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig['controlFilePathVec'] = $controlfile
    }
    if($redologpath){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig.redoLogConf['groupMemberVec'] = $redologpath
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig.redoLogConf['numGroups'] = $redologpath.Length
    }
    if($frasizeMB){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig['fraSizeMb'] = $frasizeMB
    }
    if($bctfile){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig['bctFilePath'] = $bctfile
    }
    if($auditpath){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig['auditLogDest'] = $auditpath
    }
    if($diagpath){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig['diagDest'] = $diagpath
    }
    if($frapath){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDBConfig['fraDest'] = $frapath
    }
}

### apply log replay time
if($validLogTime -eq $True){
    $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.restoreTimeSecs = $([int64]($logUsecs/1000000))
}else{
    if($logTime){
        Write-Host "LogTime of $logTime is out of range" -ForegroundColor Yellow
        Write-Host "Available range is $(usecsToDate $logStart) to $(usecsToDate $logEnd)" -ForegroundColor Yellow
        exit 1
    }
}

### handle pfile parameters
if($pfileParameterName.Count -ne $pfileParameterValue.Count){
    Write-Host "Number of pfile parameter names and values do not match" -ForegroundColor Yellow
    exit 1
}else{
    if($pfileParameterName.Count -gt 0){
        $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams['oracleDbConfig'] = @{ "pfileParameterMap" = @()}
        0..($pfileParameterName.Count - 1) | ForEach-Object {
            $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDbConfig.pfileParameterMap += @{
                "key" = [string]$pfileParameterName[$_];
                "value" = [string]$pfileParameterValue[$_]
            }
        }
    }
}

### no recovery mode
if($noRecovery){
    $restoreParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.noOpenMode = $True
}

### perform restore
$response = api post /recoverApplication $restoreParams

if($response){
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    "Restoring $sourceDB to $targetServer as $targetDB (task name: $taskName)"
}else{
    Write-Warning "No Response"
    exit 1
}

if($wait -or $progress){
    $lastProgress = -1
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    $finishedStates = @('kSuccess','kFailed','kCanceled', 'kFailure')
    $status = (api get /restoretasks/$taskId).restoreTask.performRestoreTaskState.base.publicStatus
    while($status -notin $finishedStates){
        sleep 10
        if($progress){
            $progressMonitor = api get "/progressMonitors?taskPathVec=restore_sql_$($taskId)&includeFinishedTasks=true&excludeSubTasks=false"
            $percentComplete = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
            if($percentComplete -gt $lastProgress){
                "{0} percent complete" -f [math]::Round($percentComplete, 0)
                $lastProgress = $percentComplete
            }
        }
        $status = (api get /restoretasks/$taskId).restoreTask.performRestoreTaskState.base.publicStatus
    }
    "Restore ended with status $status"
    if($status -eq 'kSuccess'){
        exit 0
    }else{
        exit 1
    }
    exit 1
}else{
    exit 0
}
