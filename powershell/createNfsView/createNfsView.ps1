### Usage:
# ./createNfsView.ps1 -vip mycluster `
#                     -username myuser `
#                     -domain mydomain.net `
#                     -viewName myview `
#                     -readWrite 192.168.1.7/32, 192.168.1.8/32 `
#                     -readOnly 192.168.1.0/24 `
#                     -rootSquash

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',           # local or AD domain
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain', # name of storage domain to store view in
    [Parameter()][switch]$rootSquash, # whether whitelist entries should use root squash
    [Parameter()][array]$readWrite, # list of cidr's to add to whitelist (e.g. 192.168.1.7/32) with read/write access
    [Parameter()][array]$readOnly, # list of cidr's to add to whitelist (e.g. 192.168.1.0/24) with read/only access
    [Parameter()][ValidateSet("Backup Target Low","Backup Target High","TestAndDev High","TestAndDev Low")][string]$qosPolicy = 'TestAndDev High'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

if($rootSquash){
    $nfsRootSquash = $True
}else{
    $nfsRootSquash = $false
}

### find storage domain
$sd = api get viewBoxes | Where-Object name -eq $storageDomain
if($sd){
    $sdId = $sd[0].id
}else{
    Write-Warning "Storage domain $storageDomain not found"
    exit 1
}

function netbitsToDDN($netBits){
    $maskBits = '1' * $netBits + '0' * (32 - $netBits)
    $octet1 = [convert]::ToInt32($maskBits.Substring(0,8),2)
    $octet2 = [convert]::ToInt32($maskBits.Substring(8,8),2)
    $octet3 = [convert]::ToInt32($maskBits.Substring(16,8),2)
    $octet4 = [convert]::ToInt32($maskBits.Substring(24,8),2)
    return "$octet1.$octet2.$octet3.$octet4"
}

function newWhiteListEntry($cidr, $nfsAccess){
    $ip, $netbits = $cidr -split '/'
    $maskDDN = netbitsToDDN $netbits
    $whitelistEntry = @{
        "nfsAccess" = $nfsAccess;
        "nfsRootSquash" = $nfsRootSquash;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    return $whitelistEntry
}

### build subnetWhiteList
$subnetWhitelist = @()
foreach($cidr in $readWrite){
    $subnetWhitelist += newWhiteListEntry $cidr 'kReadWrite'
}
foreach($cidr in $readOnly){
    $subnetWhitelist += newWhiteListEntry $cidr 'kReadOnly'
}

$viewParams = @{
    "caseInsensitiveNamesEnabled"     = $false;
    "enableNfsViewDiscovery"          = $true;
    "fileExtensionFilter"             = @{
        "isEnabled"          = $false;
        "mode"               = "kBlacklist";
        "fileExtensionsList" = @()
    };
    "nfsRootPermissions"              = @{
        "uid"  = 0;
        "gid"  = 0;
        "mode" = 493
    };
    "overrideGlobalWhitelist"         = $true;
    "protocolAccess"                  = "kNFSOnly";
    "securityMode"                    = "kNativeMode";
    "qos"                             = @{
        "principalName" = $qosPolicy
    };
    "viewBoxId"                       = $sdId;
    "name"                            = $viewName
}

if($subnetWhitelist.Count -gt 0){
    $viewParams['subnetWhitelist'] = $subnetWhitelist 
}

"Creating view $viewName"
$null = api post views $viewParams
