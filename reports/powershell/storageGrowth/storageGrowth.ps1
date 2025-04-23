### usage: ./storageChart.ps1 -vip 192.168.1.198 -username admin [ -domain local ] [ -days 60 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][array]$clusterName = $null,
    [Parameter()][int32]$days = $null
)

### constants
$GiB = (1024*1024*1024)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

function reportStorage(){
    ### get cluster info
    $cluster = api get cluster
    $clusterId = $cluster.id
    $clusterName = $cluster.name
    $clusterCreatedMsecs = $cluster.createdTimeMsecs

    if($days){
        $startTimeMsecs = $(timeAgo $days days)/1000
    }else{
        $startTimeMsecs = $clusterCreatedMsecs
    }

    $outFile = join-path -Path $PSScriptRoot -ChildPath "storageGrowth-$clusterName.csv"
    "Cluster,Date,Consumed (GiB),Capacity (GiB),PCT Full" | Tee-Object -FilePath $outFile

    ### collect $days of write throughput stats
    write-host "Gathering Storage Statistics..." -ForegroundColor Green
    $consumptionStats = api get statistics/timeSeriesStats?schemaName=kBridgeClusterStats`&entityId=$clusterId`&metricName=kMorphedUsageBytes`&startTimeMsecs=$startTimeMsecs`&rollupFunction=average`&rollupIntervalSecs=86400
    $capacityStats = api get statistics/timeSeriesStats?schemaName=kBridgeClusterStats`&entityId=$clusterId`&metricName=kCapacityBytes`&startTimeMsecs=$startTimeMsecs`&rollupFunction=average`&rollupIntervalSecs=86400

    $statsConsumed = @{}
    foreach ($stat in $consumptionStats.dataPointVec){
        $dt = (Get-Date (usecsToDate (($stat.timestampMsecs)*1000)) -Hour 0 -Minute 0 -Second 0).ToString('yyyy-MM-dd')
        $consumed = $stat.data.int64Value/$GiB
        $statsConsumed[$dt] =  [math]::Round($consumed)
    }

    $statsCapacity = @{}
    foreach ($stat in $capacityStats.dataPointVec){
        $dt = (Get-Date (usecsToDate (($stat.timestampMsecs)*1000)) -Hour 0 -Minute 0 -Second 0).ToString('yyyy-MM-dd')
        $capacity = $stat.data.int64Value/$GiB
        $statsCapacity[$dt] =  [math]::Round($capacity)
    }

    foreach($dt in $statsConsumed.Keys | Sort-Object -Descending){
        $pctFull = ([math]::Round(100 * $statsConsumed[$dt] / $statsCapacity[$dt]))
        """{0}"",""{1}"",""{2}"",""{3}"",""{4}""" -f $cluster.name, $dt, $statsConsumed[$dt], $statsCapacity[$dt], $pctFull | Tee-Object -FilePath $outFile -Append
    }

    write-host "Output written to $outFile" -ForegroundColor Green

}

# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "`n$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName | Sort-Object){
            $null = heliosCluster $c
            reportStorage
        }
    }else{
        reportStorage
    }
}
