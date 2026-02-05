# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][int]$days = 2,
    [Parameter()][int]$pageSize = 500
)

$version = '2026-02-05'

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt

# date range
$midnight = Get-Date -Hour 0 -Minute 0
$midnightUsecs = dateToUsecs $midnight
$uEnd = $midnightUsecs + 86399000000
$uStart = $midnightUsecs - ($days * 86400000000) + 86400000000

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

$outfileName = "ccsSlaReport.csv"
"""ObjectName"",""SourceName"",""Region"",""Environment"",""RunDate"",""Status"",""RunType"",""SLAViolated""" | Out-File -FilePath $outfileName -Encoding utf8

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

$totalCount = 0
$trackDupe = @()
$finishedStates = @('SucceededWithWarning', 'Succeeded', 'Failed', 'Canceled')

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
            $isSlaViolated = $params.isSlaViolated
            $runType = $params.runType
            $runId = $params.runId

            if($status -notin $finishedStates){
                $objects = api get -v2 "data-protect/objects?ids=$objectId&includeLastRunInfo=false&regionId=$($regionId)"
                $sla = $objects.objects[0].objectBackupConfiguration.sla | Where-Object backupRunType -eq $runType
                $slaMinutes = $sla.slaMinutes
                $nowUsecs = dateToUsecs
                $slaWindow = $startTimeUsecs + ($slaMinutes * 60000000)
                $isSlaViolated = $false
                if($slaWindow -le $nowUsecs){
                    $isSlaViolated = $True
                }
            }

            $startTime = usecsToDate $startTimeUsecs
            "$($objectName) ($($startTime)) [$($status)] $($isSlaViolated)"
            """$($objectName)"",""$($sourceName)"",""$($regionId)"",""$($protectionEnvironmentType)"",""$($startTime)"",""$($status)"",""$($runType)"",""$($isSlaViolated)""" | Out-File -FilePath $outfileName -Append
        }
        if(@($activities.activity).Count -lt 100){
            break
        }else{
            $queryParams.toTimeUsecs = $activities.activity[-1].timeStampUsecs
        }
    }
}

Write-Host "`nOutput saved to $outfileName`n"
