# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,      # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local',          # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName   # job to run
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# find migration job
$jobs = api get protectionJobs?onlyReturnDataMigrationJobs=true
$job = $jobs | Where-Object name -eq $jobName
if(!$job){
    Write-Host "Migration job $jobName not found!" -ForegroundColor Yellow
    exit 1
}

$runParams = @{
    "copyRunTargets" = @();
    "runNowParameters" = @()
}

Write-Host "Running migration job $jobName..."
$null = api post "protectionJobs/run/$($job.id)" $runParams
exit 0
