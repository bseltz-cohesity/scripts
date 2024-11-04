### usage: ./createSMBView.ps1 -vip mycluster -username myusername -domain mydomain.net -viewName newview1 -readWrite mydomain.net\server1 -fullControl mydomain.net\admingroup1 -qosPolicy 'TestAndDev High' -storageDomain mystoragedomain

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain',  # name of storage domain in which to create view
    [Parameter()][array]$allowList,                   # one or more CIDR address e.g. 192.168.2.0/24, 192.168.2.11/32
    [Parameter()][switch]$caseSensitive,              # enable view case sensitive file names
    [Parameter()][switch]$showKeys,                   # show access keys
    [Parameter()][int64]$quotaLimitGB = 0,            # quota Limit in GiB
    [Parameter()][int64]$quotaAlertGB = 0,            # quota alert threshold in GiB
    [Parameter()][ValidateSet('Backup Target Low','Backup Target High','TestAndDev High','TestAndDev Low')][string]$qosPolicy = 'TestAndDev High'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# end authentication =========================================

# convert CIDR to DDN
function netbitsToDDN($netBits){
    $maskBits = '1' * $netBits + '0' * (32 - $netBits)
    $octet1 = [convert]::ToInt32($maskBits.Substring(0,8),2)
    $octet2 = [convert]::ToInt32($maskBits.Substring(8,8),2)
    $octet3 = [convert]::ToInt32($maskBits.Substring(16,8),2)
    $octet4 = [convert]::ToInt32($maskBits.Substring(24,8),2)
    return "$octet1.$octet2.$octet3.$octet4"
}

# Create allowlist entry
function newAllowListEntry($cidr){
    $ip, $netbits = $cidr -split '/'
    $maskDDN = netbitsToDDN $netbits
    $allowlistEntry = @{
        "nfsAccess" = "kReadWrite";
        "smbAccess"     = "kReadWrite";
        "nfsRootSquash" = $false;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    return $allowlistEntry
}

# find storage domain
$sd = api get viewBoxes | Where-Object name -eq $storageDomain
if($sd){
    $sdId = $sd[0].id
}else{
    Write-Warning "Storage domain $storageDomain not found"
    exit 1
}

# define new view
$newView = @{
    "caseInsensitiveNamesEnabled"     = $true;
    "enableNfsViewDiscovery"          = $true;
    "enableSmbAccessBasedEnumeration" = $false;
    "enableSmbViewDiscovery"          = $true;
    "fileExtensionFilter"             = @{
        "isEnabled"          = $false;
        "mode"               = "kBlacklist";
        "fileExtensionsList" = @()
    };
    "protocolAccess"                  = "kS3Only";
    "securityMode"                    = "kNativeMode";
    "qos"                             = @{
        "principalName" = $qosPolicy
    };
    "name"                            = $viewName;
    "viewBoxId"                       = $sdId;
}

# case sensitivity
if($caseSensitive){
    $newView.caseInsensitiveNamesEnabled = $false
}

# quota
if ($quotaLimitGB -ne 0 -or $quotaAlertGB -ne 0) {
    $newView['logicalQuota'] = @{ }
    if ($quotaLimitGB -ne 0) {
        $newView.logicalQuota['hardLimitBytes'] = $quotaLimitGB * 1024 * 1024 * 1024
    }
    if ($quotaAlertGB -ne 0) {
        $newView.logicalQuota['alertLimitBytes'] = $quotaAlertGB * 1024 * 1024 * 1024
    }
}

# allowlist
$subnetAllowList = @()
foreach($cidr in $allowList){
    $subnetAllowList += newAllowListEntry $cidr
}

if($subnetAllowList.Count -gt 0){
    $newView['subnetWhitelist'] = $subnetAllowList 
}

# create the view
"Creating view $viewName..."
$null = api post views $newView

# return S3 keys
if($showKeys){
    $user = api get users | Where-Object {$_.username -eq $username -and $_.domain -eq $domain}
    "s3AccessKeyId: {0}" -f $user.s3AccessKeyId
    "  s3SecretKey: {0}" -f $user.s3SecretKey
}
