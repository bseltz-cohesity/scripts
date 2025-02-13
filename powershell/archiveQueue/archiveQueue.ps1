### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
   [Parameter()][string]$jobName,          # filter on job names
   [Parameter()][string]$jobList = '',    # filter on job names from text file
   [Parameter()][switch]$cancelOutdated,  # cancel if archive is already due to expire
   [Parameter()][switch]$cancelQueued,    # cancel if archive hasn't transferred any data yet
   [Parameter()][switch]$cancelAll,       # cancel all archives
   [Parameter()][switch]$quickScan,       # break scan if a completion is found or if no copyRuns are detected
   [Parameter()][switch]$showFinished,    # show completed archives
   [Parameter()][int]$numRuns = 1000,
   [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'MiB'
)

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
if($cohesity_api.api_version -lt '2025.01.10'){
    Write-Host "This script requires cohesity-api.ps1 version 2025.01.10 or later" -foregroundColor Yellow
    Write-Host "Please download it from https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api" -ForegroundColor Yellow
    exit
}


$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$finishedStates = @('kCanceled', 'kCanceling', 'kSuccess', 'kFailure', 'kWarning')

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "ArchiveQueue-$($cluster.name)-$dateString.tsv"
"Job ID`tJob Name`tRun Date`tLogical $unit`tPhysical $unit`tStatus`tTarget`tStart Time`tEnd Time`tExpiry Time" | Out-File -FilePath $outfileName

$nowUsecs = dateToUsecs (get-date)
$thenUsecs = [int64]($nowUsecs + ($daysTilExpire * 24 * 60 * 60 * 1000000))

$runningTasks = 0

foreach($job in (api get protectionJobs | Where-Object {$_.isDeleted -ne $True} | Sort-Object -Property name)){

    $jobId = $job.id
    $jobName = $job.name

    if($jobNames.Length -eq 0 -or $jobName -in $jobNames){
        "$jobName ($jobId)"
        $endUsecs = dateToUsecs (Get-Date)
        $archiveTasksFound = $false
        $breakOut = $false
        Get-Runs -jobId $jobId -numRuns $numRuns -includeRunning | Foreach-Object {
            $run = $_
            if($breakOut){
                break
            }
            $runStartTimeUsecs = $run.backupRun.stats.startTimeUsecs
            foreach($copyRun in ($run.copyRun | Where-Object {$_.target.type -eq 'kArchival'})){
                $archiveTasksFound = $True
                $target = $copyRun.target.archivalTarget.vaultName
                $status = $copyRun.status
                $startTimeUsecs = $copyRun.stats.startTimeUsecs
                $endTimeUsecs = $copyRun.stats.endTimeUsecs
                $noLongerNeeded = ''
                $cancelling = ''
                $cancel = $false
                $expiryTimeUsecs = $copyRun.expiryTimeUsecs
                if($copyRun.stats.logicalBytesTransferred){
                    $transferred = $copyRun.stats.logicalBytesTransferred
                }else{
                    $transferred = 0
                }
                if($copyRun.stats.physicalBytesTransferred){
                    $physicalTransferred = $copyRun.stats.physicalBytesTransferred
                }else{
                    $physicalTransferred = 0
                }
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

                    if($transferred -eq 0 -and ($cancelQueued -or $cancelAll)){
                        $cancel = $True
                        $cancelling = '(Cancelling)'
                    }

                    "        {0,25}:    ({1} $unit)    {2}  {3}  {4}" -f (usecsToDate $runStartTimeUsecs), (toUnits $transferred), $referenceFull, $noLongerNeeded, $cancelling
                    "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t`t{8}" -f $jobId, $jobName, (usecsToDate $runStartTimeUsecs), (toUnits $transferred), (toUnits $physicalTransferred), $status, $target, (usecsToDate $startTimeUsecs), (usecsToDate $expiryTimeUsecs) | Out-File -FilePath $outfileName -Append
                    $runningTasks += 1
                    # cancel archive task
                    if($cancel -eq $True){
                        $cancelTaskParams = @{
                            "jobId"       = $jobId;
                            "copyTaskUid" = $copyRun.taskUid
                        }
                        $null = api post "protectionRuns/cancel/$($jobId)" $cancelTaskParams 
                    }
                }else{
                    if($showFinished -and $expiryTimeUsecs -gt $nowUsecs){
                        "        {0,25}:    ({1} $unit)    {2}  {3}" -f (usecsToDate $runStartTimeUsecs), (toUnits $transferred), $status, $referenceFull
                        "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}`t{9}" -f $jobId, $jobName, (usecsToDate $runStartTimeUsecs), (toUnits $transferred), (toUnits $physicalTransferred), $status, $target, (usecsToDate $startTimeUsecs), (usecsToDate $endTimeUsecs), (usecsToDate $expiryTimeUsecs) | Out-File -FilePath $outfileName -Append
                    }else{
                        if($quickScan){
                            $breakOut = $True
                            break
                        }
                    }
                }
            }
            if($breakOut){
                break
            }
            if($quickScan -and $archiveTasksFound -eq $false){
                $breakOut = $True
                break
            }
        }
    }
}

if($runningTasks -eq 0){
    "`nNo active archive tasks found"
    exit 0
}else{
    "`nOutput saved to $outfilename"
    exit 1
}
