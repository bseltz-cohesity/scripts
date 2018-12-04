### usage: ./monitorArchiveTasks.ps1 -vip mycluster -username admin [ -domain local ] [ -olderThan 30 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$olderThan = 0, #archive snapshots older than x days
    [Parameter()][string]$domain = 'local' #local or AD domain
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### olderThan days in usecs
$olderThanUsecs = timeAgo $olderThan days

### find protectionRuns with old local snapshots with archive tasks and sort oldest to newest
"searching for old snapshots..."
foreach ($job in ((api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId })) {
    
    $runs = (api get protectionRuns?jobId=$($job.id)`&excludeTasks=true`&excludeNonRestoreableRuns=true`&numRuns=999999`&runTypes=kRegular`&endTimeUsecs=$olderThanUsecs) | `
        Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
        Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } | `
        Where-Object { 'kArchival' -in $_.copyRun.target.type } | `
        Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

    foreach ($run in $runs) {

        $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
        $jobName = $run.jobName

        ### Display Status of archive task
        foreach ($copyRun in $run.copyRun) {
            if ($copyRun.target.type -eq 'kArchival') {
                if ($copyRun.status -eq 'kSuccess') {
                    write-host "$runDate  $jobName  -> Completed" -ForegroundColor Green
                }
                else {
                    Write-Host "$runDate  $jobName  -> $($copyRun.status)" -ForegroundColor Yellow
                }
            }
        }
    }
}


