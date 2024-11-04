### process commandline arguments
[CmdletBinding()]
param (
   [Parameter()][string]$vip = 'helios.cohesity.com',
   [Parameter()][string]$username = 'helios',
   [Parameter()][string]$domain = 'local',
   [Parameter()][switch]$useApiKey,
   [Parameter()][string]$password = $null,
   [Parameter()][switch]$mcm,
   [Parameter()][string]$mfaCode = $null,
   [Parameter()][switch]$emailMfaCode,
   [Parameter()][string]$clusterName = $null,
   [Parameter()][int]$days = 7,
   [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'MiB'
)

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-$dateString-replicationWireStats.csv"

# headings
"""Remote Cluster"",""Date"",""$unit""" | Out-File -FilePath $outfileName -Encoding utf8

$daysAgoMsecs = [int64] [math]::Round((dateToUsecs ((Get-Date).AddDays(-$days))) / 1000)

$remoteClusters = api get remoteClusters | Where-Object {$_.purposeReplication -eq $True}
$remoteClusterStatEntities = api get "statistics/entities?maxEntities=1000&schemaName=kBridgeMadroxRemoteClusterStats"
$remoteClusterStatEntityIds = @($remoteClusterStatEntities.entityId.entityId.data.int64Value)

foreach($remoteCluster in $remoteClusters){
    if($remoteCluster.clusterId -in $remoteClusterStatEntityIds){
        "Getting stats for $($remoteCluster.name)..."
        $stats = api get "statistics/timeSeriesStats?&entityId=$($remoteCluster.clusterId)&metricName=kTxPhysicalBytesMorphed&metricUnitType=0&range=day&rollupFunction=sum&rollupIntervalSecs=86400&schemaName=kBridgeMadroxRemoteClusterStats&startTimeMsecs=$daysAgoMsecs"
        foreach($stat in $stats.dataPointVec){
            $statDate = usecsToDate ($stat.timestampMsecs * 1000)
            $statValue = $stat.data.int64Value
            """{0}"",""{1}"",""{2}""" -f $remoteCluster.name, $statDate, (toUnits $statValue) | Out-File -FilePath $outfileName -Encoding utf8 -Append
        }
    }
}

Write-Host "`nOutput saved to $outfileName`n"
