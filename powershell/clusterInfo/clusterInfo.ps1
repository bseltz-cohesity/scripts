# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$outFolder = '.'        # output folder
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

$cluster = api get cluster?fetchStats=true
$dateString = (get-date).ToString('yyyy-MM-dd')
$GiB = 1024 * 1024 * 1024

$outfile = $(Join-Path -Path $outFolder -ChildPath "$($cluster.name)-clusterInfo-$dateString.txt")

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
# $config = $status.clusterConfig.proto
$nodeStatus = $status.nodeStatus

# if($config){
#     $chassisList = $config.chassisVec
#     $hostName = $status.clusterConfig.proto.clusterPartitionVec[0].hostName
# }else{
#     $chassisList = (api get -v2 chassis).chassis
#     $hostName = (api get clusterPartitions)[0].hostName
# }

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
        $nodeIp = ($node.ip -split ':')[-1]
        $nodeipmi = $ipmi.nodesIpmiInfo | Where-Object nodeIp -eq ($node.ip -split ':')[-1]
        if($nodeipmi){
            $nodeIpmiIp = $nodeipmi[0].nodeIpmiIp
        }else{
            $nodeIpmiIp = ''
        }
        # node info
        copySessionCookie $node.ip
        $cohesity_api.apiRoot = "https://$($nodeIp)/irisservices/api/v1"
        $nodeInfo = api get /nexus/node/hardware_info
        $nwInfo = api get /nexus/node/list_network_interfaces?cache=true

        if($needSerial){
            output ("   Chassis Serial: {0}" -f $nodeInfo.cohesityChassisSerial)
            $needSerial = $false
        }
        output ("`n                  Node ID: {0}" -f $node.id)
        output ("              Virtual IPs: {0}" -f (($nwInfo.networkInterfaces.virtualIp | Where-Object {$_ -ne ''} | Sort-Object) -join ', '))
        output ("                  Node IP: {0}" -f $nodeIp)
        output ("                  IPMI IP: {0}" -f $nodeIpmiIp)
        output ("                  Slot No: {0}" -f $node.slotNumber)
        output ("                Serial No: {0}" -f $nodeInfo.cohesityNodeSerial)
        output ("            Product Model: {0}" -f $nodeInfo.productModel)
        output ("          Product Version: {0}" -f $node.nodeSoftwareVersion)
        foreach($stat in $nodeStatus){
            if($stat.nodeId -eq $node.id){
                output ("                   Uptime: {0}" -f $stat.uptime)
            }     
        }
    }
}

"`nOutput saved to $outfile`n"
