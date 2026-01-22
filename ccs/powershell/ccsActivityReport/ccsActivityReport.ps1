# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][int]$days = 2,
    [Parameter()][int]$pageSize = 500,
    [Parameter()][switch]$skipSuccess
)

$version = '2026-01-22'

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt

# date range
$midnight = Get-Date -Hour 0 -Minute 0
$midnightUsecs = dateToUsecs $midnight
$uEnd = $midnightUsecs + 86399000000
$uStart = $midnightUsecs - ($days * 86400000000) + 86400000000
# $start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
# $end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

$queryParams = @{
    "statsParams" = @{
        "attributes" = @(
            "Status";
            "ActivityType"
        )
    };
    "fromTimeUsecs" = [Int64]$uStart;
    "toTimeUsecs" = [Int64]$uEnd;
    "activityTypes" = @(
        "ArchivalRun";
        "BackupRun"
    );
    "pagination" = @{
        "limit" = $pageSize
    }
    "excludeStats" = $true
}

$outfileName = "ccsActivityReport.csv"
"""ObjectName"",""SourceName"",""Region"",""Environment"",""RunDate"",""Status"",""Message""" | Out-File -FilePath $outfileName -Encoding utf8

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

$totalCount = 0
$trackDupe = @()

while($True){
    $activities = api post -mcmv2 "data-protect/objects/activity?regionIds=$($regionList)" $queryParams
    if($activities.PSObject.Properties['activity'] -and $activities.activity -ne $null){
        $activities.activity = @($activities.activity | Where-Object {$_.id -notin $trackDupe})
        foreach($activity in $activities.activity | Where-Object {$_.archivalRunParams.status -ne 'Failed'}){
            $totalCount += 1
            $trackDupe = @($trackDupe + $activity.id)
            $objectId = $activity.object.id
            $objectName = $activity.object.name
            $regionId = $activity.regionId
            $sourceName = $activity.object.sourceName
            $environment = $activity.object.environment

            $startTimeUsecs = $activity.timeStampUsecs

            if($activity.PSObject.Properties['backupRunParams']){
                $params = $activity.backupRunParams
            }else{
                $params = $activity.archivalRunParams
            }
            $protectionEnvironmentType = $params.protectionEnvironmentType
            $status = $params.status
            $errorMessage = $params.errorMessage
            $runId = $params.runId
            if($status -eq 'SucceededWithWarning'){
                $run = api get -v2 "data-protect/objects/$($objectId)/runs/$($runId)?regionId=$($regionId)"
                if($run.PSObject.Properties['archivalInfo']){
                    $errorMessage = $run.archivalInfo.archivalTargetResults[0].message
                }
            }
            if(!$skipSuccess -or $status -ne 'Succeeded'){
                $startTime = usecsToDate $startTimeUsecs
                "$($objectName) ($($startTime)) [$($status)]"
                """$($objectName)"",""$($sourceName)"",""$($regionId)"",""$($protectionEnvironmentType)"",""$($startTime)"",""$($status)"",""$($errorMessage)""" | Out-File -FilePath $outfileName -Append
            }
        }
        if(@($activities.activity).Count -lt 100){
            break
        }else{
            $queryParams.toTimeUsecs = $activities.activity[-1].timeStampUsecs
        }
    }
}

# Write-Host "Activity Count: $totalCount"
Write-Host "`nOutput saved to $outfileName`n"
