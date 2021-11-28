### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
   [Parameter()][string]$domain = 'local',      # local or AD domain
   [Parameter()][string]$jobName,          # filter on job names
   [Parameter()][string]$jobList = '',    # filter on job names from text file
   [Parameter()][switch]$cancelOutdated,  # cancel if archive is already due to expire
   [Parameter()][switch]$cancelQueued,    # cancel if archive hasn't transferred any data yet
   [Parameter()][switch]$cancelAll,       # cancel all archives
   [Parameter()][switch]$showFinished,    # show completed archives
   [Parameter()][int]$numRuns = 100,
   [Parameter()][int]$daysBack,
   [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'MiB'
)

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

# gather list of jobs
$jobNames = @()
if($jobName){
    $jobNames = @($jobNames + $jobName)
}
if ('' -ne $jobList){
    if(Test-Path -Path $jobList -PathType Leaf){
        $jobs = Get-Content $jobList
        foreach($j in $jobs){
            $jobNames += [string]$j
        }
    }else{
        Write-Host "Job list $jobList not found!" -ForegroundColor Yellow
        exit
    }
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kCanceled', 'kCanceling', 'kSuccess', 'kFailure', 'kWarning')

$oldest = @{}

if(!$showFinished){
    Write-Host "`nConnecting to Siren " -NoNewLine
    $jobNames = @()
    $nodes = api get nodes
    $ProgressPreference = 'SilentlyContinue'
    Write-Host "." -NoNewLine
    $bridgePage = Invoke-WebRequest -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=http%3A%2F%2F$($nodes[0].ip)%3A11111%2F" -Headers $cohesity_api.header -SkipCertificateCheck
    $iceBoxUrl = $bridgePage.Content.split('flagz')[-1].split('>icebox<')[0].split('=')[-1].split('"')[0]
    Write-Host "." -NoNewLine
    $iceBoxPage = Invoke-WebRequest -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=$iceBoxUrl" -Headers $cohesity_api.header -SkipCertificateCheck
    $iceBoxMasterUrl = $iceBoxPage.Content.Split('Icebox Master Location</td>')[1].split('</td>')[0].split('remoteUrl=')[1].split('"')[0]
    Write-Host "." -NoNewLine
    $iceBoxMasterPage = Invoke-WebRequest -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=$iceBoxMasterUrl" -Headers $cohesity_api.header -SkipCertificateCheck
    $rows = $iceBoxMasterPage.Content.split('Archival Jobs')[1].split('<table ')[1].split('</table/>')[0].split('<tr>') | Where-Object { $_.subString(1,4) -eq '<td>' }
    $ProgressPreference = 'Continue'
    foreach($row in $rows){
        $columns = $row.split('</td>')
        $taskUid = $columns[0].split('>')[1].split('%3D')[-1].split('"')[0]
        $clusterId, $clusterIncarnationId, $taskId = $taskUid.split('%3A')
        $jobName = $columns[8].split('>')[0].split('"')[-2]
        $jobId = $columns[8].split('>')[-2].split('<')[0]
        $jobNames += $jobName
        if([string]$jobId -notin $oldest.Keys){
            $oldest[[string]$jobId] = [int64]$taskId
        }else{
            if($taskId -lt $oldest[[string]$jobId]){
                $oldest[[string]$jobId] = [int64]$taskId
            }
        }
    }
    Write-Host "." -NoNewLine
}

$cluster = api get cluster
$daysBackUsecs = $cluster.createdTimeMsecs * 1000
if($daysBack){
    $daysBackUsecs = dateToUsecs ((get-Date).AddDays(-$daysBack))
}
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "ArchiveQueue-$($cluster.name)-$dateString.csv"
"Job ID,Job Name,Run Date,Status,Target,Reference Full,Start Time,End Time,Transferred $unit" | Out-File -FilePath $outfileName

$nowUsecs = dateToUsecs (get-date)
$thenUsecs = [int64]($nowUsecs + ($daysTilExpire * 24 * 60 * 60 * 1000000))

$runningTasks = 0
Write-Host ""

foreach($job in (api get protectionJobs?allUnderHierarchy=true | Where-Object {$_.isDeleted -ne $True} | Sort-Object -Property name)){

    $jobId = $job.id
    $jobName = $job.name

    if(($jobNames.Length -eq 0 -and $showFinished) -or $jobName -in $jobNames){
        if($job.tenantId){
            $tenantId = $job.tenantId.split('/')[0]
            impersonate $tenantId
        }
        "$jobName ($jobId)"
        $endUsecs = dateToUsecs (Get-Date)
        $archiveTasksFound = $false
        $breakOut = $false
        while($True){
            if($breakOut){
                break
            }
            $runs = api get "protectionRuns?jobId=$jobId&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true"
            if($runs){
                $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs - 1
            }else{
                break
            }
            foreach($run in $runs){
                $runStartTimeUsecs = $run.backupRun.stats.startTimeUsecs
                if($showFinished -and $runStartTimeUsecs -lt $daysBackUsecs){
                    $breakOut = $True
                    break
                }
                foreach($copyRun in ($run.copyRun | Where-Object {$_.target.type -eq 'kArchival'})){
                    $archiveTasksFound = $True
                    $target = $copyRun.target.archivalTarget.vaultName
                    $status = $copyRun.status.subString(1)
                    $startTimeUsecs = $copyRun.stats.startTimeUsecs
                    $endTimeUsecs = $copyRun.stats.endTimeUsecs
                    $transferred = $copyRun.stats.logicalBytesTransferred
                    $noLongerNeeded = ''
                    $cancelling = ''
                    $cancel = $false
                    $expiryTimeUsecs = $copyRun.expiryTimeUsecs
                    
                    if($copyRun.stats.isIncremental -eq $False){
                        $referenceFull = '(Reference Full)'
                    }else{
                        $referenceFull = ''
                    }

                    if($copyRun.status -notin $finishedStates){
                        # cancel outdated
                        if($cancelOutdated){
                            $thisrun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$($runStartTimeUsecs)&id=$($jobId)"
                            foreach($task in $thisrun.backupJobRuns.protectionRuns[0].copyRun.activeTasks){
                                if($task.snapshotTarget.type -eq 3){
                                    $daysToKeep = $task.retentionPolicy.numDaysToKeep - $daysTilExpire
                                    $usecsToKeep = $daysToKeep * 1000000 * 86400
                                    $timePassed = $nowUsecs - $runStartTimeUsecs
                                    if($timePassed -gt $usecsToKeep){
                                        $noLongerNeeded = "(NO LONGER NEEDED)"
                                        if($cancelOutdated -or $cancelAll){
                                            $cancel = $True
                                            $cancelling = '(Cancelling)'
                                        }
                                    }
                                }
                            }
                        }
                        if($status -eq 'Running' -and $cancelQueued){
                            $cancel = $True
                            $cancelling = '(Cancelling)'
                        }
                        if($cancelAll){
                            $cancel = $True
                            $cancelling = '(Cancelling)'
                        }
                        "        {0,25} -> {1}  {2}  {3}  {4}" -f (usecsToDate $runStartTimeUsecs), $target, $referenceFull, $noLongerNeeded, $cancelling
                        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}""" -f $jobId, $jobName, (usecsToDate $runStartTimeUsecs), $status, $target, $referenceFull | Out-File -FilePath $outfileName -Append
                        $runningTasks += 1
                        # cancel archive task
                        if($cancel -eq $True){
                            $cancelTaskParams = @{
                                "jobId"       = $jobId;
                                "copyTaskUid" = $copyRun.taskUid
                            }
                            $null = api post "protectionRuns/cancel/$($jobId)" $cancelTaskParams 
                        }
                        if(!$showFinished -and [string]$jobId -in $oldest.keys -and $copyRun.taskUid.id -le [int64]$oldest[[string]$jobId]){
                            $breakOut = $True
                            break
                        }
                    }else{
                        if($showFinished){
                            "        {0,25}: -> {1}  {2}  {3}  {4}" -f (usecsToDate $runStartTimeUsecs), $target, $status, (toUnits $transferred),$referenceFull
                            """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""" -f $jobId, $jobName, (usecsToDate $runStartTimeUsecs), $status, $target, $referenceFull, (usecsToDate $startTimeUsecs), (usecsToDate $endTimeUsecs), (toUnits $transferred) | Out-File -FilePath $outfileName -Append
                        }
                    }
                }
                if($breakOut){
                    break
                }
            }
            if($quickScan -and $archiveTasksFound -eq $false){
                $breakOut = $True
                break
            }
        }
    }
    switchback
}

if($runningTasks -eq 0){
    "`nNo active archive tasks found"
}else{
    "`nOutput saved to $outfilename"
}
