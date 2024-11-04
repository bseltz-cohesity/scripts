# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter(Mandatory = $True)][string]$remoteCluster,
    [Parameter()][ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','unselected')][string]$dayOfWeek = 'unselected',
    [Parameter()][int]$dayOfMonth,
    [Parameter()][int]$dayOfYear,
    [Parameter()][int64]$runId,
    [Parameter()][int]$keepFor, #set replica retention to x days from backup date
    [Parameter()][int]$pastSearchDays = 31,
    [Parameter()][int]$maxDrift = 3,
    [Parameter()][switch]$commit,
    [Parameter()][switch]$cascade,
    [Parameter()][switch]$firstOfMonth
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

$jobs = api get "protectionJobs"

# get remote cluster
$remote = api get remoteClusters | Where-Object {$_.name -eq $remoteCluster}
if(!$remote){
    Write-Warning "Replication target $remoteCluster not found"
    exit 1
}

# calculate dates
$searchTimeUsecs = dateToUsecs ((get-date).AddDays(-$pastSearchDays))
$monthDays = @(0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 20, 31)

$desiredDayOfMonth = $dayOfMonth
$desiredDayOfYear = $dayOfYear

$ignoreJobTypes = @('kRDSSnapshotManager', 'kAWSSnapshotManager', 'kSnapshotManager', 'kAuroraSnapshotManager')

# find specified jobs
$cluster = api get cluster
$jobs = api get protectionJobs | Where-Object {$_.policyId.split(':')[0] -ne $remote.clusterId}

if(! $cascade){
    $jobs = $jobs | Where-Object {$_.policyId.split(':')[0] -eq $cluster.id}
}

$jobs = $jobs | Where-Object {$_.environment -notin $ignoreJobTypes}

if($jobNames.Count -gt 0){
    $jobs = $jobs | Where-Object name -in $jobNames
}

# catch invalid job names
if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$replicatedRunIds = @()
$successStatus = @('kSuccess', 'kWarning', 4, 6)


foreach($job in $jobs){
    $weekdayBurn = 0
    # find latest local snapshot that has not been replicated yet
    $runs = (api get protectionRuns?jobId=$($job.id)`&numRuns=9999`&runTypes=kRegular`&runTypes=kFull`&excludeTasks=true`&startTimeUsecs=$searchTimeUsecs) | `
        Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
        Where-Object { !('kRemote' -in $_.copyRun.target.type) -or ($_.copyRun | Where-Object { $_.target.type -eq 'kRemote' -and ($_.target.replicationTarget.clusterName -ne $remoteCluster -or $_.status -in @('kCanceled','kFailed')) }) } | `
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
                if($status -notin $successStatus){
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
                if($status -notin $successStatus){
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
                if($status -notin $successStatus){
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
        $thisRunId = $runDetail[0].backupJobRuns.protectionRuns[0].backupRun.base.jobInstanceId
        # calculate replica expire time
        if($keepFor){
            $newExpireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
        }else{
            $newExpireTimeUsecs = $expireTimeUsecs
        }
        $daysToKeep = [math]::Round(($newExpireTimeUsecs - $now) / 86400000000) 
        $expireDate = usecsToDate $newExpireTimeUsecs

        # create replication task definition
        $replicationTask = @{
            'jobRuns' = @(
                @{
                    'copyRunTargets'    = @(
                        @{
                            "replicationTarget" = @{
                                "clusterId" = $remote.clusterId;
                                "clusterName" = $remote.name
                            };
                            'daysToKeep'     = [int] $daysToKeep;
                            'type'           = 'kRemote'
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
        # submit the replication task
        if($thisRunId -notin $replicatedRunIds){
            if($commit){
                write-host "Replicating $($jobName) ($runDate) --> $remoteCluster ($expireDate)"
                $null = api put protectionRuns $replicationTask
            }else{
                write-host "Would replicate $($jobName) ($runDate) --> $remoteCluster ($expireDate)"
            }
            $replicatedRunIds = @($replicatedRunIds + $thisRunId)
        }
    }
}
