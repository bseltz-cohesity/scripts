# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][ValidateSet('GiB','TiB')][string]$unit = 'TiB',
    [Parameter()][Int]$days = 31
)

$conversion = @{'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "clusterStorageStats-$($cluster.name)-$dateString.csv"

# headings
"Date,Capacity ($unit),Consumed ($unit),Free ($unit),Used %,Data In ($unit),Data Written ($unit),Storage Reduction,Data Reduction" | Out-File -FilePath $outfileName

$endMsecs = [math]::Round((dateToUsecs (Get-Date)) / 1000, 0)
$startMsecs = [math]::Round((timeAgo $days days) / 1000, 0)

$capacityStats = api get "statistics/timeSeriesStats?endTimeMsecs=$endMsecs&entityId=$($cluster.id)&metricName=kCapacityBytes&metricUnitType=0&range=day&rollupFunction=average&rollupIntervalSecs=86400&schemaName=kBridgeClusterStats&startTimeMsecs=$startMsecs"
$consumedStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=kBridgeClusterTierPhysicalStats&metricName=kMorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.id):Local&endTimeMsecs=$endMsecs"
$dataInStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=ApolloV2ClusterStats&metricName=BrickBytesLogical&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.name) (ID $($cluster.id))&endTimeMsecs=$endMsecs"
$dataWrittenStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=ApolloV2ClusterStats&metricName=ChunkBytesMorphed&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.name) (ID $($cluster.id))&endTimeMsecs=$endMsecs"
$logicalSizeStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=kBridgeClusterLogicalStats&metricName=kUnmorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.id)&endTimeMsecs=$endMsecs"

$stats = @{}

function parseStats($dataPoints, $statName){
    foreach($stat in $dataPoints){
        $value = $stat.data.int64Value
        $date = (usecsToDate ($stat.timestampMsecs * 1000)).ToString('yyyy-MM-dd')
        if($date -notin $stats.Keys){
            $stats[$date] = @{}
        }
        $stats[$date][$statName] = $value
    }
}

parseStats $capacityStats.dataPointVec 'capacity'
parseStats $consumedStats.dataPointVec 'consumed'
parseStats $dataInStats.dataPointVec 'dataIn'
parseStats $dataWrittenStats.dataPointVec 'dataWritten'
parseStats $logicalSizeStats.dataPointVec 'logicalSize'

$lastStatReported = $false
foreach($date in $stats.Keys | Sort-Object -Descending){
    $capacity = $stats[$date].capacity
    $consumed = $stats[$date].consumed
    $dataIn = $stats[$date].dataIn
    $dataWritten = $stats[$date].dataWritten
    $logicalSize = $stats[$date].logicalSize
    $free = $capacity - $consumed
    $pctUsed = [math]::Round(100 * $consumed / $capacity, 0)
    $storageReduction = [math]::Round($logicalSize / $consumed, 1)
    $dataReduction = [math]::Round($dataIn / $dataWritten, 1)
    if(!$lastStatReported){
        $lastStatReported = $True
        "`nStats for $($cluster.name):`n"
        "         Capacity: {0} $unit" -f (toUnits $capacity)
        "         Consumed: {0} $unit" -f (toUnits $consumed)
        "             Free: {0} $unit" -f (toUnits $free)
        "     Percent Used: {0}%" -f $pctUsed
        "Storage Reduction: {0}x" -f $storageReduction
        "   Data Reduction: {0}x" -f $dataReduction
    }
    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""" -f $date, (toUnits $capacity), (toUnits $consumed), (toUnits $free), $pctUsed, (toUnits $dataIn), (toUnits $dataWritten), $storageReduction, $dataReduction | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfilename`n"
