### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][int]$numRuns = 999,
   [Parameter()][switch]$cancelAll,
   [Parameter()][switch]$cancelOutdated
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')

$nowUsecs = dateToUsecs (get-date)

$runningTasks = @{}

foreach($job in (api get protectionJobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false} | Sort-Object -Property name)){
    $jobId = $job.id
    $jobName = $job.name
    "Getting tasks for $jobName"
    $runs = api get "protectionRuns?jobId=$jobId&numRuns=$numRuns&excludeTasks=true" | Where-Object {$_.copyRun.status -notin $finishedStates }
    foreach($run in $runs){
        $runStartTimeUsecs = $run.backupRun.stats.startTimeUsecs
        foreach($copyRun in $($run.copyRun | Where-Object {$_.status -notin $finishedStates})){
            $startTimeUsecs = $runStartTimeUsecs
            $copyType = $copyRun.target.type
            $status = $copyRun.status
            if($copyType -eq 'kRemote'){
                $runningTask = @{
                    "jobname" = $jobName;
                    "jobId" = $jobId;
                    "startTimeUsecs" = $runStartTimeUsecs;
                    "copyType" = $copyType;
                    "status" = $status
                }
                $runningTasks[$startTimeUsecs] = $runningTask
            }
        }
    }
}

# display output sorted by oldest first
if($runningTasks.Keys.Count -gt 0){
    "`n`nStart Time           Job Name"
    "----------           --------"
    foreach($startTimeUsecs in ($runningTasks.Keys | Sort-Object)){
        $t = $runningTasks[$startTimeUsecs]
        "{0}   {1} ({2})" -f (usecsToDate $t.startTimeUsecs), $t.jobName, $t.jobId
        $run = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$($t.startTimeUsecs)&id=$($t.jobId)"
        $runStartTimeUsecs = $run.backupJobRuns.protectionRuns[0].backupRun.base.startTimeUsecs
        foreach($task in $run.backupJobRuns.protectionRuns[0].copyRun.activeTasks){
            if($task.snapshotTarget.type -eq 2){

                $noLongerNeeded = ''
                $daysToKeep = $task.retentionPolicy.numDaysToKeep
                $usecsToKeep = $daysToKeep * 1000000 * 86400
                $timePassed = $nowUsecs - $runStartTimeUsecs
                if($timePassed -gt $usecsToKeep){
                    $noLongerNeeded = "NO LONGER NEEDED"
                }
                "                       Replication Task ID: {0}  {1}" -f $task.taskUid.objectId, $noLongerNeeded
                foreach($subTask in $task.activeCopySubTasks | Sort-Object {$_.publicStatus} -Descending){
                    if($subTask.snapshotTarget.type -eq 2){
                        if($subTask.publicStatus -eq 'kRunning'){
                            $pct = $subTask.replicationInfo.pctCompleted
                        }else{
                            $pct = 0
                        }
                        "                       {0} ({1})`t{2}" -f $subTask.publicStatus, $pct, $subTask.entity.displayName
                    }
                }
                if($cancelAll -or ($cancelOutdated -and ($noLongerNeeded -eq "NO LONGER NEEDED"))){
                    $cancelTaskParams = @{
                        "jobId"       = $t.jobId;
                        "copyTaskUid" = @{
                            "id"                   = $task.taskUid.objectId;
                            "clusterId"            = $task.taskUid.clusterId;
                            "clusterIncarnationId" = $task.taskUid.clusterIncarnationId
                        }
                    }
                    $null = api post "protectionRuns/cancel/$($t.jobId)" $cancelTaskParams 
                }
            }
        }
    }
}else{
    "`nNo active replication tasks found"
}
