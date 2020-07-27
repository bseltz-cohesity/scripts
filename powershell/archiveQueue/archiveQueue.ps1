### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][switch]$cancelOutdated,
   [Parameter()][switch]$cancelQueued,
   [Parameter()][switch]$cancelAll,
   [Parameter()][int]$numRuns = 9999
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
            if($copyType -eq 'kArchival'){
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
            if($task.snapshotTarget.type -eq 3){
    
                $noLongerNeeded = ''
                $cancelling = ''
                $cancel = $false
                $daysToKeep = $task.retentionPolicy.numDaysToKeep
                $usecsToKeep = $daysToKeep * 1000000 * 86400
                $timePassed = $nowUsecs - $runStartTimeUsecs
                if($timePassed -gt $usecsToKeep){
                    $noLongerNeeded = "NO LONGER NEEDED"
                    if($cancelOutdated -or $cancelAll){
                        $cancel = $True
                        $cancelling = 'Cancelling'
                    }
                }
                if($task.archivalInfo.logicalBytesTransferred){
                    $transferred = $task.archivalInfo.logicalBytesTransferred
                }else{
                    $transferred = 0
                }
                if($transferred -eq 0 -and ($cancelQueued -or $cancelAll)){
                    $cancel = $True
                    $cancelling = 'Cancelling'
                }

                "                       Archive Task ID: {0}  {1}  {2}" -f $task.taskUid.objectId, $noLongerNeeded, $cancelling
                "                       Data Transferred: {0}" -f $transferred
                # cancel archive task
                if($cancel -eq $True){
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
    "`nNo active archive tasks found"
}
