### usage: ./expireArchivedSnapshots.ps1 -vip mycluster -username admin [ -domain local ] -olderThan 365 [ -expire ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$olderThan, #archive snapshots older than x days
    [Parameter()][string]$jobName,
    [Parameter()][switch]$expire
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### olderThan days in usecs
$olderThanUsecs = timeAgo $olderThan days

### find protectionRuns with old local snapshots that are archived and sort oldest to newest
"searching for old snapshots..."
$jobs = api get protectionJobs # | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId }
if($jobName){
    $jobs = $jobs | Where-Object {$_.name -eq $jobName}
    if(!$jobs){
        Write-Host "Job $jobName not found" -ForegroundColor Yellow
    }
}

foreach ($job in $jobs) {
    
    $runs = (api get protectionRuns?jobId=$($job.id)`&numRuns=999999`&runTypes=kRegular`&excludeTasks=true`&excludeNonRestoreableRuns=true) | `
    Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
    Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } | `
    Where-Object { 'kArchival' -in $_.copyRun.target.type } | `
    Where-Object { $_.backupRun.runType -ne 'kLog' } | `
    Sort-Object -Property @{Expression={ $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

    foreach ($run in $runs) {

        $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
        $jobName = $run.jobName

        ### If the Local Snapshot is not expiring soon...
        foreach ($copyRun in $run.copyRun) {
            if ($copyRun.target.type -eq 'kArchival') {
                if ($copyRun.status -eq 'kSuccess') {
                    if ($expire) {
                        ### expire the local snapshot
                        write-host "Expiring  $runDate  $jobName  (Archive kSuccessful)" -ForegroundColor Green
                        $expireRun = @{'jobRuns' = @(
                                @{'expiryTimeUsecs'     = 0;
                                    'jobUid'            = $run.jobUid;
                                    'runStartTimeUsecs' = $run.copyRun[0].runStartTimeUsecs;
                                    'copyRunTargets'    = @(
                                        @{'daysToKeep' = 0;
                                            'type'     = 'kLocal';
                                        }
                                    )
                                }
                            )
                        }
                        api put protectionRuns $expireRun
                    }
                    else {
                        ### display that we would expire this snapshot if -expire was set
                        write-host "To Expire $runDate  $jobName  (Archive kSuccessful)" -ForegroundColor Green
                    }
                }
                else {
                    #display that we're skipping this since it hasn't completed yet
                    Write-Host "Skipping  $runDate  $jobName  (Archive $($copyRun.status)" -ForegroundColor Yellow
                }
            }
        }
    }
}

