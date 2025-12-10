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
    [Parameter()][string]$outFolder = '.'        # output folder
)

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

$cluster = api get cluster?fetchStats=true
$dateString = (get-date).ToString('yyyy-MM-dd')
$GiB = 1024 * 1024 * 1024

$outfile = $(Join-Path -Path $outFolder -ChildPath "$($cluster.name)-clusterInfo-$dateString.txt")
$csvfile = $(Join-Path -Path $outFolder -ChildPath "$($cluster.name)-clusterInfo-$dateString.csv")

$dateString | Out-File -FilePath $outfile

# log function
function output($msg, [switch]$warn){
    if($warn){
        Write-Host $msg -ForegroundColor Yellow
    }else{
        Write-Host $msg
    }
    $msg | Out-File -FilePath $outfile -Append
}

$version = ($cluster.clusterSoftwareVersion -split '_')[0]

$status = api get /nexus/cluster/status
$nodeStatus = $status.nodeStatus

$chassisList = api get -v2 chassis
if($chassisList.PSObject.Properties['chassis']){
    $chassisList = $chassisList.chassis
}

$nodes = api get nodes

$physicalCapacity = [math]::round($cluster.stats.usagePerfStats.physicalCapacityBytes / $GiB, 1)
$usedCapacity = [math]::round($cluster.stats.usagePerfStats.totalPhysicalUsageBytes / $GiB, 1)
$usedPct = [int][math]::round(100 * $usedCapacity / $physicalCapacity, 0)

# cluster info
output "`n-------------------------------------------------------"
output ("     Cluster Name: {0}" -f $hostName)
output ("  Product Version: {0}" -f $cluster.clusterSoftwareVersion)
output ("       Cluster ID: {0}" -f $cluster.id)
output ("   Healing Status: {0}" -f $status.healingStatus)
output ("     Service Sync: {0}" -f $status.isServiceStateSynced)
output (" Stopped Services: {0}" -f $status.bulletinState.stoppedServices)
output ("Physical Capacity: {0} GiB" -f $physicalCapacity)
output ("    Used Capacity: {0} GiB" -f $usedCapacity)
output ("     Used Percent: {0}%" -f $usedPct)
output ("  Number of nodes: {0}" -f @($nodes).Length)
output ("-------------------------------------------------------")

"""Chassis ID"",""Chassis Name"",""Chassis Serial"",""Chassis Hardware"",""Node ID"",""Node IP"",""IPMI IP"",""Slot Number"",""Node Serial"",""Hardware Model"",""Cohesity Version"",""Uptime""" | Out-File -FilePath $csvfile

$ipmi = api get /nexus/ipmi/cluster_get_lan_info -quiet
foreach($chassis in $chassisList | Sort-Object -Property id){
    # chassis info
    if($chassis.PSObject.Properties['name']){
        $chassisname = $chassis.name
    }else{
        $chassisname = $chassis.serial
    }
    if($chassis.PSObject.Properties['hardwareModel']){
        $hwmodel = $chassis.hardwareModel
    }else{
        $hwmodel = 'VirtualEdition'
    }
    output ("`n     Chassis Name: {0}" -f $chassisname)
    output ("       Chassis ID: {0}" -f $chassis.id)
    output ("         Hardware: {0}" -f $hwmodel)
    if($chassis.serialNumber){
        output ("   Chassis Serial: {0}" -f $chassis.serialNumber)
        $needSerial = $false
    }else{
        $needSerial = $True
    }
    $nodeIds = $chassis.nodeIds
    foreach($node in $nodes | Where-Object {$_.chassisInfo.chassisId -eq $chassis.id} | Sort-Object -Property slotNumber){
        # node info
        $nodeIp = ($node.ip -split ':')[-1]
        $nodeipmi = $ipmi.nodesIpmiInfo | Where-Object nodeIp -eq ($node.ip -split ':')[-1]
        if($nodeipmi){
            $nodeIpmiIp = $nodeipmi[0].nodeIpmiIp
        }else{
            $nodeIpmiIp = 'n/a'
        }
        if($node.PSObject.Properties['cohesityNodeSerial']){
            $nodeSerial = $node.cohesityNodeSerial
        }else{
            $nodeSerial = 'Unknown'
        }
        if($node.PSObject.Properties['productModel']){
            $productModel = $node.productModel
        }else{
            $productModel = 'Unknown'
        }
        if($node.PSObject.Properties['slotNumber']){
            $slotNumber = $node.slotNumber
        }else{
            $slotNumber = 0
        }
        if($needSerial){
            output ("   Chassis Serial: {0}" -f $nodeInfo.cohesityChassisSerial)
            $needSerial = $false
        }
        output ("`n                  Node ID: {0}" -f $node.id)
        output ("                  Node IP: {0}" -f $nodeIp)
        output ("                  IPMI IP: {0}" -f $nodeIpmiIp)
        output ("                  Slot No: {0}" -f $slotNumber)
        output ("                Serial No: {0}" -f $nodeSerial)
        output ("            Product Model: {0}" -f $productModel)
        output ("          Product Version: {0}" -f $node.nodeSoftwareVersion)
        foreach($stat in $nodeStatus){
            if($stat.nodeId -eq $node.id){
                $uptime = $stat.uptime
                output ("                   Uptime: {0}" -f $stat.uptime)
            }     
        }
        """$($chassis.id)"",""$chassisname"",""$($chassis.serialNumber)"",""$hwmodel"",""$($node.id)"",""$($nodeIp)"",""$nodeIpmiIp"",""$slotNumber"",""$nodeSerial"",""$productModel"",""$($node.nodeSoftwareVersion)"",""$uptime""" | Out-File -FilePath $csvfile -Append
    }
}

"`nOutput saved to $outfile`n            and $csvfile`n"
