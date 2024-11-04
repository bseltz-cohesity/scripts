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
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain', # name of storage domain to store view in
    [Parameter()][switch]$rootSquash, # whether allowlist entries should use root squash
    [Parameter()][array]$readWrite, # list of cidr's to add to allowlist (e.g. 192.168.1.7/32) with read/write access
    [Parameter()][array]$readOnly, # list of cidr's to add to allowlist (e.g. 192.168.1.0/24) with read/only access
    [Parameter()][ValidateSet("Backup Target Low","Backup Target High","TestAndDev High","TestAndDev Low")][string]$qosPolicy = 'TestAndDev High'
)

### source the cohesity-api helper code
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

function newAllowListEntry($cidr, $nfsAccess){
    $ip, $netbits = $cidr -split '/'
    $maskDDN = netbitsToDDN $netbits
    $allowlistEntry = @{
        "nfsAccess" = $nfsAccess;
        "nfsRootSquash" = $nfsRootSquash;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    return $allowlistEntry
}

### build subnetAllowList
$subnetAllowlist = @()
foreach($cidr in $readWrite){
    $subnetAllowlist += newAllowListEntry $cidr 'kReadWrite'
}
foreach($cidr in $readOnly){
    $subnetAllowlist += newAllowListEntry $cidr 'kReadOnly'
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

if($subnetAllowlist.Count -gt 0){
    $viewParams['subnetWhitelist'] = $subnetAllowlist 
}

"Creating view $viewName"
$null = api post views $viewParams
