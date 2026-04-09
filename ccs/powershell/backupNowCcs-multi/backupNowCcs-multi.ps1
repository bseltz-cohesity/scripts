# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter(Mandatory = $True)][string]$region,  # DMaaS region
    [Parameter()][array]$objectName,
    [Parameter()][string]$objectList,
    [Parameter()][switch]$fullBackup,
    [Parameter()][switch]$debugmode,
    [Parameter()][switch]$wait,
    [Parameter()][int]$sleepTime = 60
)

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

$objectNames = @(gatherList -Param $objectName -FilePath $objectList -Name 'objects' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt -regionid $region

$nowUsecs = dateToUsecs
$tomorrowUsecs = $nowUsecs + 86400000000
$weekAgoUsecs = timeAgo 1 week

$selectedObjects = @()

foreach($objectName in $objectNames){
    $objectName = [string]$objectName
    $objects = api get -v2 "data-protect/search/objects?searchString=$objectName&includeTenants=true"
    $objects = $objects.objects | Where-Object name -eq $objectName
    if($objects.Count -eq 0){
        Write-Host "$objectName not found" -ForegroundColor Yellow
        continue
    }
    
    $protectedObjects = api get -v2 data-protect/search/protected-objects?objectIds=$($objects[0].objectProtectionInfos[0].objectId)
    $protectedObjects = $protectedObjects.objects
    if($protectedObjects.Count -eq 0){
        Write-Host "$objectName is not protected" -ForegroundColor Yellow
        continue
    }
    
    $object = api get -v2 data-protect/objects?ids=$($objects[0].objectProtectionInfos[0].objectId)
    $thisSelectedObject = @{
        "id" = $protectedObjects[0].id;
        "takeLocalSnapshotOnly" = $false
    }
    if($fullBackup){
        $thisSelectedObject['backupType'] = 'kFull'
    }
    $selectedObjects = @($selectedObjects + $thisSelectedObject)
    Write-Host "Backing up $objectName"
}

$runParams = @{
    "action" = "ProtectNow";
    "runNowParams" = @{
        "objects" = $selectedObjects
    }
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

$result = api post -v2 data-protect/protected-objects/actions $runParams

if($debugmode){
    $result | ConvertTo-Json -Depth 99
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
    );
    "fromTimeUsecs" = $weekAgoUsecs;
    "toTimeUsecs" = $tomorrowUsecs
}

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning')
$reportedObjects = @()

if($result -and $result.PSObject.Properties['objects'] -and $result.objects.Count -gt 0){
    if($result.objects[0].PSObject.Properties['runNowStatus'] -and $result.objects[0].runNowStatus.PSObject.Properties['error']){
        $error = $result.objects[0].runNowStatus.error
        if($error.PSObject.Properties['message']){
            Write-Host $error.message -ForegroundColor Yellow
        }
    }else{
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
                                # "$($act.object.name): $status"
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
                        if($allFinished -eq $True){
                            if($act.object.name -notin $reportedObjects){
                                Write-Host "$($act.object.name) backup finished with status: $worstStatus"
                                $reportedObjects = @($reportedObjects + $($act.object.name))
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
        }
    }
}else{
    Write-Host "An unknown error occured" -ForegroundColor Yellow
}
