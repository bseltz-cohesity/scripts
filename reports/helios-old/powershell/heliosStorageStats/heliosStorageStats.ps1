# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password = $null,
    [Parameter()][ValidateSet('GiB','TiB')][string]$unit = 'TiB'
)

$conversion = @{'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -helios

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "heliosStorageStats-$dateString.csv"

# headings
"Cluster,Capacity ($unit),Consumed ($unit),Free ($unit),Used %,Data In ($unit),Data Written ($unit),Storage Reduction,Data Reduction" | Out-File -FilePath $outfileName

$stats = @{}

function parseStats($clusterName, $dataPoint, $statName){
    if($clusterName -notin $stats.Keys){
        $stats[$clusterName] = @{}
    }
    $stats[$clusterName][$statName] = $dataPoint.data.int64Value
}

$endMsecs = [math]::Round((dateToUsecs (Get-Date)) / 1000, 0)
$startMsecs = [math]::Round((timeAgo 2 days) / 1000, 0)

"`nGathering cluster stats:`n"

foreach($cluster in heliosClusters){
    heliosCluster $cluster
    "    $($cluster.name)"
    $capacityStats = api get "statistics/timeSeriesStats?endTimeMsecs=$endMsecs&entityId=$($cluster.clusterId)&metricName=kCapacityBytes&metricUnitType=0&range=day&rollupFunction=average&rollupIntervalSecs=86400&schemaName=kBridgeClusterStats&startTimeMsecs=$startMsecs"
    $consumedStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=kBridgeClusterTierPhysicalStats&metricName=kMorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.clusterId):Local&endTimeMsecs=$endMsecs"
    $dataInStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=ApolloV2ClusterStats&metricName=BrickBytesLogical&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.name) (ID $($cluster.clusterId))&endTimeMsecs=$endMsecs"
    $dataWrittenStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=ApolloV2ClusterStats&metricName=ChunkBytesMorphed&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.name) (ID $($cluster.clusterId))&endTimeMsecs=$endMsecs"
    $logicalSizeStats = api get "statistics/timeSeriesStats?startTimeMsecs=$startMsecs&schemaName=kBridgeClusterLogicalStats&metricName=kUnmorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$($cluster.clusterId)&endTimeMsecs=$endMsecs"

    parseStats $cluster.name $capacityStats.dataPointVec[0] 'capacity'
    parseStats $cluster.name $consumedStats.dataPointVec[0] 'consumed'
    parseStats $cluster.name $dataInStats.dataPointVec[0] 'dataIn'
    parseStats $cluster.name $dataWrittenStats.dataPointVec[0] 'dataWritten'
    parseStats $cluster.name $logicalSizeStats.dataPointVec[0] 'logicalSize'

}

foreach($clusterName in $stats.Keys | Sort-Object){
    $capacity = $stats[$clusterName].capacity
    $consumed = $stats[$clusterName].consumed
    $dataIn = $stats[$clusterName].dataIn
    $dataWritten = $stats[$clusterName].dataWritten
    $logicalSize = $stats[$clusterName].logicalSize
    $free = $capacity - $consumed
    $pctUsed = [math]::Round(100 * $consumed / $capacity, 0)
    $storageReduction = [math]::Round($logicalSize / $consumed, 1)
    $dataReduction = [math]::Round($dataIn / $dataWritten, 1)
    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""" -f $clusterName, (toUnits $capacity), (toUnits $consumed), (toUnits $free), $pctUsed, (toUnits $dataIn), (toUnits $dataWritten), $storageReduction, $dataReduction | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfilename`n"
