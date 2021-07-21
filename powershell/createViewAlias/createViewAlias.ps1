### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',           # local or AD domain
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter(Mandatory = $True)][string]$aliasName, # name of view to create
    [Parameter()][string]$folderPath = '/',           # relative path of alias
    [Parameter()][array]$fullControl,                 # list of users to grant full control
    [Parameter()][array]$readWrite,                   # list of users to grant read/write
    [Parameter()][array]$readOnly,                    # list of users to grant read-only
    [Parameter()][array]$modify                       # list of users to grant modify
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

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
