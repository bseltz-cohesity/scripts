### usage: ./expireOldSnaps.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -daysToKeep 60 [ -expire ]
### omitting the -expire parameter: the script will only display all the snaps older than -daysToKeep
### including the -expire parameter: the script will actually expire all the snaps older than -daysToKeep 

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$daysToKeep,
    [Parameter()][switch]$expire
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### find protectionRuns that are older than daysToKeep
"Searching for old snapshots..."
foreach ($job in (api get protectionJobs)) {

    $jobId = $job.id

    foreach ($run in (api get protectionRuns?jobId=$($job.id)`&numRuns=999999`&excludeTasks=true`&excludeNonRestoreableRuns=true)) {
        if ($run.backupRun.snapshotsDeleted -eq $false) {
            $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
            $startdateusecs = $run.copyRun[0].runStartTimeUsecs
            if ($startdateusecs -lt $(timeAgo $daysToKeep days) ) {
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
                    "$($job.name) $($startdate)"
                }
            }
        }
    }
}                                                                                           
