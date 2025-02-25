# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][string]$targetUser = $sourceUser,
    [Parameter()][string]$targetDomain = $sourceDomain,
    [Parameter()][switch]$useApiKeys,
    [Parameter()][switch]$promptForMfaCode
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$cacheFile = "$($sourceCluster)-Config.json"
if(Test-Path -Path $cacheFile -PathType Leaf){
    "`nUsing cached security config from source cluster $sourceCluster..."
    $config = Get-Content -Path $cacheFile | ConvertFrom-Json
}else{
    "`nConnecting to source cluster $sourceCluster..."
    $mfaCode = $null
    if($promptForMfaCode){
        $mfaCode = Read-Host -Prompt 'Please Enter MFA Code'
    }
    apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -apiKeyAuthentication $useApiKeys -mfaCode $mfaCode -quiet

    # get certs
    Write-Host "Getting security config"
    $config = api get -v2 security-config
    $config | toJson | Out-File -FilePath $cacheFile
}

"`nConnecting to target cluster $targetCluster..."
$mfaCode = $null
if($promptForMfaCode){
    $mfaCode = Read-Host -Prompt 'Please Enter MFA Code'
}
apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -apiKeyAuthentication $useApiKeys -mfaCode $mfaCode -quiet

$cacheFile = "$($targetCluster)-Config.json"

# backup original certs
$origConfig = api get -v2 security-config
if(! (Test-Path -Path $cacheFile -PathType Leaf)){
    $origConfig | toJson | Out-File -FilePath $cacheFile
}

# copy new certs
Write-Host "Copying security config"
$null = api put -v2 security-config $config
