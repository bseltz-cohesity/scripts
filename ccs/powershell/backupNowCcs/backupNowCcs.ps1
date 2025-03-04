# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt, # [Parameter(Mandatory = $True)][string]$region,  # DMaaS region
    [Parameter()][string]$objectName,
    [Parameter()][string]$sourceName,
    [Parameter()][string]$region,
    [Parameter()][switch]$debugmode,
    [Parameter()][switch]$wait,
    [Parameter()][int]$sleepTime = 60,
    [Parameter()][ValidateSet('kRegular','kFull','kLog')][string]$backupType = 'kRegular',
    [Parameter()][switch]$abortIfRunning
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt # -regionid $region 

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

$nowUsecs = dateToUsecs
$tomorrowUsecs = $nowUsecs + 86400000000
$weekAgoUsecs = timeAgo 1 day

$runParams = @{
    "action" = "ProtectNow";
    "runNowParams" = @{
        "objects" = @()
    }
}

if($objectName){
    if($region){
        $objects = api get -v2 "data-protect/search/objects?searchString=$objectName&includeTenants=true&regionIds=$region"
    }else{
        $objects = api get -v2 "data-protect/search/objects?searchString=$objectName&includeTenants=true&regionIds=$regionList"
    }
    $objects = $objects.objects | Where-Object {$_.name -eq $objectName}
    if($sourceName){
        $objects = $objects | Where-Object {$_.sourceInfo.name -eq $sourceName}
    }
    if($objects.Count -eq 0){
        Write-Host "$objectName not found" -ForegroundColor Yellow
        exit
    }
    foreach($obj in $objects){
        foreach($objectProtectionInfo in $obj.objectProtectionInfos | Where-Object {$_.objectBackupConfiguration -ne $null}){
            $protectedObjectId = $objectProtectionInfo.objectId
            $runParams['runNowParams']['objects'] = @($runParams['runNowParams']['objects'] + @{
                "id" = $protectedObjectId;
                "takeLocalSnapshotOnly" = $false;
                "backupType" = $backupType
            })
            $regionId = $objectProtectionInfo.regionId
            $object = api get -v2 "data-protect/objects?ids=$protectedObjectId&regionId=$regionId"
            break
        }
    }
}elseif($sourceName){
    if($region){
        $sources = api get -mcmv2 "data-protect/sources?regionIds=$region"
    }else{
        $sources = api get -mcmv2 "data-protect/sources?regionIds=$regionList"
    }
    $source = $sources.sources | Where-Object name -eq $sourceName
    if(!$source){
        Write-Host "$sourceName not found" -ForegroundColor Yellow
        exit
    }
    $regionId = $source.sourceInfoList[0].regionId
    $protectedObjects = api get -v2 "data-protect/objects?parentId=$($source.sourceInfoList[0].sourceId)&onlyProtectedObjects=true&onlyAutoProtectedObjects=false&regionId=$regionId"
    $protectedObjects = $protectedObjects.objects | Where-Object {$_.name -eq $sourceName}
    if($protectedObjects.Count -eq 0){
        Write-Host "$sourceName is not protected"
        exit
    }
    foreach($obj in $protectedObjects){
        $runParams['runNowParams']['objects'] = @($runParams['runNowParams']['objects'] + @{
            "id" = $obj.id;
            "takeLocalSnapshotOnly" = $false;
            "backupType" = $backupType
        })
        $object = api get -v2 "data-protect/objects?ids=$($obj.id)&regionId=$regionId"
        break
    }
}else{
    Write-Host "-objectName or -sourceName required" -ForegroundColor Yellow
}

# handle multiple protections
$policies = $object.objects[0].objectBackupConfiguration.policyConfig.policies
if($policies.Count -gt 1){
    $runParams['snapshotBackendTypes'] = @()
    foreach($protectionType in $policies.protectionType){
        if($object.objects[0].environment -eq 'kAWS'){
            if($protectionType -eq 'kNative'){
                $protectionType = 'kAWSNative'
            }
            if($protectionType -eq 'kSnapshotManager'){
                $protectionType = 'kAWSSnapshotManager'
            }
        }
        $runParams['snapshotBackendTypes'] = @($runParams['snapshotBackendTypes'] + $protectionType)
    }
}

