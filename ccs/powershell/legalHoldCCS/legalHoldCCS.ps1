# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][ValidateSet('mailbox','onedrive','sharepoint')][string]$objectType = 'mailbox',
    [Parameter()][string]$date,
    [Parameter()][switch]$addHold,
    [Parameter()][switch]$removeHold,
    [Parameter()][switch]$showTrue,
    [Parameter()][switch]$showFalse,
    [Parameter()][string]$startDate,
    [Parameter()][string]$endDate,
    [Parameter()][int]$range = 4
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt # -regionid $region 

if(!$startDate){
    $startDate = dateToUsecs $date
}else{
    $startDate = dateToUsecs $startDate
}

if(! $startDate -or $startDate -eq 0){
    Write-Host "Invalid date specified. Should be in format '2025-07-09'" -ForegroundColor Yellow
    exit 1
}
if(!$endDate){
    $endDate = [int64]$startDate + 86400000000
}else{
    $endDate = dateToUsecs $endDate
}

"`nOperating on Object Type: $objectType Date: $(usecsToDate $startDate) to $(usecsToDate $endDate)`n" | Tee-Object -FilePath legalHoldLog.txt

$queryParams = @{
    "statsParams" = @{
        "attributes" = @(
            "Status";
            "ActivityType"
        )
    };
    "fromTimeUsecs" = [Int64]$startDate;
    "toTimeUsecs" = [Int64]$endDate;
    "environments" = @(
        "kO365"
    );
    "archivalRunParams" = @{
        "protectionEnvironmentTypes" = @(
            "kO365Exchange";
            "kO365ExchangeCSM"
        )
    };
    "backupRunParams" = @{
        "protectionEnvironmentTypes" = @(
            "kO365Exchange";
            "kO365ExchangeCSM"
        )
    };
    "activityTypes" = @(
        "ArchivalRun";
        "BackupRun"
    );
    "excludeStats" = $true
}

if(($endDate - $startDate) -gt ($range * 86400000000)){
    $queryParams.fromTimeUsecs = $endDate - ($range * 86400000000)    
}

if($objectType -eq 'onedrive'){
    $queryParams.archivalRunParams.protectionEnvironmentTypes = @("kO365OneDrive","kO365OneDriveCSM")
    $queryParams.backupRunParams.protectionEnvironmentTypes = @("kO365OneDrive","kO365OneDriveCSM")
}

if($objectType -eq 'sharepoint'){
    $queryParams.archivalRunParams.protectionEnvironmentTypes = @("kO365Sharepoint","kO365SharepointCSM")
    $queryParams.backupRunParams.protectionEnvironmentTypes = @("kO365Sharepoint","kO365SharepointCSM")
}

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

$totalCount = 0
$trackDupe = @()

while($True){
    $activities = api post -mcmv2 "data-protect/objects/activity?regionIds=$($regionList)" $queryParams
    $activities.activity = $activities.activity | Where-Object {$_.id -notin $trackDupe}
    $trackDupe = @()
    foreach($activity in $activities.activity | Where-Object {$_.archivalRunParams.status -ne 'Failed'}){ # Sort-Object -Property {$_.object.name}
        $totalCount += 1
        $objectId = $activity.object.id
        $trackDupe = @($trackDupe + $activity.id)
        # $startTimeUsecs = $activity.archivalRunParams.runStartTimeUsecs
        $startTimeUsecs = $activity.timeStampUsecs
        if($addHold -and $activity.archivalRunParams.onLegalHold -eq $False){
            $holdParams =  @{
                "targetObjectRuns" = @(
                    @{
                        "id" = "$objectId";
                        "runStartTimeUsecs" = $startTimeUsecs
                    }
                );
                "environment" = "kO365";
                "legalHold" = "Enable"
            }
            "Adding legal hold to $($activity.object.name) ($(usecsToDate $startTimeUsecs))" | Tee-Object -FilePath legalHoldLog.txt -Append
            $result = api put -mcmv2 "data-protect/objects/runs/metadata?regionIds=$($activity.regionId)" $holdParams
            if($result.objectRunList[0].PSObject.Properties['errorMessage']){
                Write-Host "$($result.objectRunList[0].errorMessage)" -ForegroundColor Yellow
            }
        }elseif($removeHold -and $activity.archivalRunParams.onLegalHold -eq $True){
            $holdParams =  @{
                "targetObjectRuns" = @(
                    @{
                        "id" = "$objectId";
                        "runStartTimeUsecs" = $startTimeUsecs
                    }
                );
                "environment" = "kO365";
                "legalHold" = "Release"
            }
            "Removing legal hold from $($activity.object.name) ($(usecsToDate $startTimeUsecs))" | Tee-Object -FilePath legalHoldLog.txt -Append
            $result = api put -mcmv2 "data-protect/objects/runs/metadata?regionIds=$($activity.regionId)" $holdParams
            if($result.objectRunList[0].PSObject.Properties['errorMessage']){
                Write-Host "$($result.objectRunList[0].errorMessage)" -ForegroundColor Yellow
            }
        }elseif($showTrue -or $showFalse){
            $showMe = $True
            if($showFalse -and $activity.archivalRunParams.onLegalHold -eq $True){
                $showMe = $False
            }
            if($showTrue -and $activity.archivalRunParams.onLegalHold -eq $False){
                $showMe = $False
            }
            if($showMe -eq $True){
                "$($activity.object.name) ($(usecsToDate $startTimeUsecs)) on hold = $($activity.archivalRunParams.onLegalHold)" | Tee-Object -FilePath legalHoldLog.txt -Append
            }       
        }
    }
    if(@($activities.activity).Count -gt 0 -and $queryParams.fromTimeUsecs -gt $startDate){
        $queryParams.fromTimeUsecs = $queryParams.fromTimeUsecs - ($range * 86400000000)
        if($queryParams.fromTimeUsecs -lt $startDate){
            $queryParams.fromTimeUsecs = [int64]$startDate
        }
        $queryParams.toTimeUsecs = $activities.activity[-1].timeStampUsecs
    }else{
        if(@($activities.activity).Count -lt 1000){
            break
        }else{
            $queryParams.toTimeUsecs = $activities.activity[-1].timeStampUsecs
        }
    }
}

Write-Host "Activity Count: $totalCount"