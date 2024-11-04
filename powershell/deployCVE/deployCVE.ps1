
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string[]]$ip, # ip addresses of the nodes
    [Parameter(Mandatory = $True)][string]$netmask, # subnet mask
    [Parameter(Mandatory = $True)][string]$gateway, # default gateway
    [Parameter(Mandatory = $True)][string]$network1, # VM port group name
    [Parameter(Mandatory = $True)][string]$network2, # VM port group name
    [Parameter(Mandatory = $True)][string[]]$vmName, # VM names
    [Parameter(Mandatory = $True)][string[]]$vip, # VIPs for cluster
    [Parameter(Mandatory = $True)][int]$metadataSize, # size of metadata disk
    [Parameter(Mandatory = $True)][int]$dataSize, # size of data disk
    [Parameter(Mandatory = $True)][String[]]$dnsServers, # dns servers
    [Parameter(Mandatory = $True)][String[]]$ntpServers, # ntp servers
    [Parameter(Mandatory = $True)][string]$clusterName, # Cohesity cluster name
    [Parameter(Mandatory = $True)][string]$clusterDomain, # DNS domain of Cohesity cluster
    [Parameter()][switch]$encrypt, #set cluster-level encryption
    [Parameter()][switch]$fips, # set fips mode encryption
    [Parameter(Mandatory = $True)][string]$viServer, # vCenter to connect to
    [Parameter(Mandatory = $True)][string[]]$viHost, # vSphere hosts to deploy OVA to
    [Parameter(Mandatory = $True)][string[]]$viDataStore, # vSphere datastores to deploy OVA to
    [Parameter(Mandatory = $True)][string]$ovfPath, # path to ova file
    [Parameter()][string]$licenseKey = $null, # Cohesity license key
    [Parameter()][switch]$accept_eula
)

if($encrypt){
    $encryption = $true
}else{
    $encryption = $false
}

if($fips){
    $fipsmode = $true
}else{
    $fipsmode = $false
}

. .\cohesity-deploy-api.ps1
$REPORTAPIERRORS = $false

# connect to vCenter
write-host "Connecting to vCenter..."

$null = Connect-VIServer -Server $viServer -Force -WarningAction SilentlyContinue

# validate input parameters
if($ip.count -lt 3){
    write-warning 'Please specify at least 3 IP addresses'
    exit
}
if($vmName.count -ne $ip.count -or 
   $viHost.count -ne $ip.count -or 
   $viDataStore.count -ne $ip.count -or
   $vip.count -ne $ip.count){
    write-warning 'Please provide the same number of IPs, VIPs, vmNames, viHosts and viDatastores'
    exit
}

0..($ip.count-1) | foreach {

    $nodeIndex = $_

    # set OVA configuration
    $ovfConfig = Get-OvfConfiguration -Ovf $ovfPath
    $ovfConfig.Common.dataIp.Value = $ip[$nodeIndex]
    $ovfConfig.Common.dataNetmask.Value = $netmask
    $ovfConfig.Common.dataGateway.Value = $gateway
    $ovfConfig.DeploymentOption.Value = 'small'
    $ovfConfig.IpAssignment.IpProtocol.Value = 'IPv4'
    $ovfConfig.NetworkMapping.DataNetwork.Value = $network1
    $ovfConfig.NetworkMapping.SecondaryNetwork.Value = $network2 

    # deploy OVA
    write-host "Deploying OVA (node $($nodeIndex + 1) of $($ip.count))..."

    $VMHost = Get-VMHost -Name $viHost[$nodeIndex]
    $datastore = Get-Datastore -Name $viDataStore[$nodeIndex]
    $diskformat = 'Thin'
    $null = Import-VApp -Source $ovfPath -OvfConfiguration $ovfConfig -Name $vmName[$nodeIndex] -VMHost $VMHost -Datastore $datastore -DiskStorageFormat $diskformat -Confirm:$false -Force

    # add data and metadata disks
    $VM = get-vm -Name $vmName[$nodeIndex]
    $null = New-HardDisk -CapacityGB $metadataSize -Confirm:$false -StorageFormat $diskformat -VM $VM -Controller "SCSI Controller 1" -Persistence IndependentPersistent -WarningAction SilentlyContinue
    $null = New-HardDisk -CapacityGB $dataSize -Confirm:$false -StorageFormat $diskformat -VM $VM -Controller "SCSI Controller 2" -Persistence IndependentPersistent -WarningAction SilentlyContinue

    # power on VM
    $null = Start-VM $VM

}

