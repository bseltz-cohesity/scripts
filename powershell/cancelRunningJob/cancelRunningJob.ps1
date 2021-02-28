### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][string]$jobName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')

$jobs = api get protectionJobs | Where-Object {$_.isActive -ne $false -and $_.isDeleted -ne $True}
$job = $jobs | Where-Object name -eq $jobName
if(!$job){
   Write-Host "$jobName not found" -ForegroundColor Yellow
   exit 1
}

$run = api get "protectionRuns?numRuns=1&excludeTasks=true&jobId=$($job.id)"
if ($run.backupRun.status -notin $finishedStates){
   "Cancelling {0}: {1}..." -f $job.name, (usecsToDate $run.backupRun.stats.startTimeUsecs)
   $null = api post "protectionRuns/cancel/$($job.id)" @{"jobRunId"= $run.backupRun.jobRunId;}
}else{
   "{0} not running" -f $job.name
}

