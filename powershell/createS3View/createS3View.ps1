### usage: ./createSMBView.ps1 -vip mycluster -username myusername -domain mydomain.net -viewName newview1 -readWrite mydomain.net\server1 -fullControl mydomain.net\admingroup1 -qosPolicy 'TestAndDev High' -storageDomain mystoragedomain

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
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][string]$owner,
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain',  # name of storage domain in which to create view
    [Parameter()][array]$allowList,                   # one or more CIDR address e.g. 192.168.2.0/24, 192.168.2.11/32
    [Parameter()][switch]$caseSensitive,              # enable view case sensitive file names
    [Parameter()][switch]$showKeys,                   # show access keys
    [Parameter()][int64]$quotaLimitGB = 0,            # quota Limit in GiB
    [Parameter()][int64]$quotaAlertGB = 0,            # quota alert threshold in GiB
    [Parameter()][ValidateSet('BackupTargetLow','BackupTargetHigh','TestAndDevHigh','TestAndDevLow')][string]$qosPolicy = 'TestAndDevHigh'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

if($USING_HELIOS){
    if(!$owner){
        Write-Host "Owner is required when connection through Helios" -ForegroundColor Yellow
        exit 1
    }
    $users = api get -v2 users
    $thisOwner = $users.users | Where-Object {$_.s3AccountParams.s3AccountId -eq $owner}
    if(!$thisOwner){
        Write-Host "Owner $owner not found" -ForegroundColor Yellow
        exit 1
    }
}

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
    $allowlistEntry = @{
        "nfsAccess" = "kReadWrite";
        "smbAccess" = "kReadWrite";
        "s3Access" = "kReadWrite"
        "nfsRootSquash" = "kNone";
        "ip" = $ip;
        "netmaskBits" = [int]$netbits
    }
    return $allowlistEntry
}

# find storage domain
$sd = api get viewBoxes | Where-Object name -eq $storageDomain
if(!$sd){
    Write-Warning "Storage domain $storageDomain not found"
    exit 1
}

# define new view
$newView = @{
    "enableNfsWcc" = $null;
    "qos" = @{
        "name" = $qosPolicy
    };
    "caseInsensitiveNamesEnabled" = $true;
    "enableSmbViewDiscovery" = $null;
    "securityMode" = "NativeMode";
    "selfServiceSnapshotConfig" = $null;
    "sharePermissions" = @{
        "permissions" = @(
            @{
                "sid" = "S-1-1-0";
                "access" = "FullControl";
                "mode" = "FolderSubFoldersAndFiles";
                "type" = "Allow"
            }
        );
        "superUserSids" = $null
    };
    "smbPermissionsInfo" = @{
        "ownerSid" = "S-1-5-32-544";
        "permissions" = @(
            @{
                "sid" = "S-1-1-0";
                "access" = "FullControl";
                "mode" = "FolderSubFoldersAndFiles";
                "type" = "Allow"
            }
        )
    };
    "storageDomainId" = $sd[0].id;
    "category" = "ObjectServices";
    "protocolAccess" = @(
        @{
            "type" = "S3";
            "mode" = "ReadWrite"
        }
    );
    "isExternallyTriggeredBackupTarget" = $false;
    "name" = $viewName;
    "dataLockExpiryUsecs" = $null;
    "objectServicesMappingConfig" = "ObjectId";
    "mostSecureSettings" = $false;
    "intent" = @{
        "templateId" = 3113;
        "templateName" = "General Object Services"
    };
    "accessSids" = $null;
    "aclConfig" = $null;
    "antivirusScanConfig" = @{
        "isEnabled" = $false;
        "blockAccessOnScanFailure" = $false;
        "maximumScanFileSize" = 26214400;
        "scanFilter" = @{
            "isEnabled" = $false;
            "mode" = $null;
            "fileExtensionsList" = @()
        };
        "prefixScanFilter" = @{
            "isEnabled" = $false;
            "mode" = $null;
            "fileExtensionsList" = @()
        };
        "s3TaggingFilter" = @{
            "isEnabled" = $false;
            "mode" = $null;
            "tagSet" = @()
        };
        "scanOnAccess" = $false;
        "scanOnClose" = $true;
        "scanOnPut" = $false;
        "scanTimeoutUsecs" = 180000000
    };
    "description" = $null;
    "enableFastDurableHandle" = $false;
    "enableFilerAuditLogging" = $null;
    "enableOfflineCaching" = $null;
    "enableSmbAccessBasedEnumeration" = $null;
    "enableSmbEncryption" = $null;
    "enableSmbLeases" = $null;
    "enableSmbOplock" = $null;
    "enforceSmbEncryption" = $null;
    "fileExtensionFilter" = @{
        "isEnabled" = $false;
        "mode" = "Blacklist";
        "fileExtensionsList" = @()
    };
    "fileLockConfig" = $null;
    "filerLifecycleManagement" = $null;
    "logicalQuota" = $null;
    "netgroupWhitelist" = @{
        "nisNetgroups" = $null
    };
    "nfsAllSquash" = $null;
    "nfsRootSquash" = $null;
    "overrideGlobalNetgroupWhitelist" = $null;
    "overrideGlobalSubnetWhitelist" = $true;
    "ownerInfo" = $null;
    "s3FolderSupportEnabled" = $false;
    "storagePolicyOverride" = $null;
    "subnetWhitelist" = $null;
    "viewPinningConfig" = @{
        "enabled" = $false;
        "pinnedTimeSecs" = -1;
        "lastUpdatedTimestampSecs" = $null
    };
    "viewProtectionConfig" = $null;
    "enableAppAwarePrefetching" = $null;
    "enableAppAwareUptiering" = $null;
    "enableNfsViewDiscovery" = $null;
    "enableNfsUnixAuthentication" = $null;
    "enableNfsKerberosAuthentication" = $null;
    "enableNfsKerberosIntegrity" = $null;
    "enableNfsKerberosPrivacy" = $null;
    "nfsRootPermissions" = $null;
    "enableAbac" = $null;
    "lifecycleManagement" = $null;
    "versioning" = "UnVersioned"
}

if($USING_HELIOS){
    $newView['ownerInfo'] = @{"userId" = $thisOwner.s3AccountParams.s3AccountId}
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
$null = api post -v2 file-services/views $newView

# return S3 keys
if($showKeys){
    if($USING_HELIOS){
        $user = $thisOwner
    }else{
        $user = api get users | Where-Object {$_.username -eq $username -and $_.domain -eq $domain}
    }
    "s3AccessKeyId: {0}" -f $user.s3AccessKeyId
    "  s3SecretKey: {0}" -f $user.s3SecretKey
}
