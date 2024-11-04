
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$ip, # ip address of the node
    [Parameter(Mandatory = $True)][string]$netmask, # subnet mask
    [Parameter(Mandatory = $True)][string]$gateway, # default gateway
    [Parameter(Mandatory = $True)][string]$vmNetwork, # VM port group name
    [Parameter(Mandatory = $True)][string]$vmName, # VM name
    [Parameter(Mandatory = $True)][int]$metadataSize, # size of metadata disk
    [Parameter(Mandatory = $True)][int]$dataSize, # size of data disk
    [Parameter(Mandatory = $True)][String[]]$dnsServers, # dns servers
    [Parameter(Mandatory = $True)][String[]]$ntpServers, # ntp servers
    [Parameter(Mandatory = $True)][string]$clusterName, # Cohesity cluster name
    [Parameter(Mandatory = $True)][string]$clusterDomain, # DNS domain of Cohesity cluster
    [Parameter(Mandatory = $True)][string]$viServer, # vCenter to connect to
    [Parameter(Mandatory = $True)][string]$viHost, # vSphere host to deploy OVA to
    [Parameter(Mandatory = $True)][string]$viDataStore, # vSphere datastore to deploy OVA to
    [Parameter(Mandatory = $True)][string]$ovfPath, # path to ova file
    [Parameter(Mandatory = $True)][string]$licenseKey # Cohesity license key
)

. .\cohesity-api.ps1
$REPORTAPIERRORS = $false

# connect to vCenter
write-host "Connecting to vCenter..."

$null = Connect-VIServer -Server $viServer -Force -WarningAction SilentlyContinue

# set OVA configuration
write-host "Setting OVA configuration..."

$ovfConfig = Get-OvfConfiguration -Ovf $ovfPath
$ovfConfig.Common.dataIp.Value = $ip
$ovfConfig.Common.dataNetmask.Value = $netmask
$ovfConfig.Common.dataGateway.Value = $gateway
$ovfConfig.DeploymentOption.Value = 'small'
$ovfConfig.IpAssignment.IpProtocol.Value = 'IPv4'
$ovfConfig.NetworkMapping.DataNetwork.Value = $vmNetwork
$ovfConfig.NetworkMapping.SecondaryNetwork.Value = $vmNetwork

# deploy OVA
write-host "Deploying OVA..."

$VMHost = Get-VMHost -Name $viHost
$datastore = Get-Datastore -Name $viDataStore
$diskformat = 'Thin'
$null = Import-VApp -Source $ovfPath -OvfConfiguration $ovfConfig -Name $vmName -VMHost $VMHost -Datastore $datastore -DiskStorageFormat $diskformat -Confirm:$false -Force

# add data and metadata disks
write-host "Adding data disks to VM..."

$VM = get-vm -Name $vmName
$null = New-HardDisk -CapacityGB $metadataSize -Confirm:$false -StorageFormat $diskformat -VM $VM -WarningAction SilentlyContinue
$null = New-HardDisk -CapacityGB $dataSize -Confirm:$false -StorageFormat $diskformat -VM $VM -WarningAction SilentlyContinue

# power on VM
write-host "Powering on VM..."

$null = Start-VM $VM

# wait for startup
Write-Host "Waiting for VM to boot..."

apidrop -quiet
while($AUTHORIZED -eq $false){
    apiauth $ip admin -quiet
    if($AUTHORIZED -eq $false){
        Start-Sleep -Seconds 10
    }
}
apidrop -quiet

# perform cluster setup
write-host "Performing cluster setup..."

$cluster = $null
$clusterId = $null
while($cluster.length -eq 0){
    apiauth $ip admin -quiet
    if($AUTHORIZED -eq $true){
        $myObject = @{
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
            "enableEncryption" = $false;
            "rotationalPolicy" = 90;
            "enableFipsMode" = $false;
            "nodes" = @(
                @{
                    "id" = (api get /nexus/node/info).nodeId;
                    "ip" = "$ip";
                    "ipmiIp" = ""
                }
            );
            "clusterDomain" = $clusterDomain;
            "nodeIp" = "$ip";
            "hostname" = $clusterName
        }
        $cluster = api post /nexus/cluster/virtual_robo_create $myObject
        $clusterId = $cluster.clusterId
    }else{
        Start-Sleep -Seconds 10
    }
}
write-host "New clusterId is $clusterId"
apidrop -quiet

# wait for startup
write-host "Waiting for cluster setup to complete..."

$clusterId = $null
while($null -eq $clusterId){
    Start-Sleep -Seconds 10
    apiauth $ip admin -quiet
    $clusterId = (api get cluster).id
}
apidrop -quiet

# accept eula and enter license key
write-host "Accepting eula and applying license key..."

$signTime = (dateToUsecs (get-date))/1000000

$myObject = @{
    "signedVersion" = 1;
    "signedByUser" = "admin";
    "signedTime" = [Int64]$signTime;
    "licenseKey" = "$licenseKey"
}

while($AUTHORIZED -eq $false){
    apiauth $ip admin -quiet
    $null = api post /licenseAgreement $myObject
    if($AUTHORIZED -eq $false){
        Start-Sleep -Seconds 10
    }
}

write-host "VE Deployment Complete"
