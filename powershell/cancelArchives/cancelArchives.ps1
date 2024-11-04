### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key for authentication
    [Parameter()][string]$password,                      # optional password
    [Parameter()][switch]$noPrompt,                      # do not prompt for password
    [Parameter()][string]$tenant,                        # org to impersonate
    [Parameter()][switch]$mcm,                           # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,               # MFA code
    [Parameter()][switch]$emailMfaCode,                  # email MFA code
    [Parameter()][string]$clusterName = $null,           # helios cluster to access
    [Parameter()][string]$jobName,  #optional jobname filter
    [Parameter()][switch]$cancelOutdated,
    [Parameter()][switch]$cancelQueued,
    [Parameter()][switch]$cancelAll,
    [Parameter()][int]$cancelOlderThan = 0,
    [Parameter()][switch]$showFinished,
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][switch]$commit,
    [Parameter()][string]$targetName,
    [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'MiB',
    [Parameter()][switch]$logsOnly
)

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning')

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "ArchiveQueue-$($cluster.name)-$dateString.csv"
"JobName,RunDate,Status,$unit Transferred" | Out-File -FilePath $outfileName

$nowUsecs = dateToUsecs (get-date)

$runningTasks = 0

$now = Get-Date
$nowUsecs = dateToUsecs $now

$jobs = (api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true").protectionGroups | Sort-Object -Property name
if($jobName){
    $jobs = $jobs | Where-Object name -eq $jobName
}

foreach($job in $jobs){
    $jobId = $job.id
    $thisJobName = $job.name
    "Getting tasks for $thisJobName"
    $endUsecs = $nowUsecs
    $runInfo = @()
    while($True){
        $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=false"
        if($runs.runs.Count -gt 0){
            $endUsecs = $runs.runs[-1].localBackupInfo.startTimeUsecs - 1
        }else{
            break
        }
        foreach($run in $runs.runs){
            if($logsOnly -and $run.localBackupInfo.runType -ne 'kLog'){
                continue
            }
            $runId = $run.id
            $startTimeUsecs = $run.localBackupInfo.startTimeUsecs
            foreach($archivalInfo in $run.archivalInfo.archivalTargetResults){
                if($archivalInfo.targetName -eq $targetName -or ! $targetName){
                    $taskId = $archivalInfo.archivalTaskId
                    $status = $archivalInfo.status
                    $transferred = toUnits $archivalInfo.stats.logicalBytesTransferred
                    $expiryTime = $archivalInfo.expiryTimeUsecs
                    $isIncremental = $archivalInfo.isIncremental
                    $runInfo = @($runInfo + @{
                        'runId' = $runId;
                        'taskId' = $taskId;
                        'status' = $status;
                        'transferred' = $transferred;
                        'expiryTime' = $expiryTime;
                        'isIncremental' = $isIncremental;
                        'startTimeUsecs' = $startTimeUsecs;
                        'targetName' = $archivalInfo.targetName;
                    })
                }
                
            }
        }

        if($cancelQueued){
            $runInfo = @($runInfo | Where-Object {$_.status -notin $finishedStates})
            $runInfo = $runInfo[0..$($runInfo.Length-2)]
        }elseif($cancelOlderThan -gt 0){
            $daysBack = (Get-Date).AddDays(-$cancelOlderThan)
            $daysBackUsecs = dateToUsecs $daysBack
            $runInfo = @($runInfo | Where-Object {$_.status -notin $finishedStates -and $_.startTimeUsecs -lt $daysBackUsecs})
        }
        foreach($run in $runInfo){
            $referenceFull = ''
            if($run.isIncremental -eq $false){
                $referenceFull = '(Reference Full)'
            }
            if($run.status -notin $finishedStates){
                $cancelling = ''
                $reason = ''
                if($run.expiryTimeUsecs -and $nowUsecs -gt $run.expiryTimeUsecs){
                    $reason = '(Outdated)'
                    if($cancelOutdated){
                        $cancelling = '(Cancelling)'
                        if(!$commit){
                            $cancelling = '(Would Cancel)'
                        }
                    }
                }
                if($cancelQueued){
                    $reason = '(Queued)'
                    $cancelling = '(Cancelling)'
                    if(!$commit){
                        $cancelling = '(Would Cancel)'
                    }
                }
                if($cancelOlderThan -gt 0){
                    $reason = "(older than $cancelOlderThan)"
                    $cancelling = '(Cancelling)'
                    if(!$commit){
                        $cancelling = '(Would Cancel)'
                    }
                }
                if($cancelAll){
                    $cancelling = '(Cancelling)'
                    if(!$commit){
                        $cancelling = '(Would Cancel)'
                    }
                }
                "    $($run.status)  $(usecsToDate $($run.startTimeUsecs))  [$($run.targetName)]  ($($run.transferred))  $referenceFull  $reason  $cancelling"
                if($commit -and $cancelling -ne ''){
                    if($cluster.clusterSoftwareVersion -gt '6.8'){
                        $cancelParams = @{
                            "action" = "Cancel";
                            "cancelParams" = @(
                                @{
                                    "runId" = $run.runId;
                                    "archivalTaskId" = @(
                                        $run.taskId
                                    )
                                }
                            )
                        }
                        $null = api post -v2 "data-protect/protection-groups/$jobId/runs/actions" $cancelParams
                    }else{
                        $cancelParams = @{
                            "archivalTaskId" = @(
                                    $run.taskId
                            )
                        }
                        $null = api post -v2 "data-protect/protection-groups/$jobId/runs/$($run.runId)/cancel" $cancelParams                            
                    }
                }
            }else{
                if($showFinished){
                    "    $($run.status)  $(usecsToDate $($run.startTimeUsecs))  [$($run.targetName)]  ($($run.transferred))  $referenceFull"
                }
            }
        }
    }
}
