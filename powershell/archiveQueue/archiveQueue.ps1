### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][switch]$cancelOutdated,
   [Parameter()][switch]$cancelQueued,
   [Parameter()][switch]$cancelAll,
   [Parameter()][switch]$showFinished,
   [Parameter()][int]$numRuns = 99999,
   [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'MiB'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')
if($showFinished){
    $finishedStates = @()
}

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "ArchiveQueue-$($cluster.name)-$dateString.csv"
"Job ID,Job Name,Run Date,Logical $unit,Status,Target,Start Time,End Time" | Out-File -FilePath $outfileName

$nowUsecs = dateToUsecs (get-date)

$runningTasks = 0

foreach($job in (api get protectionJobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false} | Sort-Object -Property name)){
    $jobId = $job.id
    $jobName = $job.name
    "$jobName ($jobId)"
    $runs = api get "protectionRuns?jobId=$jobId&numRuns=$numRuns&excludeTasks=true" | Where-Object {$_.copyRun.status -notin $finishedStates } | Sort-Object -Property {$_.backupRun.stats.startTimeUsecs}
    foreach($run in $runs){
        $runStartTimeUsecs = $run.backupRun.stats.startTimeUsecs
        foreach($copyRun in $($run.copyRun | Where-Object {$_.status -notin $finishedStates})){
            $copyType = $copyRun.target.type
            if($copyType -eq 'kArchival'){
                $run = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$($runStartTimeUsecs)&id=$($jobId)"
                foreach($task in $run.backupJobRuns.protectionRuns[0].copyRun.activeTasks){
                    if($task.snapshotTarget.type -eq 3){
                        $noLongerNeeded = ''
                        $cancelling = ''
                        $cancel = $false
                        $daysToKeep = $task.retentionPolicy.numDaysToKeep
                        $usecsToKeep = $daysToKeep * 1000000 * 86400
                        $timePassed = $nowUsecs - $runStartTimeUsecs
                        if($timePassed -gt $usecsToKeep){
                            $noLongerNeeded = "(NO LONGER NEEDED)"
                            if($cancelOutdated -or $cancelAll){
                                $cancel = $True
                                $cancelling = '(Cancelling)'
                            }
                        }
                        if($task.archivalInfo.logicalBytesTransferred){
                            $transferred = $task.archivalInfo.logicalBytesTransferred
                        }else{
                            $transferred = 0
                        }
                        if($transferred -eq 0 -and ($cancelQueued -or $cancelAll)){
                            $cancel = $True
                            $cancelling = '(Cancelling)'
                        }
                        $startTimeUsecs = $task.archivalInfo.startTimeUsecs
                        $status = $task.publicStatus.subString(1)
                        $target = $task.snapshotTarget.archivalTarget.name
                        "        {0,25}:    ({1} $unit)    {2}  {3}" -f (usecsToDate $runStartTimeUsecs), (toUnits $transferred), $noLongerNeeded, $cancelling
                        "{0},{1},{2},{3},{4},{5},{6}" -f $jobId, $jobName, (usecsToDate $runStartTimeUsecs), (toUnits $transferred), $status, $target, (usecsToDate $startTimeUsecs) | Out-File -FilePath $outfileName -Append
                        # cancel archive task
                        if($cancel -eq $True){
                            $cancelTaskParams = @{
                                "jobId"       = $jobId;
                                "copyTaskUid" = @{
                                    "id"                   = $task.taskUid.objectId;
                                    "clusterId"            = $task.taskUid.clusterId;
                                    "clusterIncarnationId" = $task.taskUid.clusterIncarnationId
                                }
                            }
                            $null = api post "protectionRuns/cancel/$($jobId)" $cancelTaskParams 
                        }
                    }
                }
                if($showFinished){
                    foreach($task in $run.backupJobRuns.protectionRuns[0].copyRun.finishedTasks){
                        if($task.snapshotTarget.type -eq 3){
                            $status = $task.publicStatus.subString(1)
                            $target = $task.snapshotTarget.archivalTarget.name
                            $transferred = $task.archivalInfo.logicalBytesTransferred
                            $startTimeUsecs = $task.archivalInfo.startTimeUsecs
                            $endTimeUsecs = $task.archivalInfo.endTimeUsecs
                            "        {0,25}:    ({1} $unit)    {2}" -f (usecsToDate $runStartTimeUsecs), (toUnits $transferred), $status
                            "{0},{1},{2},{3},{4},{5},{6},{7}" -f $jobId, $jobName, (usecsToDate $runStartTimeUsecs), (toUnits $transferred), $status, $target, (usecsToDate $startTimeUsecs), (usecsToDate $endTimeUsecs) | Out-File -FilePath $outfileName -Append
                        }
                    }
                }
                $runningTasks += 1
            }
        }
    }
}

if($runningTasks -eq 0){
    "`nNo active archive tasks found"
}else{
    "`nOutput saved to $outfilename"
}
