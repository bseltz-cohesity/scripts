[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int64]$nth = 1,
    [Parameter()][ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')][string]$dayOfWeek = 'Sunday',
    [Parameter()][array]$jobname,
    [Parameter()][string]$jobList = '',
    [Parameter()][array]$policyName,
    [Parameter()][string]$policyList,
    [Parameter(Mandatory = $True)][int64]$daysToKeep,
    [Parameter()][switch]$includeReplicas,
    [Parameter()][switch]$commit
)

if($nth -ne -1 -and ($nth -lt 1 -or $nth -gt 4)){
    Write-Host "Invalid nth" -ForegroundColor Yellow
    exit
}

# gather job names
$jobsToUpdate = @()
foreach($job in $jobName){
    $jobsToUpdate += $job
}
if ('' -ne $jobList){
    if(Test-Path -Path $jobList -PathType Leaf){
        $jobs = Get-Content $jobList
        foreach($job in $jobs){
            $jobsToUpdate += [string]$job
        }
    }else{
        Write-Warning "job list $jobList not found!"
        exit
    }
}

# gather policy names
$policiesToUpdate = @()
foreach($policy in $policyName){
    $policiesToUpdate += $policy
}
if ('' -ne $policyList){
    if(Test-Path -Path $policyList -PathType Leaf){
        $policies = Get-Content $policyList
        foreach($policy in $policies){
            $policiesToUpdate += [string]$policy
        }
    }else{
        Write-Warning "job list $policyList not found!"
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$jobs = (api get -v2 data-protect/protection-groups).protectionGroups | Where-Object isDeleted -ne $True
if($jobsToUpdate.Length -gt 0){
    $jobs = $jobs | Where-Object name -in $jobsToUpdate
}

if(!$includeReplicas){
    $jobs = $jobs | Where-Object isActive -eq $True
}

$policies = (api get -v2 data-protect/policies).policies
if($policiesToUpdate.Length -gt 0){
    $policies = $policies | Where-Object name -in $policiesToUpdate
    $jobs = $jobs | Where-Object {$_.policyId -in @($policies.id)}
}

$lastMonth = timeAgo 31 days

if($commit){
    "`nScript started: $(Get-Date)`n" | Out-File -FilePath extendLog.txt -Append
}

$daysOfMonths = @(0,31,28,31,30,31,30,31,31,30,31,30,31)

foreach($job in $jobs | Sort-Object -Property name){
    $jobReported = $false
    $job.name
    $runs = (api get -v2 "data-protect/protection-groups/$($job.id)/runs?startTimeUsecs=$lastMonth&numRuns=9999&includeObjectDetails=false&runTypes=kSystem,kIncremental,kFull").runs
    # select unexpired runs
    $runs = $runs | Where-Object {$_.isLocalSnapshotsDeleted -ne $True -and ((usecsToDate $_.localBackupInfo.startTimeUsecs).dayOfWeek -eq $dayOfWeek -or (usecsToDate $_.originalBackupInfo.startTimeUsecs).dayOfWeek -eq $dayOfWeek)}

    foreach($run in $runs){
        if($run.isReplicationRun -eq $True){
            $startTimeUsecs = $run.originalBackupInfo.startTimeUsecs
        }else{
            $startTimeUsecs = $run.localBackupInfo.startTimeUsecs
        }
        $runDate = usecsToDate $startTimeUsecs

        # if run occured on the nth <day of week> of the month
        if($nth -eq -1){  
            $lastDayOfMonth = $daysOfMonths[$runDate.month]
            if($lastDayOfMonth -eq 28 -and [datetime]::IsLeapYear($runDate.year)){
                $lastDayOfMonth = 29
            }
            $endDay = $lastDayOfMonth
            $startDay = $lastDayOfMonth - 7
        }else{
            $startDay = 7 * ($nth - 1)
            $endDay = 7 * $nth
        }
        $runDay = (usecsToDate $startTimeUsecs).day
        if($runDay -gt $startDay -and $runDay -le $endDay){
            $thisrun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&excludeTasks=true&id=$($job.id.split(':')[-1])"
            # calculate days to extend
            $currentExpireTimeUsecs = ($thisrun.backupJobRuns.protectionRuns[0].copyRun.finishedTasks | Where-Object {$_.snapshotTarget.type -eq 1}).expiryTimeUsecs
            $currentExpireDate = (usecsToDate $currentExpireTimeUsecs).ToString('yyyy-MM-dd')
            $newExpireTimeUsecs = $startTimeUsecs + ($daysToKeep * 86400000000)
            $newExpireDate = (usecsToDate $newExpireTimeUsecs).ToString('yyyy-MM-dd')
            $daysToExtend = [int][math]::Round(($newExpireTimeUsecs - $currentExpireTimeUsecs) / 86400000000)

            if($daysToExtend -gt 0){
                "    {0} ($currentExpireDate -> $newExpireDate)" -f $runDate
                $runParameters = @{
                    "jobRuns"= @(
                        @{
                            "jobUid" = @{
                                "clusterId" = $thisrun.backupJobRuns.protectionRuns[0].copyRun.jobUid.clusterId;
                                "clusterIncarnationId" = $thisrun.backupJobRuns.protectionRuns[0].copyRun.jobUid.clusterIncarnationId;
                                "id" = $thisrun.backupJobRuns.protectionRuns[0].copyRun.jobUid.objectId
                            }
                            "runStartTimeUsecs" = $startTimeUsecs;
                            "copyRunTargets" = @(
                                @{
                                    "daysToKeep" = [int] $daysToExtend;
                                    "type" = "kLocal"
                                }
                            )
                        }
                    )
                }
                if($commit){
                    if($false -eq $jobReported){
                        "    $($job.name)" | Out-File -FilePath extendLog.txt -Append
                        $jobReported = $True
                    }
                    "        {0} ($currentExpireDate -> $newExpireDate)" -f $runDate | Out-File -FilePath extendLog.txt -Append
                    $null = api put protectionRuns $runParameters
                }
            }
        }
    }
}
