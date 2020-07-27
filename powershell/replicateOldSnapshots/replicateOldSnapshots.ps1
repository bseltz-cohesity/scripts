### usage: ./replicateOldSnapshots.ps1 -vip mycluster -username admin [ -domain local ] -replicateTo CohesityVE -olderThan 365 [ -IfExpiringAfter 30 ] [ -keepFor 365 ] [ -archive ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$jobName = $null, # name of job to replicate
    [Parameter(Mandatory = $True)][string]$replicateTo, # name of replication target
    [Parameter()][string]$olderThan = 0, # archive snapshots older than x days
    [Parameter()][string]$IfExpiringAfter = -1, # do not archve if the snapshot is going to expire within x days
    [Parameter()][string]$keepFor = 0, # set archive retention to x days from original backup date
    [Parameter()][switch]$replicate # actually replicate (otherwise test run)
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

### get replication target info
$remote = api get remoteClusters | Where-Object {$_.name -eq $replicateTo}
if (!$remote) {
    Write-Warning "Replication target $replicateTo not found"
    exit
}

### get job
if($jobName){
    $myjob = api get protectionJobs | Where-Object {$_.name -eq $jobName}
    if(!$myjob){
        Write-Warning "Job $jobName not found!" -ForegroundColor Yellow
        exit
    }
}else{
    $myjob = $null
}


### olderThan days in usecs
$olderThanUsecs = timeAgo $olderThan days

### find protectionRuns with old local snapshots that are not archived yet and sort oldest to newest
"searching for old snapshots..."
foreach ($job in ((api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId })) {
    if (!$myjob -or ($myjob.name -eq $job.name)){
        $runs = (api get protectionRuns?jobId=$($job.id)`&numRuns=999999`&runTypes=kRegular`&excludeTasks=true`&excludeNonRestoreableRuns=true) | `
            Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
            Where-Object { $_.copyRun[0].runStartTimeUsecs -le $olderThanUsecs } | `
            Where-Object { !('kRemote' -in $_.copyRun.target.type) -or ($_.copyRun | Where-Object { $_.target.type -eq 'kRemote' -and $_.status -in @('kCanceled','kFailed') }) } | `
            Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }

        foreach ($run in $runs) {

            $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
            $thisJobName = $run.jobName

            ### calculate daysToKeep
            $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
            if($keepFor -gt 0){
                $expireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
            }else{
                $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
            }
            $now = dateToUsecs $(get-date)
            $daysToKeep = [math]::Round(($expireTimeUsecs - $now) / 86400000000) 

            ### create replication task definition
            $replicationTask = @{
                'jobRuns' = @(
                    @{
                        'copyRunTargets'    = @(
                            @{
                                "replicationTarget" = @{
                                    "clusterId" = $remote.clusterId;
                                    "clusterName" = $remote.name
                                };
                                'daysToKeep'     = [int] $daysToKeep;
                                'type'           = 'kRemote'
                            }
                        );
                        'runStartTimeUsecs' = $run.copyRun[0].runStartTimeUsecs;
                        'jobUid'            = $run.jobUid
                    }
                )
            }

            ### If the Local Snapshot is not expiring soon...
            if ($daysToKeep -gt $IfExpiringAfter) {
                if ($replicate) {
                    write-host "Replicating $runDate  $thisJobName for $daysToKeep days" -ForegroundColor Green
                    ### execute replication task if arcvhive swaitch is set
                    $null = api put protectionRuns $replicationTask
                }
                else {
                    ### just display what we would do if archive switch is not set
                    write-host "$runDate  $thisJobName  (would replicate for $daysToKeep days)" -ForegroundColor Green
                }
            }
            ### Otherwise tell us that we're not archiving since the snapshot is expiring soon
            else {
                write-host "$runDate  $thisJobName  (expiring in $daysToKeep days. skipping...)" -ForegroundColor Gray
            }
        }
    }
}

