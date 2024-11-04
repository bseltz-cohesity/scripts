# usage: ./expireOldReplicas.ps1 -vip mycluster `
#                                -username myuser `
#                                -domain mydomain.net `
#                                -jobname myjob1, myjob2 `
#                                -daysToKeep 14 `
#                                -remoteCluster othercluster `
#                                -expire

# omitting the -expire parameter: the script will only display all the replicas older than -daysToKeep
# including the -expire parameter: the script will actually expire all the snaps older than -daysToKeep 

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$jobname = $null,
    [Parameter(Mandatory = $True)][string]$remoteCluster,
    [Parameter(Mandatory = $True)][string]$daysToKeep,
    [Parameter()][ValidateSet("kRegular","kFull","kLog","kSystem","kAll")][string]$backupType = 'kAll',
    [Parameter()][switch]$expire,
    [Parameter()][Int64]$numRuns = 1000,
    [Parameter()][Int64]$daysBack = 180
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# filter on jobname
$jobs = api get protectionJobs
if($jobname){
    $jobs = $jobs | Where-Object { $_.name -in $jobname }
    $notfoundJobs = $jobname | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$nowUsecs = dateToUsecs (get-date)
$daysBackUsecs = dateToUsecs (get-date).AddDays(-$daysBack)

# find protectionRuns that are older than daysToKeep
"Searching for old replicas..."

foreach ($job in $jobs | Sort-Object -Property name) {
    $job.name
    $jobId = $job.id

    $endUsecs = dateToUsecs (Get-Date)
    while($True){
        # paging: get numRuns at a time
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true" | Where-Object {$_.backupRun.stats.endTimeUsecs -lt $endUsecs}
        if($runs){
            $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs
        }else{
            break
        }
        # runs with replicas on tha remote cluster
        foreach ($run in $runs | Where-Object {$_.copyRun | where-object {$_.target.replicationTarget.clusterName -eq $remoteCluster -and $_.expiryTimeUsecs -gt $nowUsecs}}){
            if($run.backupRun.stats.startTimeUsecs -le $daysBackUsecs){
                break
            }
            if ($run.backupRun.runType -eq $backupType -or $backupType -eq 'kAll'){
                $copyRun = $run.copyRun | Where-Object {$_.target.replicationTarget.clusterName -eq $remoteCluster }
                $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
                $startdateusecs = $run.copyRun[0].runStartTimeUsecs
                if ($startdateusecs -lt $(timeAgo $daysToKeep days) ) {
                    # if -expire switch is set, expire the replica
                    if ($expire) {
                        $exactRun = api get /backupjobruns?exactMatchStartTimeUsecs=$startdateusecs`&id=$jobId
                        $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                        # expire the replica
                        "    Expiring $($job.name) Replica on $remoteCluster from $startdate"
                        $expireRun = @{'jobRuns' = @(
                                @{'expiryTimeUsecs'     = 0;
                                    'jobUid'            = @{
                                        'clusterId' = $jobUid.clusterId;
                                        'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                                        'id' = $jobUid.objectId;
                                    }
                                    'runStartTimeUsecs' = $startdateusecs;
                                    'copyRunTargets'    = @(
                                        @{
                                            'daysToKeep' = 0;
                                            'type'     = 'kRemote';
                                            'replicationTarget' = $copyRun.target.replicationTarget
                                        }
                                    )
                                }
                            )
                        }
                        $null = api put protectionRuns $expireRun
                    }else{
                        # just print old replicas if we're not expiring
                        "    $($job.name) ($($run.backupRun.runType.subString(1))) $($startdate)"
                    }
                }
            }
        }
    }
}                                                                                           
