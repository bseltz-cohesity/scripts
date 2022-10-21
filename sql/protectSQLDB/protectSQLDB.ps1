# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$jobname,
    [Parameter(Mandatory = $True)][string]$servername,
    [Parameter()][string]$instancename = 'MSSQLSERVER',
    [Parameter(Mandatory = $True)][string]$dbname
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

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
if(!$sourceSpecialParameter){
    $job.sourceSpecialParameters += @{"sourceId" = $serverId; "sqlSpecialParameters" = @{"applicationEntityIds" = @($dbId)}}
}else{
    $sourceSpecialParameter.sqlSpecialParameters.applicationEntityIds += $dbId
    $sourceSpecialParameter.sqlSpecialParameters.applicationEntityIds = @($sourceSpecialParameter.sqlSpecialParameters.applicationEntityIds | Where-Object {$_ -in $instance.nodes.protectionSource.id})
}
write-host "Adding $instancename/$dbname to protection job $jobname..."
$null = api put "protectionJobs/$($job.id)" $job
