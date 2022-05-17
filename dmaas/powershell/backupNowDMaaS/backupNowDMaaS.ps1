# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,  # DMaaS region
    [Parameter(Mandatory = $True)][string]$objectName,
    [Parameter()][switch]$debugmode,
    [Parameter()][switch]$wait
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

$nowUsecs = dateToUsecs
$tomorrowUsecs = $nowUsecs + 86400000000
$weekAgoUsecs = timeAgo 1 week

$objects = api get -v2 "data-protect/search/objects?searchString=$objectName&includeTenants=true"
$objects = $objects.objects | Where-Object name -eq $objectName
if($objects.Count -eq 0){
    Write-Host "$objectName not found" -ForegroundColor Yellow
    exit
}

$protectedObjects = api get -v2 data-protect/search/protected-objects?objectIds=$($objects[0].objectProtectionInfos[0].objectId)
$protectedObjects = $protectedObjects.objects
if($protectedObjects.Count -eq 0){
    Write-Host "$objectName is not protected"
    exit
}

$object = api get -v2 data-protect/objects?ids=$($objects[0].objectProtectionInfos[0].objectId)

$runParams = @{
    "action" = "ProtectNow";
    "runNowParams" = @{
        "objects" = @(
            @{
                "id" = $protectedObjects[0].id;
                "takeLocalSnapshotOnly" = $false
            }
        )
    }
}

$activityParams = @{
    "statsParams" = @{
        "attributes" = @(
            "Status";
            "ActivityType"
        )
    };
    "fromTimeUsecs" = $weekAgoUsecs;
    "toTimeUsecs" = $tomorrowUsecs;
    "objectIdentifiers" = @(
        @{
            "objectId" = $protectedObjects[0].id;
            "clusterId" = $null;
            "regionId" = $region
        }
    )
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

# wait for existing run to finish
$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning')
$status = 'unknown'
$reportWaiting = $True
while($status -notin $finishedStates){
    $result = api post -mcmv2 "data-protect/objects/activity" $activityParams
    if($result.PSObject.Properties['activity'] -and $result.activity -ne $null -and $result.activity.Count -gt 0){
        if($result.activity[0].PSObject.Properties['archivalRunParams'] -and $result.activity[0].archivalRunParams.PSObject.Properties['status']){
            $status = $result.activity[0].archivalRunParams.status
            if($status -in $finishedStates){
                break
            }else{
                if($reportWaiting){
                    Write-Host "Waiting for existing run to finish"
                    $reportWaiting = $false
                }
                Start-Sleep 10
            }
        }
    }else{
        break
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
        "Running backup of $objectName"
        if($wait){
            Start-Sleep 10
            $activityParams.fromTimeUsecs = $nowUsecs
            $status = 'unknown'
            while($status -notin $finishedStates){
                $result = api post -mcmv2 "data-protect/objects/activity" $activityParams
                if($result.PSObject.Properties['activity'] -and $result.activity -ne $null -and $result.activity.Count -gt 0){
                    if($result.activity[0].PSObject.Properties['archivalRunParams'] -and $result.activity[0].archivalRunParams.PSObject.Properties['status']){
                        $status = $result.activity[0].archivalRunParams.status
                        if($status -in $finishedStates){
                            break
                        }else{
                            Start-Sleep 10
                        }
                    }
                }
            }
            Write-Host "Backup finished with status: $status"
        }
    }
}else{
    Write-Host "An unknown error occured" -ForegroundColor Yellow
}
