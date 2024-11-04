# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory=$True)][string]$remoteCluster,
    [Parameter()][string]$addIp,
    [Parameter()][string]$removeIp
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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

$remotes = api get remoteClusters
$remote = $remotes | Where-Object name -eq $remoteCluster
if(!$remote){
    Write-Host "Remote cluster $remoteCluster not found" -ForegroundColor Yellow
    exit 1
}

if($addIp){
    $remote.remoteIps = @($remote.remoteIps + $addIp)
}

if($removeIp){
    $remote.remoteIps = @($remote.remoteIps | Where-Object {$_ -ne $removeIp})
}

$remote.remoteIps
if($addIp -or $removeIp){
    $null = api put remoteClusters/$($remote.clusterId) $remote
}
