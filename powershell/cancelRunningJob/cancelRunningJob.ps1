### process commandline arguments
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
   [Parameter()][string]$jobName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
   Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
   exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
   Write-Host "Not authenticated" -ForegroundColor Yellow
   exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
   $thisCluster = heliosCluster $clusterName
   if(! $thisCluster){
       exit 1
   }
}
# end authentication =========================================

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

