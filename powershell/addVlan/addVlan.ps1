### usage: ./addVLAN.ps1 -cluster mycluster `
#                        -username myuser `
#                        -domain mydomain.net `
#                        -vlanId 60 `
#                        -cidr 192.168.60.0/24 `
#                        -vip 192.168.60.2, 192.168.60.3, 192.168.60.4 `
#                        -gateway 192.168.60.254 `
#                        -hostname mycluster.net60.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$cluster,   # cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username,  # cohesity username
    [Parameter()][string]$domain = 'local',           # user domain
    [Parameter()][int]$vlanId = $null,                # VLAN ID to create
    [Parameter()][string]$interface = 'bond0',        # interface to use
    [Parameter()][string]$cidr = $null,               # CIDR of new VLAN
    [Parameter()][array]$vip = $null,                 # List of VIPs to add for new VLAN
    [Parameter()][string]$hostname = $null,           # Optional hostname of cluster on new VLAN
    [Parameter()][string]$gateway = $null,            # Optional gateway on new VLAN
    [Parameter()][string]$configFile = $null,         # Optional config file to provide parameters
    [Parameter()][switch]$delete                      # remove the vlan and vips
)

# read config file if specified
if($configFile -and (Test-Path $configFile -PathType Leaf)){
    . $configFile
}

# confirm all required inputs
if(! $vlanId){
    write-host "vlanId required!" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $cluster -username $username -domain $domain

# get interfaces
$iflist = api get /nexus/node/list_network_interfaces
$iface = $iflist.networkInterfaces | Where-Object ifaceName -eq $interface
if(!$iface){
    Write-Host "Interface $interface not found!" -ForegroundColor Yellow
    exit
}

if($delete){
    if($iface.PSObject.properties['ifaceGroup']){
        $deleteParams = @{
            "ifaceGroupName" = "$($iface.ifaceGroup).$vlanId"
        }
    }else{
        $deleteParams = @{
            "ifaceGroupName" = "$($iface.ifaceName).$vlanId"
        }
    }
    Write-Host "Deleting vlan $vlanId"
    $null = api delete vlans/$vlanId $deleteParams
    exit
}

if(! $cidr){
    write-host "cidr required!" -ForegroundColor Yellow
    exit
}

if(! $vip){
    write-host "at least one vip required!" -ForegroundColor Yellow
    exit
}

# parse cidr
$network, $prefix = $cidr.Split('/')
if(! $network -or ! $prefix){
    write-host "Invalid CIDR format!" -ForegroundColor Yellow
    exit
}

"Adding VLAN $vlanId..."

# new vlan object
$newVlan = @{
    "id"            = $vlanId;
    "subnet"        = @{
        "ip"          = $network;
        "netmaskBits" = [int]$prefix
    };
    "ips"           = @();
}

# add vips to vlan object
foreach($ip in $vip){
    $newVlan.ips += $ip
}

# add optional gateway
if($gateway){
    $newVlan['gateway'] = $gateway
}

# add optional hostname
if($hostname){
    $newVlan['hostname'] = $hostname
}

# handle different versions of Cohesity
$addToPartition = $false
if($iface.PSObject.properties['ifaceGroup']){
    $newVlan['ifaceGroupName'] = "$($iface.ifaceGroup).$vlanId"
    $newVlan['vlanName'] = "$($iface.ifaceGroup).$vlanId"
}else{
    $newVlan['interfaceName'] = $iface.ifaceName
    $newVlan['vlanName'] = "$($iface.ifaceName).$vlanId"
    $addToPartition = $True
}

# save new vlan
$null = api put vlans/$vlanId $newVlan

# for older versions of Cohesity, add new vlan to cluater partition
if($addToPartition -eq $True){
    "adding to partitions"
    $partitions = api get clusterPartitions
    $vlans = api get vlans
    $partitions[0].vlans = $vlans
    foreach($ip in $vip){
        $partitions[0].vlanIps += $ip
    }
    $null = api put "/clusterPartitions/$($partitions[0].id)" $partitions[0]
}