$clusterBringupParams = @{
    "clusterName" = $clusterName;
    "ntpServers" = $ntpServers;
    "dnsServers" = $dnsServers;
    "domainNames" = @(
        $clusterDomain
    );
    "clusterGateway" = $gateway;
    "clusterSubnetCidrLen" = $netmask;
    "ipmiGateway" = $null;
    "ipmiSubnetCidrLen" = $null;
    "ipmiUsername" = $null;
    "ipmiPassword" = $null;
    "enableEncryption" = $encryption;
    "rotationalPolicy" = 90;
    "enableFipsMode" = $fipsmode;
    "nodes" = @();
    "clusterDomain" = $clusterDomain;
    "vips" = $vip;
    "hostname" = $clusterName
}

# wait for startup
Write-Host "Waiting for VMs to boot..."

apidrop -quiet
while($AUTHORIZED -eq $false){
    apiauth $ip[0] admin -quiet
    if($AUTHORIZED -eq $false){
        Start-Sleep -Seconds 10
    }
}

$nodeCount = 0
while($nodeCount -lt $ip.count){
    $nodecount = 0
    $nodes = api get /nexus/avahi/discover_nodes
    foreach($freenode in $nodes.freeNodes){
        if($freenode.ipAddresses[0] -in $ip){
            $nodecount += 1
        }
    }
    # "{0} of {1} freenodes found" -f ($nodeCount, $ip.count)

    if($nodecount -lt $ip.count){
        sleep 10
    }else{
        foreach($freenode in $nodes.freeNodes){
            if($freenode.ipAddresses[0] -in $ip){
                $clusterBringupParams.nodes += @{
                    'id' = $freenode.nodeId;
                    'ip' = $freenode.ipAddresses[0];
                    'ipmiIp' = ''
                }
            }
        }        
    }
}


# perform cluster setup
write-host "Performing cluster setup..."

$result = api post /nexus/cluster/virtual_robo_create $clusterBringupParams

### wait for cluster to come online

apidrop -quiet
while($AUTHORIZED -eq $false){
    apiauth $ip[0] admin -quiet
    if($AUTHORIZED -eq $false){
        Start-Sleep -Seconds 10
    }
}

$clusterId = $null
while($null -eq $clusterId){
    Start-Sleep -Seconds 10
    apiauth $ip[0] admin -quiet
    if($AUTHORIZED -eq $true){
        $clusterId = (api get cluster).id
    }
}

write-host "New clusterId is $clusterId"
apidrop -quiet

# wait for startup
write-host "Waiting for cluster setup to complete..."

$synced = $false
while($synced -eq $false){
    Start-Sleep -Seconds 10
    apiauth $ip[0] admin -quiet
    if($AUTHORIZED -eq $true){
        $stat = api get /nexus/cluster/status
        if($stat.isServiceStateSynced -eq $true){
            $synced = $true
        }
    }    
}


if($accept_eula -and $licenseKey){
    # accept eula and enter license key
    write-host "Accepting eula and applying license key..."

    $signTime = (dateToUsecs (get-date))/1000000

    $myObject = @{
        "signedVersion" = 2;
        "signedByUser" = "admin";
        "signedTime" = [Int64]$signTime;
        "licenseKey" = "$licenseKey"
    }

    apidrop -quiet
    while($AUTHORIZED -eq $false){
        apiauth $ip[0] admin -quiet
        $null = api post /licenseAgreement $myObject
        if($AUTHORIZED -eq $false){
            Start-Sleep -Seconds 10
        }
    }
}

write-host "Cluster Deployment Complete!"

