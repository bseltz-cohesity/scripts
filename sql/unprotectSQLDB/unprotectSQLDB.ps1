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
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$jobname,
    [Parameter(Mandatory = $True)][string]$servername,
    [Parameter()][string]$instancename = 'MSSQLSERVER',
    [Parameter(Mandatory = $True)][string]$dbname
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName -and $_.isDeleted -ne $True}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

$sources = api get protectionSources?environments=kSQL

$server = $sources.nodes | Where-Object {$_.protectionSource.name -eq $servername}
if(!$server){
    Write-Warning "Server $servername not found!"
    exit
}
$serverId = $server.protectionSource.id

$instance = $server.applicationNodes | Where-Object {$_.protectionSource.name -eq $instancename}
if(!$instance){
    Write-Warning "Instance $instancename not found!"
    exit
}

$db = $instance.nodes | Where-Object {$_.protectionSource.name -eq "$instancename/$dbname"}
if(!$db){
    Write-Warning "Database $instancename/$dbname not found!"
    exit
}
$dbId = $db.protectionSource.id

$job.sourceIds = @(($job.sourceIds + $serverId) | Sort-Object -Unique)

if(! $job.PSObject.Properties['sourceSpecialParameters']){
    setApiProperty -object $job -name 'sourceSpecialParameters' -value @()
}
$sourceSpecialParameter = $job.sourceSpecialParameters | Where-Object {$_.sourceId -eq $serverId }
if($sourceSpecialParameter){
    $sourceSpecialParameter.sqlSpecialParameters.applicationEntityIds  = @($sourceSpecialParameter.sqlSpecialParameters.applicationEntityIds | Where-Object {$_ -ne $dbId})
    $sourceSpecialParameter.sqlSpecialParameters.applicationEntityIds = @($sourceSpecialParameter.sqlSpecialParameters.applicationEntityIds | Where-Object {$_ -in $instance.nodes.protectionSource.id})
}
write-host "Removing $instancename/$dbname from protection job $jobname..."
$null = api put "protectionJobs/$($job.id)" $job
