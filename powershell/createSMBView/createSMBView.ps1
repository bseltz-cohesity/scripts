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
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain',  # name of storage domain in which to create view
    [Parameter()][array]$fullControl,                 # list of users to grant full control
    [Parameter()][array]$readWrite,                   # list of users to grant read/write
    [Parameter()][array]$readOnly,                    # list of users to grant read-only
    [Parameter()][array]$modify,                      # list of users to grant modify
    [Parameter()][switch]$setSharePermissions,        # apply ACLs to share permissions also
    [Parameter()][int64]$quotaLimitGB = 0,            # quota Limit in GiB
    [Parameter()][int64]$quotaAlertGB = 0,            # quota alert threshold in GiB
    [Parameter()][ValidateSet('BackupTarget', 'FileServices')][string]$category = 'FileServices',
    [Parameter()][ValidateSet('Backup Target Low','Backup Target High','TestAndDev High','TestAndDev Low')][string]$qosPolicy = 'TestAndDev High'
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

### find storage domain
$sd = api get viewBoxes | Where-Object name -eq $storageDomain
if($sd){
    $sdId = $sd[0].id
}else{
    Write-Warning "Storage domain $storageDomain not found"
    exit 1
}

### define new view
$newView = @{
    "enableSmbAccessBasedEnumeration" = $true;
    "enableSmbViewDiscovery" = $true;
    "fileDataLock" = @{
        "lockingProtocol" = "kSetReadOnly"
    };
    "fileExtensionFilter" = @{
        "isEnabled" = $false;
        "mode" = "kBlacklist";
        "fileExtensionsList" = @()
    };
    "securityMode" = "kNativeMode";
    "sharePermissions" = @(
        @{
            "sid" = "S-1-1-0";
            "access" = "kFullControl";
            "mode" = "kFolderSubFoldersAndFiles";
            "type" = "kAllow"
        }
    );
    "smbPermissionsInfo" = @{
        "ownerSid" = "S-1-5-32-544";
        "permissions" = @()
    };
    "protocolAccess" = "kSMBOnly";
    "subnetWhitelist" = @();
    "qos" = @{
        "principalName" = $qosPolicy
    };
    "viewBoxId" = $sdId;
    "caseInsensitiveNamesEnabled" = $true;
    "storagePolicyOverride" = @{
        "disableInlineDedupAndCompression" = $false
    };
    "name" = $viewName
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

### add permissions
function addPermission($user, $perms){
    $domain, $domainuser = $user.split('\')
    $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
    if($principal){
        $permission = @{
            "sid" = $principal.sid;
            "type" = "kAllow";
            "mode" = "kFolderSubFoldersAndFiles";
            "access" = $perms
        }
        $newView.smbPermissionsInfo.permissions += $permission
        if($setSharePermissions){
            $sharePermission = @{
                "sid" = $principal.sid;
                "type" = "kAllow";
                "access" = $perms
            }
            $newView.sharePermissions = @($newView.sharePermissions + $sharePermission)
        }
    }else{
        Write-Warning "User $user not found"
        exit 1
    }    
}

if($setSharePermissions){
    $newView.sharePermissions = @()
}

foreach($user in $readWrite){
    addPermission $user 'kReadWrite'
}

foreach($user in $fullControl){
    addPermission $user 'kFullControl'
}

foreach($user in $readOnly){
  addPermission $user 'kReadOnly'
}

foreach($user in $modify){
  addPermission $user 'kModify'
}

if($newView.smbPermissionsInfo.permissions.Count -eq 0){
    $newView.sharePermissions = @($newView.sharePermissions + @{
        "sid" = "S-1-1-0";
        "type" = "kAllow";
        "mode" = "kFolderSubFoldersAndFiles";
        "access" = "kFullControl"
    })
}

### create the view
"Creating view $viewName..."
$thisView = api post views $newView
# $thisView
$v2View = api get -v2 file-services/views?viewIds=$($thisView.viewId)
# $v2View.views
$v2View.views[0].category = $category
$null = api put -v2 file-services/views/$($thisView.viewId) $v2View.views[0]
