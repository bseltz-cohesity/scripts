### Usage:
# ./changeLocalRetention.ps1 -vip mycluster `
#                            -username myuser `
#                            -domain mydomain.net `
#                            -jobname 'My Job' `
#                            -snapshotDate '2020-05-01 23:30' `
#                            -daysToKeep 10 `
#                            -force

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$jobname,
    [Parameter()][string]$snapshotDate = $null,
    [Parameter(Mandatory = $True)][string]$daysToKeep,
    [Parameter()][ValidateSet("kRegular","kFull","kLog","kSystem","kAll")][string]$backupType = 'kAll',
    [Parameter()][int]$maxRuns = 100000,
    [Parameter()][switch]$force
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# parse date
if($snapshotDate){
    $dt, $tm = $snapshotDate -split ' '
    $year, $month, $day = $dt -split '-'
    $hour, $minute, $second = $tm -split ':'
}

# filter on job name
$jobs = api get protectionJobs
$joblist = @()
if($jobname.Length -gt 0){
    foreach($j in $jobname){
        $job = $jobs | Where-Object {$_.name -eq $j}
        if($job){
            $joblist += $job
        }else{
            Write-Host "Job $j not found" -ForegroundColor Yellow
            exit
        }
    }
}else{
    $joblist = $jobs
}

function changeRetention($run){
    $startDateUsecs = $run.backupRun.stats.startTimeUsecs
    $startDate = usecsToDate $startDateUsecs
    $newExpireUsecs = [int64](dateToUsecs $startDate.addDays($daysToKeep))
    $newExpireDate = usecsToDate $newExpireUsecs
    $oldExpireUsecs = $run.copyRun[0].expiryTimeUsecs
    if($newExpireUsecs -gt $oldExpireUsecs){
        $daysToChange = [int][math]::Round(($newExpireUsecs - $oldExpireUsecs) / 86400000000)
    }else{
        $daysToChange = -([int][math]::Round(($oldExpireUsecs - $newExpireUsecs) / 86400000000))
    }
    write-host "Changing retention for $($run.jobName) ($($startDate)) to $newExpireDate"
    if($force){
        $editRun = @{
            'jobRuns' = @(
                @{
                    'jobUid'            = $run.jobUid;
                    'runStartTimeUsecs' = $startDateUsecs;
                    'copyRunTargets'    = @(
                        @{'daysToKeep' = $daysToChange;
                            'type'     = 'kLocal';
                        }
                    )
                }
            )
        }
        $null = api put protectionRuns $editRun
    }
}

foreach($job in $joblist){
    if($snapshotDate){
        $startTimeUsecs = dateToUsecs $snapshotDate
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$maxRuns&runTypes=$backupType&excludeTasks=true&excludeNonRestoreableRuns=true&startTimeUsecs=$startTimeUsecs" | Where-Object {$_.backupRun.snapshotsDeleted -ne $True}
    }else{
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$maxRuns&runTypes=$backupType&excludeTasks=true&excludeNonRestoreableRuns=true" | Where-Object {$_.backupRun.snapshotsDeleted -ne $True}
    }
    foreach($run in $runs){
        if($snapshotDate){
            $startTime = usecsToDate $run.backupRun.stats.startTimeUsecs
            if($startTime.Year -eq $year -and $startTime.Month -eq $month -and $startTime.Day -eq $day){
                if(!($hour -and $startTime.Hour -ne $hour)){
                    if(!($minute -and $startTime.Minute -ne $minute)){
                        if(!($second -and $startTime.Second -ne $second)){
                            changeRetention $run
                        }
                    }
                }
            }
        }else{
            changeRetention $run
        }
    }
}