$activityParams = @{
    "statsParams" = @{
        "attributes" = @(
            "Status";
            "ActivityType"
        )
    };
    "activityTypes" = @(
        "ArchivalRun";
        "BackupRun"
    )
    "fromTimeUsecs" = $weekAgoUsecs;
    "toTimeUsecs" = $tomorrowUsecs
}

# wait for existing run to finish
$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning')
$allFinished = $false
$reportWaiting = $True
while($allFinished -eq $false){
    $allFinished = $True
    $result = api post -mcmv2 "data-protect/objects/activity?regionId=$regionId" $activityParams
    if($result.PSObject.Properties['activity'] -and $result.activity -ne $null -and $result.activity.Count -gt 0){
        foreach($protectedObject in $runParams['runNowParams']['objects']){
            $protectedObjectId = $protectedObject.id
            $activities = $result.activity | Where-Object {$_.object.id -eq $protectedObjectId -or $_.sourceInfo.id -eq $protectedObjectId}
            foreach($act in $activities){
                if($act.PSObject.Properties['archivalRunParams'] -and $act.archivalRunParams.PSObject.Properties['status']){
                    $status = $act.archivalRunParams.status
                    if($status -notin $finishedStates){
                        if($abortIfRunning){
                            Write-Host "Backup already in progress"
                            exit
                        }
                        $allFinished = $false
                        if($reportWaiting){
                            Write-Host "Waiting for existing run to finish"
                            $reportWaiting = $false
                        }
                    }
                }
            }
        }
        if($allFinished -eq $True){
            break
        }
        Start-Sleep $sleepTime
    }else{
        $allFinished = $false
    }
}

$result = api post -v2 "data-protect/protected-objects/actions?regionId=$regionId" $runParams

if($debugmode){
    $result | ConvertTo-Json -Depth 99
}

if($result -and $result.PSObject.Properties['objects'] -and $result.objects.Count -gt 0){
    if($result.objects[0].PSObject.Properties['runNowStatus'] -and $result.objects[0].runNowStatus.PSObject.Properties['error']){
        $error = $result.objects[0].runNowStatus.error
        if($error.PSObject.Properties['message']){
            Write-Host $error.message -ForegroundColor Yellow
        }
    }else{
        if($objectName){
            "Running backup of $objectName"
        }else{
            "Running backup of $sourceName"
        }
        if($wait){
            Start-Sleep $sleepTime
            $activityParams.fromTimeUsecs = $nowUsecs
            $status = 'unknown'
            $allFinished = $false
            $worstStatus = 'Succeeded'
            while($allFinished -eq $false){
                $allFinished = $True
                $result = api post -mcmv2 "data-protect/objects/activity?regionId=$regionId" $activityParams
                if($result.PSObject.Properties['activity'] -and $result.activity -ne $null -and $result.activity.Count -gt 0){
                    foreach($protectedObject in $runParams['runNowParams']['objects']){
                        $protectedObjectId = $protectedObject.id
                        $activities = $result.activity | Where-Object {$_.object.id -eq $protectedObjectId -or $_.sourceInfo.id -eq $protectedObjectId}
                        foreach($act in $activities){
                            if($act.PSObject.Properties['archivalRunParams'] -and $act.archivalRunParams.PSObject.Properties['status']){
                                $status = $act.archivalRunParams.status
                                if($status -eq 'Failed'){
                                    $worstStatus = 'Failed'
                                }
                                if($worstStatus -ne 'Failed' -and $status -eq 'Canceled'){
                                    $worstStatus = 'Cenceled'
                                }
                                if($worstStatus -ne 'Failed' -and $worstStatus -ne 'Canceled' -and $status -eq 'SucceededWithWarning'){
                                    $worstStatus = 'SucceededWithWarning'
                                }
                                if($status -notin $finishedStates){
                                    $allFinished = $false
                                }
                            }
                        }
                    }
                    if($allFinished -eq $True){
                        break
                    }
                    Start-Sleep $sleepTime
                }else{
                    $allFinished = $false
                }
            }
            Write-Host "Backup finished with status: $worstStatus"
        }
    }
}else{
    Write-Host "An unknown error occured" -ForegroundColor Yellow
}
