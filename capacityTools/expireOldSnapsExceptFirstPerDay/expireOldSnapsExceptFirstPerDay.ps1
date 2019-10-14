### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$jobname = $null,
    [Parameter(Mandatory = $True)][string]$daysToKeep,
    [Parameter()][switch]$expire
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### filter on jobname
$jobs = api get protectionJobs
if($jobname){
    $jobs = $jobs | Where-Object { $_.name -eq $jobname }
    if($jobs.count -eq 0){
        Write-Host "Job '$jobname' not found" -ForegroundColor Yellow
        exit
    }
}

### find protectionRuns that are older than daysToKeep
"Searching for old snapshots..."

foreach ($job in $jobs) {

    $jobId = $job.id
    $runs = api get protectionRuns?jobId=$($job.id)`&numRuns=999999`&excludeTasks=true`&excludeNonRestoreableRuns=true`&runTypes=kRegular
    $dailyRuns = $runs | where-object {$_.backupRun.snapshotsDeleted -eq $false -and $_.backupRun.runType -eq 'kRegular'} | Group-Object -Property {(usecsToDate $_.copyRun[0].runStartTimeUsecs).DayOfYear}, {(usecsToDate $_.copyRun[0].runStartTimeUsecs).Year}

    foreach($dayRuns in $dailyRuns){
        $theseruns = $dayRuns.Group | Sort-Object -Property { $_.copyRun.runStartTimeUsecs } | Where-Object { $_.backupRun.runType -eq 'kRegular' }
        $firstSnap = $true
        foreach ($run in $theseruns) {
            if ($run.backupRun.snapshotsDeleted -eq $false) {
                $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
                $startdateusecs = $run.copyRun[0].runStartTimeUsecs
                if ($startdateusecs -lt $(timeAgo $daysToKeep days) ) {
                    if(! $firstSnap){
                        ### if -expire switch is set, expire the local snapshot
                        if ($expire) {
                            $exactRun = api get /backupjobruns?exactMatchStartTimeUsecs=$startdateusecs`&id=$jobId
                            $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                            ### expire the snapshot
                            "Expiring $($job.name) Snapshot from $startdate"
                            $expireRun = @{'jobRuns' = @(
                                    @{'expiryTimeUsecs'     = 0;
                                        'jobUid'            = @{
                                            'clusterId' = $jobUid.clusterId;
                                            'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                                            'id' = $jobUid.objectId;
                                        }
                                        'runStartTimeUsecs' = $startdateusecs;
                                        'copyRunTargets'    = @(
                                            @{'daysToKeep' = 0;
                                                'type'     = 'kLocal';
                                            }
                                        )
                                    }
                                )
                            }
                            api put protectionRuns $expireRun
                        }else{
                            ### just print old snapshots if we're not expiring
                            "Expire $($job.name) $($startdate)"
                        }
                    }else{
                        "Keep $($job.name) $($startdate)"
                        $firstSnap = $false
                    }
                }
            }
        }
    }                                                                                           
}