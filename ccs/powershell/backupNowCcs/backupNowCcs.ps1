# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter(Mandatory = $True)][string]$region,  # Ccs region
    [Parameter()][string]$objectName,
    [Parameter()][string]$sourceName,
    [Parameter()][switch]$debugmode,
    [Parameter()][switch]$wait,
    [Parameter()][int]$sleepTime = 60
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

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
    $objects = api get -v2 "data-protect/search/objects?searchString=$objectName&includeTenants=true"
    $objects = $objects.objects | Where-Object {$_.name -eq $objectName}
    if($sourceName){
        $objects = $objects | Where-Object {$_.sourceInfo.name -eq $sourceName}
    }
    
    if($objects.Count -eq 0){
        Write-Host "$objectName not found" -ForegroundColor Yellow
        exit
    }
    foreach($obj in $objects){
        $protectedObjectId = $obj.objectProtectionInfos[0].objectId
        $runParams['runNowParams']['objects'] = @($runParams['runNowParams']['objects'] + @{
            "id" = $protectedObjectId;
            "takeLocalSnapshotOnly" = $false
        })
        $object = api get -v2 data-protect/objects?ids=$protectedObjectId
    }    
    $object = api get -v2 data-protect/objects?ids=$($objects[0].objectProtectionInfos[0].objectId)

}elseif($sourceName){
    $sources = api get -mcmv2 "data-protect/sources"
    $source = $sources.sources | Where-Object name -eq $sourceName
    if(!$source){
        Write-Host "$sourceName not found" -ForegroundColor Yellow
        exit
    }
    $protectedObjects = api get -v2 "data-protect/objects?parentId=$($source.sourceInfoList[0].sourceId)&onlyProtectedObjects=true&onlyAutoProtectedObjects=false"
    $protectedObjects = $protectedObjects.objects
    if($protectedObjects.Count -eq 0){
        Write-Host "$sourceName is not protected"
        exit
    }
    foreach($obj in $protectedObjects){
        $runParams['runNowParams']['objects'] = @($runParams['runNowParams']['objects'] + @{
            "id" = $obj.id;
            "takeLocalSnapshotOnly" = $false
        })
        $object = api get -v2 data-protect/objects?ids=$($obj.id)
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
    $result = api post -mcmv2 "data-protect/objects/activity" $activityParams
    if($result.PSObject.Properties['activity'] -and $result.activity -ne $null -and $result.activity.Count -gt 0){
        foreach($protectedObject in $runParams['runNowParams']['objects']){
            $protectedObjectId = $protectedObject.id
            $activities = $result.activity | Where-Object {$_.object.id -eq $protectedObjectId -or $_.sourceInfo.id -eq $protectedObjectId}
            foreach($act in $activities){
                if($act.PSObject.Properties['archivalRunParams'] -and $act.archivalRunParams.PSObject.Properties['status']){
                    $status = $act.archivalRunParams.status
                    if($status -notin $finishedStates){
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

$result = api post -v2 data-protect/protected-objects/actions $runParams

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
                $result = api post -mcmv2 "data-protect/objects/activity" $activityParams
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
