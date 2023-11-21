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
    [Parameter(Mandatory = $True)][string]$sourceDB,     # name of the source DB we want to clone
    [Parameter()][string]$targetServer = $sourceServer,  # where to attach the clone DB
    [Parameter()][string]$targetDB = $sourceDB,          # desired clone DB name
    [Parameter(Mandatory = $True)][string]$oracleHome,
    [Parameter(Mandatory = $True)][string]$oracleBase,
    [Parameter()][int]$channels = $null,                 # number of restore channels
    [Parameter()][string]$channelNode = $null,           # destination for data files
    [Parameter()][switch]$wait,    # wait for clone to finish
    [Parameter()][string]$logTime, # PIT to replay logs to e.g. '2019-01-20 02:01:47'
    [Parameter()][switch]$latest,  # replay to latest available log PIT
    [Parameter()][string]$password = $null, # optional! clear text password
    [Parameter()][array]$pfileParameterName,
    [Parameter()][array]$pfileParameterValue,
    [Parameter()][string]$preScript,
    [Parameter()][string]$preScriptArguments = '',
    [Parameter()][string]$postScript,
    [Parameter()][string]$postScriptArguments = '',
    [Parameter()][Int64]$scriptTimeout = 900,
    [Parameter()][Int64]$vlan = 0
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

### search for database to clone
$searchresults = api get "/searchvms?entityTypes=kOracle&vmName=$sourceDB"

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

### create clone task
$taskName = "Clone-Oracle_$(dateToUsecs (get-date))"

$cloneParams = @{
    "name" = "$taskName";
    "action" = "kCloneApp";
    "restoreAppParams" = @{
        "type" = 19;
        "ownerRestoreInfo" = @{
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

### configure channels
if($channels){
    if($channelNode){
        $sourceDatabase = $targetEntity.appEntity.auxChildren | Where-Object {$_.entity.displayName -eq $sourceDB}
        if($sourceDatabase){
            $uuid = $sourceDatabase[0].entity.oracleEntity.uuid
        }else{
            Write-Host "database not found on source entity" -foregroundcolor Yellow
            exit 1
        }
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
    $cloneParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams['oracleTargetParams'] = @{
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

# vlan config
if($vlan -gt 0){
    $vlanObj = api get vlans | Where-Object id -eq $vlan
    if($vlanObj){
        $cloneParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.physicalEntity['vlanParams'] = @{
            "vlanId" = $vlanObj.id;
            "interfaceName" = $vlanObj.ifaceGroupName
        }
    }else{
        Write-Host "VLAN $vlan not found" -foregroundcolor Yellow
        exit 1
    }
}

### apply log replay time
if($validLogTime -eq $True){
    $cloneParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.restoreTimeSecs = $([int64]($logUsecs/1000000))
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
        $cloneParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams['oracleDbConfig'] = @{ "pfileParameterMap" = @()}
        0..($pfileParameterName.Count - 1) | ForEach-Object {
            $cloneParams.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.oracleDbConfig.pfileParameterMap += @{
                "key" = [string]$pfileParameterName[$_];
                "value" = [string]$pfileParameterValue[$_]
            }
        }
    }
}

### handle pre script
if($preScript -or $postScript){
    $cloneParams.restoreAppParams.restoreAppObjectVec[0]['additionalParams'] = @{}
    if($preScript){
        $cloneParams.restoreAppParams.restoreAppObjectVec[0].additionalParams['preScript'] = @{
            "script" = @{
                "continueOnError" = $false;
                "scriptPath" = $preScript;
                "scriptParams" = $preScriptArguments;
                "timeoutSecs" = $scriptTimeout
            }
        }
    }
    if($postScript){
        $cloneParams.restoreAppParams.restoreAppObjectVec[0].additionalParams['postScript'] = @{
            "script" = @{
                "continueOnError" = $false;
                "scriptPath" = $postScript;
                "scriptParams" = $ostScriptArguments;
                "timeoutSecs" = $scriptTimeout
            }
        }
    }
}

### execute the clone task (post /cloneApplication api call)
# $cloneParams | ConvertTo-Json -Depth 99
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
