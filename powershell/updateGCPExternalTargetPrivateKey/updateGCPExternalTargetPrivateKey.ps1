# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory=$True)][string]$targetName,
    [Parameter(Mandatory=$True)][string]$privateKey
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$vault = api get vaults | Where-Object {$_.name -eq $targetName -and $_.externalTargetType -eq 'kGoogle'}
if(! $vault){
    Write-Host "External target $targetName not found" -ForegroundColor Yellow
    exit 1
}

Write-Host "updating private key for $targetName..."
$privateKey = $privateKey.replace("\n", "`n")
setApiProperty -object $vault.config.google -name clientPrivateKey -value $privateKey
$result = api put vaults/$($vault.id) $vault
