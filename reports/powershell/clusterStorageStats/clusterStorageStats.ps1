# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][ValidateSet('GiB','TiB')][string]$unit = 'TiB',
    [Parameter()][Int]$days = 31
)

$conversion = @{'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

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
    if($capacity -eq $null -or $capacity -eq 0){
        continue
    }
    $consumed = $stats[$date].consumed
    $dataIn = $stats[$date].dataIn
    $dataWritten = $stats[$date].dataWritten
    $logicalSize = $stats[$date].logicalSize
    $free = $capacity - $consumed
    $pctUsed = [math]::Round(100 * $consumed / $capacity, 0)
    $storageReduction = 1
    if($consumed -gt 0){
        $storageReduction = [math]::Round($logicalSize / $consumed, 1)
    }
    $dataReduction = 1
    if($dataWritten -gt 0){
        $dataReduction = [math]::Round($dataIn / $dataWritten, 1)
    }
    
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
