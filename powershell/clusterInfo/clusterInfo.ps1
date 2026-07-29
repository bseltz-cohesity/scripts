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
    [Parameter()][string]$outFolder = '.'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$GiB = 1024 * 1024 * 1024
$dateString = (get-date).ToString('yyyy-MM-dd-HH-mm')
if(!$outfileName){
    $outfileName = "clusterInfo-$dateString.csv"
}

$outfile = $(Join-Path -Path $outFolder -ChildPath "clusterInfo-$dateString.txt")
$csvfile = $(Join-Path -Path $outFolder -ChildPath "clusterInfo-$dateString.csv")
(get-date).ToString('yyyy-MM-dd') | Out-File -FilePath $outfile

# headings
"""Cluster Name"",""Chassis ID"",""Chassis Name"",""Chassis Serial"",""Chassis Hardware"",""Slot Number"",""Node ID"",""Virtual IPs"",""Node IP"",""IPMI IP"",""Node Serial"",""Hardware Model"",""Cohesity Version"",""Uptime"",""Interfaces"",""Disk Count"",""Offline Disk Count""" | Out-File -FilePath $csvfile

function output($msg, [switch]$warn){
    if($warn){
        Write-Host $msg -ForegroundColor Yellow
    }else{
        Write-Host $msg
    }
    $msg | Out-File -FilePath $outfile -Append
}

function getReport(){

    $cluster = api get cluster?fetchStats=true
    $version = ($cluster.clusterSoftwareVersion -split '_')[0]

    $status = api get /nexus/cluster/status
    $nodeStatus = $status.nodeStatus

    $chassisList = api get -v2 chassis
    if($chassisList.PSObject.Properties['chassis']){
        $chassisList = $chassisList.chassis
    }

    $nodes = api get -v2 clusters/nodes
    $interfaces = api get interface
    $physicalCapacity = [math]::round($cluster.stats.usagePerfStats.physicalCapacityBytes / $GiB, 1)
    $usedCapacity = [math]::round($cluster.stats.usagePerfStats.totalPhysicalUsageBytes / $GiB, 1)
    $usedPct = [int][math]::round(100 * $usedCapacity / $physicalCapacity, 0)

    # cluster info
    output "`n-------------------------------------------------------"
    output ("     Cluster Name: {0}" -f $cluster.name)
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
            $if = $interfaces | Where-Object nodeId -eq $node.id
            $ints = $if.interfaces # | Where-Object {$_.isConnected -eq $True -and $_.PSObject.Properties['speed']}
            $vips = ($if.interfaces.virtualIp | Where-Object {$_}) -join ', '
            $diskCount = ($node.diskCountByTier.diskCount | Measure-Object -Sum).Sum
            output ("`n                  Node ID: {0}" -f $node.id)
            # output ("              Virtual IPs: {0}" -f $vips)
            output ("                  Node IP: {0}" -f $nodeIp)
            output ("                  IPMI IP: {0}" -f $nodeIpmiIp)
            output ("                  Slot No: {0}" -f $slotNumber)
            output ("                Serial No: {0}" -f $nodeSerial)
            output ("            Product Model: {0}" -f $productModel)
            output ("          Product Version: {0}" -f $node.nodeSoftwareVersion)
            output ("               Disk Count: {0}" -f $diskCount)
            output ("       Offline Disk Count: {0}" -f $node.offlineDiskCount)
            foreach($stat in $nodeStatus){
                if($stat.nodeId -eq $node.id){
                    $uptime = $stat.uptime
                    output ("                   Uptime: {0}" -f $stat.uptime)
                }     
            }
            $infs = @()
            $vlans = api get "vlans?_includeTenantInfo=true"
            
            foreach($int in $ints | Sort-Object -Property name){
                # $int | toJson
                $group = $int.group
                if($group -notmatch '\.'){
                    $group = "$($group).0"
                }
                $vlan = $vlans | Where-Object {$_.ifaceGroupName -eq $group}
                $speed = 'UNKNOWN'
                if($int.PSObject.Properties['speed']){
                    $speed = $int.speed
                }
                output ("                Interface: {0} ({1}) MTU: {2}" -f $int.name, $speed, $int.mtu)
                if($vlan){
                    output ("                           FQDN: {0}" -f $vlan.hostname)
                }
                if($int.PSObject.Properties['staticIp']){
                    output ("                           Static IP: {0}" -f $int.staticIp)
                }
                if($int.PSObject.Properties['virtualIp']){
                    output ("                           Virtual IP: {0}" -f $int.virtualIp)
                }
                output ("                           MAC Address: {0}" -f $int.macAddress)
                $infs = @($infs + "$($int.name)($($int.speed))")
            }
            """$($cluster.name)"",""$($chassis.id)"",""$chassisname"",""$($chassis.serialNumber)"",""$hwmodel"",""$slotNumber"",""$($node.id)"",""$vips"",""$($nodeIp)"",""$nodeIpmiIp"",""$nodeSerial"",""$productModel"",""$($node.nodeSoftwareVersion)"",""$uptime"",""$($infs -join ';')"",""$($diskCount)"",""$($node.offlineDiskCount)""" | Out-File -FilePath $csvfile -Append
        }
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
            Write-Host "`n$c`n"
            getReport
        }
    }else{
        getReport
    }
}

Write-Host "`nOutput saved to $outfile`n            and $csvfile`n"
