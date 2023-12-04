# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][ValidateSet('Windows','Linux')][string]$platform = 'Windows',
    [Parameter()][ValidateSet('RPM','DEB','Script','SuseRPM')][string]$packageType = 'RPM'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# end authentication =========================================

$images = api get -mcmv2 data-protect/agents/images?platform=$platform
if($platform -eq 'Linux'){
    $package = $images.agents[0].PlatformSubTypes | Where-Object packageType -eq $packageType
    $downloadURL = $package.downloadURL
    $fileName = ($downloadURL -split '/')[-1]
    Write-Host "Downloading $platform agent ($packageType)..."
}else{
    $downloadURL = $images.agents[0].downloadURL
    $fileName = ($downloadURL -split '/')[-1]
    Write-Host "Downloading $platform agent..."
}

fileDownload -uri $downloadURL -fileName $fileName
Write-Host "Agent downloaded: $fileName"
# $rpmPackage = $images.agents[0].PlatformSubTypes | Where-Object packageType -eq 'RPM'
# fileDownload -uri $rpmPackage.downloadURL -fileName cohesity-agent.rpm               
