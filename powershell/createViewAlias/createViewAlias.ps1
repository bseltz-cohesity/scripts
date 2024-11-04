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
    [Parameter(Mandatory = $True)][string]$aliasName, # name of view to create
    [Parameter()][string]$folderPath = '/',           # relative path of alias
    [Parameter()][array]$fullControl,                 # list of users to grant full control
    [Parameter()][array]$readWrite,                   # list of users to grant read/write
    [Parameter()][array]$readOnly,                    # list of users to grant read-only
    [Parameter()][array]$modify                       # list of users to grant modify
)

# source the cohesity-api helper code
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

# add permission function
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
        return $permission
    }else{
        Write-Host "User $user not found" -ForegroundColor Yellow
        exit 1
    }    
}

$view = api get "views/$viewName"
if(!$view){
    Write-Host "View $viewName not found" -ForegroundColor Yellow
    exit
}

$newAlias = @{
    "viewName" = $view.name;
    "viewPath" = $folderPath;
    "aliasName" = $aliasName;
    "sharePermissions" = @()
}

foreach($user in $readWrite){
    $newAlias.sharePermissions += addPermission $user 'kReadWrite'
}

foreach($user in $fullControl){
    $newAlias.sharePermissions += addPermission $user 'kFullControl'
}

foreach($user in $readOnly){
    $newAlias.sharePermissions += addPermission $user 'kReadOnly'
}

foreach($user in $modify){
    $newAlias.sharePermissions += addPermission $user 'kModify'
}

Write-Host "Creating view alias $aliasName -> $($view.name)$folderPath"
$null = api post viewAliases $newAlias
