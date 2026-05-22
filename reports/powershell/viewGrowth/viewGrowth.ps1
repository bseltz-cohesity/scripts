### usage: ./viewGrowth.ps1 -vip mycluster -username myusername -domain mydomain.net [ -days 31 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][int]$days = 31,
    [Parameter()][switch]$skipEmpty
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$views = (api get views).views | Sort-Object -Property name
$consumers = api get stats/consumers?consumerType=kViews

$endDate = get-date
$startDate = $endDate.AddDays(-$days)
$startDateString = ([datetime]$startDate).ToString("yyyy-MM-dd")
$endDateString = ([datetime]$endDate).ToString("yyyy-MM-dd")
$outfile = "viewGrowth_$($vip -replace ':', '-')_$($startDateString)_$($endDateString).csv"

$startDateMsecs = (dateToUsecs $startDate)/1000
$endDateMsecs = (dateToUsecs $endDate)/1000

function formatSize($size){
    $sizeUnits = 'B'
    if([math]::Abs($size) -ge 1073741824){
        $size = [math]::round(($size/1073741824),1)
        $sizeUnits = 'GiB'
    }elseif ([math]::Abs($size) -ge 1048576) {
        $size = [math]::round(($size/1048576),1)
        $sizeUnits = 'MiB'                                                              
    }elseif ([math]::Abs($size) -ge 1024) {
        $size = [math]::round(($size/1024),1)
        $sizeUnits = 'KiB'                                                              
    }
    "$size $sizeUnits"
}

"View Name,Start Size,Start (Formatted),End Size,End (Formatted),Growth,Growth (Formatted)," | Out-File  $outfile

foreach($view in $views | Sort-Object -Property name){
    $consumer = $consumers.statsList | Where-Object {$_.id -eq $view.viewId}
    $consumerId = $consumer.groupList[0].id
    $viewStats = api get -v2 "stats/time-series-stats?startTimeMsecs=$startDateMsecs&schemaName=BookKeeperStats&metricNames=LogicalUsage&rollupIntervalSecs=86400&rollupFunction=kLatest&entityIdList=$consumerId&endTimeMsecs=$endDateMsecs"
    $stats = $viewStats.timeSeriesStats[0]
    if($stats.dataPoints.count -gt 0){
        $stats.dataPoints = $stats.dataPoints | Sort-Object -Property timestampMsecs
        $startSize = $stats.dataPoints[0].int64Value
        $endSize = $stats.dataPoints[-1].int64Value
        "
 View Name: {0}
Start Size: {1} ({2})
  End Size: {3} ({4})
    Growth: {5} ({6})" -f $view.name, $startSize, $(formatSize($startSize)), $endSize, $(formatSize($endSize)), $($endSize - $startSize), $(formatSize(($endSize - $startSize)))    

        "{0},{1},{2},{3},{4},{5},{6}" -f $view.name, $startSize, $(formatSize($startSize)), $endSize, $(formatSize($endSize)), $($endSize - $startSize), $(formatSize(($endSize - $startSize))) | Out-File $outfile -Append

    }else{
        $view.name | Out-File $outfile -Append
        Write-Warning "No stats for $($view.name)"
    }
}
