# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][ValidateSet('mailbox','onedrive')][string]$objectType = 'mailbox',
    [Parameter()][string]$date,
    [Parameter()][switch]$addHold,
    [Parameter()][switch]$removeHold,
    [Parameter()][switch]$showTrue,
    [Parameter()][switch]$showFalse
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt # -regionid $region 

$startDate = dateToUsecs $date

if(! $startDate -or $startDate -eq 0){
    Write-Host "Invalid date specified. Should be in format '2025-07-09'" -ForegroundColor Yellow
    exit 1
}
$endDate = $startDate + 86400000000

$queryParams = @{
    "statsParams" = @{
        "attributes" = @(
            "Status";
            "ActivityType"
        )
    };
    "fromTimeUsecs" = $startDate;
    "toTimeUsecs" = $endDate;
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

if($objectType -eq 'onedrive'){
    $queryParams.archivalRunParams.protectionEnvironmentTypes = @("kO365OneDrive","kO365OneDriveCSM")
    $queryParams.backupRunParams.protectionEnvironmentTypes = @("kO365OneDrive","kO365OneDriveCSM")
}

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

$activities = api post -mcmv2 "data-protect/objects/activity?regionIds=$($regionList)" $queryParams

foreach($activity in $activities.activity | Sort-Object -Property {$_.object.name}){
    $objectId = $activity.object.id
    $startTimeUsecs = $activity.timestampUsecs
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
        Write-Host "Adding legal hold to $($activity.object.name) ($(usecsToDate $startTimeUsecs))"
        $result = api put -mcmv2 "data-protect/objects/runs/metadata?regionIds=$($activity.regionId)" $holdParams
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
        Write-Host "Removing legal hold from $($activity.object.name) ($(usecsToDate $startTimeUsecs))"
        $result = api put -mcmv2 "data-protect/objects/runs/metadata?regionIds=$($activity.regionId)" $holdParams
    }elseif($showTrue -or $showFalse){
        $showMe = $True
        if($showFalse -and $activity.archivalRunParams.onLegalHold -eq $True){
            $showMe = $False
        }
        if($showTrue -and $activity.archivalRunParams.onLegalHold -eq $False){
            $showMe = $False
        }
        if($showMe -eq $True){
            Write-Host "$($activity.object.name) ($(usecsToDate $startTimeUsecs)) on hold = $($activity.archivalRunParams.onLegalHold)"
        }       
    }
}
