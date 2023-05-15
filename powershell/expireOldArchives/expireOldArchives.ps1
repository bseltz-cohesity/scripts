### usage: ./monitorArchiveTasks.ps1 -vip mycluster -username admin [ -domain local ] [ -olderThan 30 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$jobName, # optional jobName 
    [Parameter()][string]$target, # optional target name
    [Parameter()][int]$olderThan = 0, # expire archives older than x days
    [Parameter()][int]$newerThan = 0, # expire archives newer than X days
    [Parameter()][switch]$expire,
    [Parameter()][switch]$showUnsuccessful
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### olderThan days in usecs
$olderThanUsecs = timeAgo $olderThan days
$newerThanUsecs = timeAgo $newerThan days

### find protectionRuns with old local snapshots with archive tasks and sort oldest to newest
"searching for old snapshots..."

$jobs = api get protectionJobs # | Where-Object { $_.policyId.split(':')[0] -eq $clusterId }
if($jobName){
    $jobs = $jobs | Where-Object name -eq $jobName
}

foreach ($job in $jobs) {
    $job.name
    $runs = (api get protectionRuns?jobId=$($job.id)`&excludeTasks=true`&excludeNonRestoreableRuns=true`&numRuns=999999`&runTypes=kRegular`&runTypes=kFull`&endTimeUsecs=$olderThanUsecs) | `
        Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } | `
        Where-Object { 'kArchival' -in $_.copyRun.target.type } | `
        Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

    if($newerThan -gt 0){
        $runs = $runs | Where-Object { $_.copyRun[0].runStartTimeUsecs -ge $newerThanUsecs }
    }

    foreach ($run in $runs) {

        $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
        $jobName = $run.jobName

        ### Display Status of archive task
        foreach ($copyRun in $run.copyRun) {
            if ($copyRun.target.type -eq 'kArchival') {
                if (($copyRun.status -eq 'kSuccess' -or $copyRun.status -eq 4) -and (! $showUnsuccessful)) {
                    if ($copyRun.expiryTimeUsecs -gt 0) {
                        if( ! $target -or $copyRun.target.archivalTarget.vaultName -eq $target){
                            write-host "$runDate  $jobName" -ForegroundColor Green
                            $expireRun = @{'jobRuns' = @(
                                    @{'expiryTimeUsecs'     = 0;
                                        'jobUid'            = $run.jobUid;
                                        'runStartTimeUsecs' = $run.backupRun.stats.startTimeUsecs;
                                        'copyRunTargets'    = @(
                                            @{'daysToKeep'       = 0;
                                                'type'           = 'kArchival';
                                                'archivalTarget' = $copyRun.target.archivalTarget
                                            }
                                        )
                                    }
                                )
                            }
                            if ($expire) {
                                api put protectionRuns $expireRun
                            }
                        }
                    }
                }else{
                    if($copyRun.status -ne 'kSuccess' -and $showUnsuccessful){
                        write-host "$runDate  $jobName $($copyRun.status)" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
}
