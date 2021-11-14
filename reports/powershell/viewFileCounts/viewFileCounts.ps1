### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

"`nGathering view stats...`n"

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "ViewFileCounts-$($cluster.name)-$dateString.csv"
"View,Folders,Files" | Out-File -FilePath $outfileName

$views = api get views

$endMsecs = (dateToUsecs (get-date)) / 1000
$startMsecs = $endMsecs - 172800000

foreach($view in $views.views | Sort-Object -Property name){
    $consumer = api get "stats/consumers?consumerType=kViews&consumerIdList=$($view.viewId)"
    $entityId = $consumer.statsList[0].groupList[0].entityId
    $folderStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=BookKeeperStats&metricName=NumDirectories&rollupIntervalSecs=21600&rollupFunction=latest&entityIdList=$entityId&endTimeMsecs=$endMsecs"
    if($folderStats.dataPointVec.Count -gt 0){
        $numDirectories = $folderStats.dataPointVec[0].data.int64Value
    }else{
        $numDirectories = 0
    }
    $fileStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=BookKeeperStats&metricName=NumFiles&rollupIntervalSecs=21600&rollupFunction=latest&entityIdList=$entityId&endTimeMsecs=$endMsecs"
    if($fileStats.dataPointVec.Count -gt 0){
        $numFiles = $fileStats.dataPointVec[0].data.int64Value
    }else{
        $numFiles = 0
    }
    "{0,25}  {1}/{2}" -f $view.name, $numDirectories, $numFiles
    "{0},{1},{2}" -f $view.name, $numDirectories, $numFiles | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfileName`n"
