# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][string]$clusterName = $null,           # helios cluster to access 
    [Parameter(Mandatory = $True)][string]$serverName,   # protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$dbName        # name of the source DB we want to restore
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# handle source instance name e.g. instance/dbname
if($dbName.Contains('/')){
    $instanceName, $sourceDB = $sourceDB.Split('/')
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
}
