# usage: ./archiveOldSnapshots.ps1 -vip mycluster `
#                                  -username admin `
#                                  -domain local `
#                                  -vault S3 `
#                                  -jobName myjob1, myjob2
#                                  -keepFor 365

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$jobNames, # jobs to archive
    [Parameter(Mandatory = $True)][string]$vault, #name of archive target
    [Parameter()][ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','unselected')][string]$dayOfWeek = 'unselected',
    [Parameter()][int]$dayOfMonth,
    [Parameter()][int]$dayOfYear,
    [Parameter()][int64]$runId,
    [Parameter()][int]$keepFor, #set archive retention to x days from backup date
    [Parameter()][int]$pastSearchDays = 31,
    [Parameter()][int]$maxDrift = 3,
    [Parameter()][switch]$commit,
    [Parameter()][switch]$localOnly,
    [Parameter()][switch]$firstOfMonth,
    [Parameter()][ValidateSet('kCloud','kTape','kNas')][string]$vaultType = 'kCloud'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get archive target info
$vaults = api get vaults | Where-Object { $_.name -eq $vault }
if (!$vaults) {
    Write-Warning "Archive Target $vault not found"
    exit
}
$vaultName = $vaults[0].name
$vaultId = $vaults[0].id

# calculate dates
$searchTimeUsecs = dateToUsecs ((get-date).AddDays(-$pastSearchDays))
$monthDays = @(0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 20, 31)

$desiredDayOfMonth = $dayOfMonth
$desiredDayOfYear = $dayOfYear

# find specified jobs
$cluster = api get cluster
$jobs = api get protectionJobs
if($localOnly){
    $jobs = $jobs | Where-Object {$_.policyId.split(':')[0] -eq $cluster.id}
}

if($jobNames){
    $jobs = $jobs | Where-Object name -in $jobNames
}

foreach($job in $jobs){

    $weekdayBurn = 0
    # find latest local snapshot that has not been archived yet
    $runs = (api get protectionRuns?jobId=$($job.id)`&numRuns=9999`&runTypes=kRegular`&runTypes=kFull`&excludeTasks=true`&startTimeUsecs=$searchTimeUsecs) | `
        Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
        Where-Object { !('kArchival' -in $_.copyRun.target.type) -or ($_.copyRun | Where-Object { $_.target.type -eq 'kArchival' -and $_.status -in @('kCanceled','kFailed') }) } | `
        Sort-Object -Property {$_.copyRun[0].runStartTimeUsecs}

    $dailyRuns = $runs | Group-Object -Property {(usecsToDate $_.copyRun[0].runStartTimeUsecs).DayOfYear}, {(usecsToDate $_.copyRun[0].runStartTimeUsecs).Year}

    foreach($dayRuns in $dailyRuns){
        $selectedRun = $null
        $theseruns = $dayRuns.Group | Sort-Object -Property {$_.copyRun[0].runStartTimeUsecs}
        $run = $theseruns[-1] # last run of the day
        $lastDayOfYear = 365
        $jobName = $run.jobName
        $status = $run.backupRun.status
        $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
        # adjust last day of year for leap year
        if($dayOfYear -eq -1){
            $dayOfYear = 365
            if([datetime]::IsLeapYear($runDate.Year)){
                $dayOfYear = 366
                $lastDayOfYear = 366
            }
        }
        # adjust last day of february for leap year
        if($dayOfMonth -eq -1){
            $dayOfMonth = $monthDays[$runDate.Month]
            if($runDate.Month -eq 2 -and [datetime]::IsLeapYear($runDate.Year)){
                $dayOfMonth += 1
            }
        }

        # select specific, yearly, monthly, weekly or daily snapshot
        if($runId){
            if($run.backupRun.jobRunId -eq $runId){
                $selectedRun = $run
            }
        }elseif($dayOfYear){
            if($runDate.DayOfYear -eq $dayOfYear){
                # drift forward if yearly snapshot failed
                if($status -ne 'kSuccess'){
                    if($dayOfYear -le ($desiredDayOfYear + $maxDrift)){
                        $dayOfYear += 1
                        if($dayOfYear -gt $lastDayOfYear){
                            $dayOfYear = 1
                            $desiredDayOfYear = 0
                        }
                    }
                }else{
                    $selectedRun = $run
                }
            }
        }elseif($dayOfMonth){
            if($runDate.Day -eq $dayOfMonth){
                # drift forward if monthly snapshot failed
                if($status -ne 'kSuccess'){
                    if($dayOfMonth -le ($desiredDayOfMonth + $maxDrift)){
                        $dayOfMonth += 1
                        if($dayOfMonth -gt $monthDays[$runDate.Month]){
                            $dayOfMonth = 1
                            $desiredDayOfMonth = 0
                        }
                    }
                }else{
                    $selectedRun = $run
                }
            }
        }elseif($dayOfWeek -ne 'unselected'){
            if($runDate.DayOfWeek -eq $dayOfWeek -and (!$firstOfMonth -or $runDate.Day -le 7)){
                # drift forward if weekly snapshot failed
                if($status -ne 'kSuccess'){
                    if($dayOfWeek -eq 'Sunday' -and $weekdayBurn -lt $maxDrift){
                        $dayOfWeek = 'Monday'
                        $weekdayBurn += 1
                    }elseif($dayOfWeek -eq 'Monday' -and $weekdayBurn -lt $maxDrift){
                        $dayOfWeek = 'Tuesday'
                        $weekdayBurn += 1
                    }elseif($dayOfWeek -eq 'Tuesday' -and $weekdayBurn -lt $maxDrift){
                        $dayOfWeek = 'Wednesday'
                        $weekdayBurn += 1
                    }elseif($dayOfWeek -eq 'Wednesday' -and $weekdayBurn -lt $maxDrift){
                        $dayOfWeek = 'Thursday'
                        $weekdayBurn += 1
                    }elseif($dayOfWeek -eq 'Thursday' -and $weekdayBurn -lt $maxDrift){
                        $dayOfWeek = 'Friday'
                        $weekdayBurn += 1
                    }elseif($dayOfWeek -eq 'Friday' -and $weekdayBurn -lt $maxDrift){
                        $dayOfWeek = 'Saturday'
                        $weekdayBurn += 1
                    }elseif($dayOfWeek -eq 'Saturday' -and $weekdayBurn -lt $maxDrift){
                        $dayOfWeek = 'Sunday'
                        $weekdayBurn += 1
                    }
                }else{
                    $selectedRun = $run
                }
            }
        }else{
            $selectedRun = $run
        }
        if($selectedRun){
            break
        }
    }

    if($selectedRun){
        $run = $selectedRun

        $now = dateToUsecs $(get-date)

        # local snapshots stats
        $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
        $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs

        # get jobUid of originating cluster
        $runDetail = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&excludeTasks=true&id=$($run.jobId)"
        $jobUid = $runDetail[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid

        # calculate archive expire time
        if($keepFor){
            $newExpireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
        }else{
            $newExpireTimeUsecs = $expireTimeUsecs
        }
        $daysToKeep = [math]::Round(($newExpireTimeUsecs - $now) / 86400000000) 
        $expireDate = usecsToDate $newExpireTimeUsecs

        # create archive task definition
        $archiveTask = @{
            'jobRuns' = @(
                @{
                    'copyRunTargets'    = @(
                        @{
                            'archivalTarget' = @{
                                'vaultId'   = $vaultId;
                                'vaultName' = $vaultName;
                                'vaultType' = $vaultType
                            };
                            'daysToKeep'     = [int] $daysToKeep;
                            'type'           = 'kArchival'
                        }
                    );
                    'runStartTimeUsecs' = $run.copyRun[0].runStartTimeUsecs;
                    'jobUid'            = @{
                        'clusterId' = $jobUid.clusterId;
                        'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                        'id' = $jobUid.objectId
                    }
                }
            )
        }
        # submit the archive task
        if($commit){
            write-host "Archiving $($jobName) ($runDate) --> $vaultName ($expireDate)"
            $null = api put protectionRuns $archiveTask
        }else{
            write-host "Would archive $($jobName) ($runDate) --> $vaultName ($expireDate)"
        }
    }
}
