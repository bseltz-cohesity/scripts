# version: 2025-01-03

# process commandline arguments
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
    [Parameter()][ValidateSet('MiB','GiB','TiB','MB','GB','TB')][string]$unit = 'GiB',
    [Parameter()][string]$outfileName
)

$scriptversion = '2025-01-03 (PowerShell)'

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024; 'KB' = 1000; 'MB' = 1000 * 1000; 'GB' = 1000 * 1000 * 1000; 'TB' = 1000 * 1000 * 1000 * 1000}

function toUnits($val){
    return [math]::Round($val/$conversion[$unit], 1)
}

$dateString = (get-date).ToString('yyyy-MM-dd')
if(!$outfileName){
    $outfileName = "storageStatsReport-$dateString.csv"
}

# log function
function output($msg, [switch]$warn, [switch]$quiet){
    if(!$quiet){
        if($warn){
            Write-Host $msg -ForegroundColor Yellow
        }else{
            Write-Host $msg
        }
    }
}

# headings
"""Cluster Name"",""Total Used $unit"",""BookKeeper Used $unit"",""Total Unaccounted Usage $unit"",""Total Unaccounted Percent"",""Morphed Garbage $unit"",""Garbage Percent"",""Other Unaccounted $unit"",""Other Unaccounted Percent"",""Reduction Ratio"",""Script Version"",""Cluster Software Version""" | Out-File -FilePath $outfileName

function reportStorage(){
    $viewHistory = @{}
    $cluster = api get "cluster?fetchStats=true"
    output "$($cluster.name)"
    $clusterUsed = 0
    $sumObjectsUsed = 0
    $sumObjectsWritten = 0
    $sumObjectsWrittenWithResiliency = 0

    try{
        $clusterReduction = [math]::Round($cluster.stats.dataUsageStats.dataInBytes / $cluster.stats.usagePerfStats.dataInBytesAfterReduction, 1)
        $clusterUsed = toUnits $cluster.stats.localUsagePerfStats.totalPhysicalUsageBytes
    }catch{
        $clusterReduction = 1
    }
    $garbageStart = (dateToUsecs (Get-Date -Hour 0 -Minute 0 -Second 0)) / 1000
    $bookKeeperStart = (dateToUsecs ((Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-29))) / 1000
    $bookKeeperEnd = (dateToUsecs ((Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(1))) / 1000
    $bookKeeperStats = api get "statistics/timeSeriesStats?startTimeMsecs=$bookKeeperStart&schemaName=MRCounters&metricName=bytes_value&rollupIntervalSecs=180&rollupFunction=average&entityId=BookkeeperChunkBytesPhysical&endTimeMsecs=$bookKeeperEnd"
    $bookKeeperBytes = $bookKeeperStats.dataPointVec[-1].data.int64Value
    $clusterUsedBytes = $cluster.stats.localUsagePerfStats.totalPhysicalUsageBytes
    $unaccounted = $clusterUsedBytes - $bookKeeperBytes
    $unaccountedPercent = 0
    $garbageStats = api get "statistics/timeSeriesStats?endTimeMsecs=$bookKeeperEnd&entityId=$($cluster.id)&metricName=kMorphedGarbageBytes&metricUnitType=0&range=day&rollupFunction=average&rollupIntervalSecs=360&schemaName=kBridgeClusterStats&startTimeMsecs=$garbageStart"
    $garbageBytes = $garbageStats.dataPointVec[-1].data.int64Value
    $garbagePercent = 0
    $otherUnaccountedBytes = $unaccounted - $garbageBytes
    $otherUnaccountedPercent = 0
    if($clusterUsedBytes -gt 0){
        $unaccountedPercent = [math]::Round(100 * ($unaccounted / $clusterUsedBytes), 1)
        $garbagePercent = [math]::Round(100 * ($garbageBytes / $clusterUsedBytes), 1)
        $otherUnaccountedPercent = $unaccountedPercent - $garbagePercent
    }
    """$($cluster.name)"",""$clusterUsed"",""$(toUnits $bookKeeperBytes)"",""$(toUnits $unaccounted)"",""$unaccountedPercent"",""$(toUnits $garbageBytes)"",""$garbagePercent"",""$(toUnits $otherUnaccountedBytes)"",""$otherUnaccountedPercent"",""$clusterReduction"",""$scriptVersion"",""$($cluster.clusterSoftwareVersion)""" | Out-File -FilePath $outfileName -Append
}

# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        output "`n$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            reportStorage
        }
    }else{
        reportStorage
    }
}

output "Output saved to: $outfileName"
