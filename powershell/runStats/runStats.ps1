### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### find protectionRuns that are older than daysToKeep
"Collecting Job Run Statistics..."
foreach ($job in ((api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId })) {
    "Runs for $($job.name)"
    $jobId = $job.id
    $runs = api get protectionRuns?jobId=$($job.id)`&numRuns=99999`&excludeTasks=true`&excludeNonRestoreableRuns=true
    $runs | Select-Object -Property @{Name="Run Date"; Expression={usecsToDate $_.backupRun.stats.startTimeUsecs}}, 
                                    @{Name="MB Read"; Expression={[math]::Round(($_.backupRun.stats.totalBytesReadFromSource)/(1024*1024))}},
                                    @{Name="MB Written"; Expression={[math]::Round(($_.backupRun.stats.totalPhysicalBackupSizeBytes)/(1024*1024))}} | ft 
}                                                                                           
