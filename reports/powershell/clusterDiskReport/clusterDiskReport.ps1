# version: 2025-10-17

# process commandline arguments
[CmdletBinding(PositionalBinding=$false)]
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
    [Parameter()][string]$outfileName
)

$scriptversion = '2025-10-17'

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$dateString = (get-date).ToString('yyyy-MM-dd-HH-mm')
if(!$outfileName){
    $outfileName = "clusterDiskReport-$dateString.csv"
}

# headings
"""Cluster Name"",""Node IP"",""Node ID"",""Storage Tier"",""Size TiB"",""Serial Number"",""Avoid Access"",""Removal State""" | Out-File -FilePath $outfileName

function getReport(){
    $cluster = api get cluster
    Write-Host "`n$($cluster.name)"
    $disks = api get "/disks?includeMarkedForRemoval=true"
    $alerts = api get "alerts?maxAlerts=1000&alertTypeBucketList=kHardware&alertStateList=kOpen,kNote&alertSeverityList=kWarning&alertCategoryList=kDisk"
    foreach($alert in $alerts){
        $disk_serial = $disk_node_id = $disk_node_ip = $null
        $disk_serial = ($alert.propertyList | Where-Object key -eq 'disk_serial').value
        $disk_node_id = ($alert.propertyList | Where-Object key -eq 'node_id').value
        $disk_node_ip = ($alert.propertyList | Where-Object key -eq 'node_ip').value
        $existingDisk = $disks | Where-Object {$_.hardwareInfo.serial -eq $disk_serial}
        if(! $disk_serial){
            continue
        }
        if(!$existingDisk){
            $disks = @($disks + @{
                'currentNodeIp' = $disk_node_ip;
                'currentNodeId' = $disk_node_id;
                'hardwareInfo' = @{
                    'serial' = $disk_serial
                };
                'avoidAccess' = $True;
                'removalState' = 'kBlacklisted'
            })
        }
    }
    foreach($disk in $disks | Sort-Object -Property currentNodeIp, storageTier){
        """$($cluster.name.toUpper())"",""$($disk.currentNodeIp)"",""$($disk.currentNodeId)"",""$($disk.storageTier)"",""$([math]::Round($disk.maxPhysicalCapacityBytes / (1024 * 1024 * 1024 * 1024), 2))"",""$($disk.hardwareInfo.serial)"",""$($disk.avoidAccess)"",""$($disk.removalState)""" | Out-File -FilePath $outfileName -Append
    }
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
    if(! $USING_HELIOS -and $useApiKey -and $password){
        $password = $null
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            getReport
        }
    }else{
        getReport
    }
}

Write-Host "`nOutput saved to: $outfileName`n"
