# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][int]$sitesToRemove = 99999
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

# get the O365 protection source
$source = api get protectionSources?environments=kO365 | Where-Object {$_.protectionSource.name -eq $sourceName}
if(!$source){
    Write-Host "Source $sourceName not found!" -ForegroundColor Yellow
    exit
}

# get existing site IDs
$sites = $source.nodes | Where-Object {$_.protectionSource.office365ProtectionSource.type -eq 'kSites'}
$siteIds = $sites.nodes.protectionSource.id
$missingIds = @($job.sourceIds | Where-Object {$_ -notin $siteIds})

if($missingIds){
    $missingIds = @($missingIds[0..$sitesToRemove])
    $job.sourceIds = $job.sourceIds | Where-Object {$_ -in $siteIds} | Sort-Object -Unique
    Write-Host "Removing $($missingIds.Count) missing sourceIds from $jobName"
    $null = api put "protectionJobs/$($job.id)" $job
}else{
    Write-Host "No missing sites in $jobName"
}
