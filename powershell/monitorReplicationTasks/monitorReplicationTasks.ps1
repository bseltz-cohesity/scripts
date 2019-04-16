### usage: ./monitorReplicationTasks.ps1 -vip mycluster -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local' #local or AD domain
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### find protectionRuns with active replication tasks

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
$foundOne = $false

"Looking for Replication Tasks..."
foreach ($job in ((api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId })) {
    
    $runs = (api get protectionRuns?jobId=$($job.id)`&excludeTasks=true`&excludeNonRestoreableRuns=true`&numRuns=999999`&runTypes=kRegular) | `
        Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
        Where-Object { 'kRemote' -in $_.copyRun.target.type } | `
        Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

    foreach ($run in $runs) {

        $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
        $jobName = $run.jobName

        ### Display Status of archive task
        foreach ($copyRun in $run.copyRun) {
            if ($copyRun.target.type -eq 'kRemote') {
                if ($copyRun.status -notin $finishedStates) {
                    $foundOne = $True
                    Write-Host "$runDate  $jobName  -> $($copyRun.status)" -ForegroundColor Yellow
                }
            }
        }
    }
}

if($false -eq $foundOne){
    write-host "No running replication tasks found"
}

