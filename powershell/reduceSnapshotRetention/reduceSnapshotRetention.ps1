### usage: ./reduceSnapshotRetention.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -newRetention 60 [ -force ]
### omitting the -force parameter: the script will only display the snaps it would have reduced or expired
### including the -force parameter: the script will actually reduce the retention or expire the snapshots 

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$jobName,
    [Parameter(Mandatory = $True)][string]$newRetention,
    [Parameter()][switch]$force
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find protectionRuns that are older than daysToKeep
"Reviewing snapshots..."
foreach ($job in (api get protectionJobs)) {
    if(! ($jobName -and $jobName -ne $job.name)){
        $jobId = $job.id

        foreach ($run in (api get protectionRuns?jobId=$($job.id)`&numRuns=999999`&excludeTasks=true`&excludeNonRestoreableRuns=true)) {
            if ($run.backupRun.snapshotsDeleted -eq $false) {
                $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
                $startdateusecs = $run.copyRun[0].runStartTimeUsecs
                if ($startdateusecs -lt $(timeAgo $newRetention days) ) {
                    ### if -force switch is set, expire the local snapshot
                    if ($force) {
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
                        $null = api put protectionRuns $expireRun
                    }else{
                        ### just print snapshots we would expire
                        "Would expire $($job.name) $($startdate)"
                    }
                }else{
                    $newExpiryUsecs = [int64](dateToUsecs $startdate.addDays($newRetention))
                    if($run.copyRun[0].expiryTimeUsecs -gt ($newExpiryUsecs + 86400000000)){
                        $reduceByDays = [int64][math]::floor(($run.copyRun[0].expiryTimeUsecs - $newExpiryUsecs) / 86400000000)
                        ### if -force is set, reduce the retention
                        if ($force) {
                            $exactRun = api get /backupjobruns?exactMatchStartTimeUsecs=$startdateusecs`&id=$jobId
                            $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                            ### edit the snapshot
                            "Reducing retention for $($job.name) Snapshot from $startdate"
                            $editRun = @{'jobRuns' = @(
                                    @{
                                        'jobUid'            = @{
                                            'clusterId' = $jobUid.clusterId;
                                            'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                                            'id' = $jobUid.objectId;
                                        }
                                        'runStartTimeUsecs' = $startdateusecs;
                                        'copyRunTargets'    = @(
                                            @{'daysToKeep' = -$reduceByDays;
                                                'type'     = 'kLocal';
                                            }
                                        )
                                    }
                                )
                            }
                            $null = api put protectionRuns $editRun
                        }else{
                            ### just print snapshots we would expire
                            "Would reduce $($job.name) $($startdate) by $reduceByDays days"
                        }    
                    }
                }
            }
        }
    }
}                                                                                   
