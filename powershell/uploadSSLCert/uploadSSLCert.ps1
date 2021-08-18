[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #cohesity username
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$certFile,
    [Parameter(Mandatory = $True)][string]$keyFile
)

if(Test-Path -Path $certFile -PathType Leaf){
    $certData = Get-Content $certFile -Raw
}else{
    write-host "Cert File not found!" -ForegroundColor Yellow
    exit 1
}

if(Test-Path -Path $keyFile -PathType Leaf){
    $keyData = Get-Content $keyFile -Raw
}else{
    write-host "Key File not found!" -ForegroundColor Yellow
    exit 1
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster

$sslparams = @{
    "certificate" = [string]$certData;
    "lastUpdateTimeMsecs" = 0;
    "privateKey" = [string]$keyData
}

Write-Host "Updating SSL certificate on $($cluster.name)..."
$null = api put certificates/webServer $sslparams

$restartParams = @{
    "clusterId" = $cluster.id;
    "services" = @("iris")
}

Write-Host "Restarting IRIS service..."
$null = api post /nexus/cluster/restart $restartParams
