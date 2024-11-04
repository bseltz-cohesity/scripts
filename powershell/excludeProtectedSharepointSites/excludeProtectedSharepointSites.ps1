# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$jobName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get the protection job
$jobs = api get "protectionJobs?environments=kO365Outlook" | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false}
$job = $jobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Host "Job $jobName not found!" -ForegroundColor Yellow
    exit
}
$otherJobs = $jobs | Where-Object {$_.name -ne $jobName}

# get the O365 protection source
$source = api get protectionSources?environments=kO365 | Where-Object {$_.protectionSource.id -eq $job.parentSourceId}

# get unprotected sites
$sites = $source.nodes | Where-Object {$_.protectionSource.office365ProtectionSource.type -eq 'kSites'}
$protectedSites = $sites.nodes | Where-Object {$_.protectionSource.id -in $otherJobs.sourceIds}
$excludeSourceIds = @($protectedSites.protectionSource.id) 

if(!$job.PSObject.Properties['excludeSourceIds']){
    setApiProperty -object $job -name 'excludeSourceIds' -value @($excludeSourceIds)
}else{
    $job.excludeSourceIds = $excludeSourceIds
}

Write-Host "Excluding protected sites from $jobName"
$null = api put "protectionJobs/$($job.id)" $job
