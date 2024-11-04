### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$sourcePath,
    [Parameter(Mandatory = $True)][string]$targetPath
)

$sourcePath = $sourcePath.Replace('\', '/').Replace('//', '/')
$targetPath = $targetPath.Replace('\', '/').Replace('//', '/')

if($sourcePath.StartsWith('/')){
    $sourcePath = $sourcePath.Substring(1)
}

if($targetPath.StartsWith('/')){
    $targetPath = $targetPath.Substring(1)
}

$targetView, $targetPath = $targetPath.Split('/', 2)

if($targetPath -eq ''){
    Write-Host "targetPath must be a new folder name" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$CloneDirectoryParams = @{
    'destinationDirectoryName' = "$targetPath";
    'destinationParentDirectoryPath' = "/$targetView";
    'sourceDirectoryPath' = "/$sourcePath"
}

"Copying $sourcePath to $targetView/$targetPath..."
$null = api post views/cloneDirectory $CloneDirectoryParams

