### usage: ./viewGrowth.ps1 -vip mycluster -username myusername -domain mydomain.net [ -days 31 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$days = 31
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$views = (api get views).views | Sort-Object -Property name

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
    $stats = api get "statistics/timeSeriesStats?endTimeMsecs=$endDateMsecs&entityId=$($view.viewId)&metricName=kSystemUsageBytes&metricUnitType=0&range=week&rollupFunction=latest&rollupIntervalSecs=14400&schemaName=kBridgeViewLogicalStats&startTimeMsecs=$startDateMsecs"
    if($stats.dataPointVec.count -gt 0){
        $startSize = $stats.dataPointVec[0].data.int64Value
        $endSize = $stats.dataPointVec[-1].data.int64Value
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
