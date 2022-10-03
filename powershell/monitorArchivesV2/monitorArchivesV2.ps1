### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
   [Parameter()][int]$daysBack = 31
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning')

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "MonitorArchives-$($cluster.name)-$dateString.csv"
"JobName,RunDate,Status,Target,$unit Transferred,StartTime,EndTime,Pct Complete,Duration" | Out-File -FilePath $outfileName

$nowUsecs = dateToUsecs (get-date)

$runningTasks = 0

$now = Get-Date
$nowUsecs = dateToUsecs $now
$daysBackUsecs = dateToUsecs $now.AddDays(-$daysBack)

foreach($job in (api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true").protectionGroups | Sort-Object -Property name){
    $jobId = $job.id
    $jobName = $job.name
    "Getting tasks for $jobName"
    $endUsecs = dateToUsecs (Get-Date)
    while($True){
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=false"
        if($runs.runs.Count -gt 0){
            $endUsecs = $runs.runs[-1].localBackupInfo.startTimeUsecs - 1
        }else{
            break
        }
        foreach($run in $runs.runs){
            $runId = $run.id
            if($run.PSObject.Properties['localBackupInfo']){
                $runStartTimeUsecs = $run.localBackupInfo.startTimeUsecs
            }else{
                $runStartTimeUsecs = $run.originalBackupInfo.startTimeUsecs
            }
            if($runStartTimeUsecs -lt $daysBackUsecs){
                break
            }
            foreach($archivalInfo in $run.archivalInfo.archivalTargetResults){
                $taskId = $archivalInfo.archivalTaskId
                $status = $archivalInfo.status
                $progressTaskId = $archivalInfo.progressTaskId
                $bytesTransferred = $archivalInfo.stats.physicalBytesTransferred
                $targetName = $archivalInfo.targetName
                $queuedTimeUsecs = $archivalInfo.queuedTimeUsecs
                if($archivalInfo.PSObject.Properties['startTimeUsecs']){
                    $startTimeUsecs = $archivalInfo.startTimeUsecs
                    $started = $True
                }else{
                    $started = $false
                }
                if($status -notin $finishedStates){
                    $endTimeUsecs = $nowUsecs
                    if($progressTaskId){
                        $taskMonitor = api get "/progressMonitors?taskPathVec=$($progressTaskId)"
                        $pctComplete = [math]::Round($taskMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished)
                    }else{
                        $pctComplete = 0
                    }
                    write-host "  $status $(usecsToDate $runStartTimeUsecs)" -ForegroundColor Cyan
                }else{
                    if($status -eq 'Succeeded'){
                        $pctComplete = 100
                    }else{
                        $pctComplete = '-'
                    }
                    if($status -eq 'Succeeded'){
                        write-host "  $status $(usecsToDate $runStartTimeUsecs)" -ForegroundColor Green
                    }elseif ($status -eq 'Canceled'){
                        write-host "  $status $(usecsToDate $runStartTimeUsecs)" -ForegroundColor DarkYellow
                    }else{
                        write-host "  $status $(usecsToDate $runStartTimeUsecs)" -ForegroundColor DarkRed
                    }
                    $endTimeUsecs = $archivalInfo.endTimeUsecs
                }
                if($started){
                    $ts = [TimeSpan]::FromSeconds([math]::Round(($endTimeUsecs - $startTimeUsecs) / 1000000))
                    $duration = "{0}:{1:d2}:{2:d2}:{3:d2}" -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds
                    $startTime = usecsToDate $startTimeUsecs
                    if($status -notin $finishedStates){
                        $endTime = '-'
                    }else{
                        $endTime = usecsToDate $endTimeUsecs
                    }
                }else{
                    $duration = '-'
                    $startTime = '-'
                    $endTime = '-'
                }

                "$jobName,$(usecsToDate $runStartTimeUsecs),$status,$targetName,""$(toUnits $bytesTransferred)"",$startTime,$endTime,$pctComplete,$duration" | Out-File -FilePath $outfileName -Append
            }
        }
    } 
}
