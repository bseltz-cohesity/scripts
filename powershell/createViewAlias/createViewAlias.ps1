### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',           # local or AD domain
    [Parameter(Mandatory = $True)][string]$viewName,  # name of view to create
    [Parameter(Mandatory = $True)][string]$aliasName,  # name of view to create
    [Parameter()][string]$folderPath = '/'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$view = api get "views/$viewName"
if(!$view){
    Write-Host "View $viewName not found" -ForegroundColor Yellow
    exit
}

$newAlias = @{
    "viewName" = $view.name;
    "viewPath" = $folderPath;
    "aliasName" = $aliasName;
    "sharePermissions" = @($view.sharePermissions)
    "subnetWhitelist" = @($view.subnetWhitelist)
}

Write-Host "Creating view alias $aliasName -> $($view.name)$folderPath"
$null = api post viewAliases $newAlias
