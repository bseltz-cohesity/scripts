# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$serverName,   # protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$dbName        # name of the source DB we want to restore
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# handle source instance name e.g. instance/dbname
if($dbName.Contains('/')){
    $instanceName, $dbName = $dbName.Split('/')
}else{
    $instanceName = 'MSSQLSERVER'
}

$sources = api get "protectionSources/registrationInfo?environments=kSQL&includeApplicationsTreeInfo=false"
$serverSourceRootNode = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $servername}
if(! $serverSourceRootNode){
    Write-Host "Server $servername not found!" -ForegroundColor Yellow
    exit 1
}
$server = api get "protectionSources?id=$($serverSourceRootNode.rootNode.id)"
# $sources = api get protectionSources?environments=kSQL

# $server = $sources[0].nodes | Where-Object {$_.protectionSource.name -eq $serverName}
# if(! $server){
#     Write-Host "Server $serverName not found" -ForegroundColor Yellow
#     exit
# }

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
    # $database.protectionSource.sqlProtectionSource | toJson
}
