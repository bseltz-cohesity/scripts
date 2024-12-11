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
    [Parameter(Mandatory = $True)][string]$serverName,   # protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$dbName        # name of the source DB we want to restore
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

# handle source instance name e.g. instance/dbname
if($dbName.Contains('/')){
    $instanceName, $dbName = $dbName.Split('/')
}else{
    $instanceName = 'MSSQLSERVER'
}

$sources = api get protectionSources?environments=kSQL

$server = $sources[0].nodes | Where-Object {$_.protectionSource.name -eq $serverName}
if(! $server){
    Write-Host "Server $serverName not found" -ForegroundColor Yellow
    exit
}

$instance = $server.applicationNodes | Where-Object {$_.protectionSource.name -eq $instanceName}
if(! $instance){
    Write-Host "Instance $instanceName not found" -ForegroundColor Yellow
    exit
}

$database = $instance.nodes | Where-Object {$_.protectionSource.name -eq "$instanceName/$dbName"}
if(! $database){
    Write-Host "Database $dbName not found" -ForegroundColor Yellow
    exit
}else{
    $database.protectionSource.sqlProtectionSource.dbFiles | Format-Table
    $database.protectionSource.sqlProtectionSource | toJson
}
