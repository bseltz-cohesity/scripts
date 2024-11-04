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
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][array]$jobMatch,
    [Parameter()][DateTime]$after,
    [Parameter()][DateTime]$before,
    [Parameter(Mandatory = $True)][string]$daysToKeep,
    [Parameter()][ValidateSet("kRegular","kFull","kLog","kSystem","AllExceptLogs")][string]$backupType = 'AllExceptLogs',
    [Parameter()][int]$maxRuns = 100000,
    [Parameter()][switch]$commit,
    [Parameter()][switch]$allowReduction
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
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

# filter on job name
$jobs = api get protectionJobs
$myjoblist = @()
if($jobNames.Length -gt 0){
    foreach($j in $jobNames){
        $job = $jobs | Where-Object {$_.name -eq $j}
        if($job){
            $myjoblist += $job
        }else{
            Write-Host "Job $j not found" -ForegroundColor Yellow
            exit
        }
    }
}else{
    $myjoblist = $jobs
}

$matchJobList = @()
if($jobMatch.Length -gt 0){
    foreach($job in $myjoblist){
        $includeJob = $false
        foreach($matchString in $jobMatch){
            if($job.name -match $matchString){
                $includeJob = $True
            }
        }
        if($includeJob -eq $True){
            $matchJobList += $job
        }
    }
    $myjoblist = @($matchJobList)
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
    if($daysToChange -eq 0){
        Write-Host "Retention for $($run.jobName) ($($startDate)) to $newExpireDate remains unchanged"
    }else{
        if(!$allowReduction -and $daysToChange -lt 0){
            Write-Host "Would reduce Retention for $($run.jobName) ($($startDate)) to $newExpireDate - skipping"
        }else{
            if($commit){
                $exactRun = api get /backupjobruns?exactMatchStartTimeUsecs=$startDateUsecs`&id=$($run.jobId)
                $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                $editRun = @{
                    'jobRuns' = @(
                        @{
                            'jobUid'            = @{
                                'clusterId' = $jobUid.clusterId;
                                'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                                'id' = $jobUid.objectId
                            };
                            'runStartTimeUsecs' = $startDateUsecs;
                            'copyRunTargets'    = @(
                                @{'daysToKeep' = $daysToChange;
                                    'type'     = 'kLocal';
                                }
                            )
                        }
                    )
                }
                write-host "Changing retention for $($run.jobName) ($($startDate)) to $newExpireDate"
                $null = api put protectionRuns $editRun
            }else{
                Write-Host "Would change retention for $($run.jobName) ($($startDate)) to $newExpireDate"
            }
        }
    }
}

if($after){
    $afterUsecs = dateToUsecs $after
}else{
    $afterUsecs = 0
}

if($before){
    $beforeUsecs = dateToUsecs $before
}else{
    $beforeUsecs = dateToUsecs
}

if($backupType -eq 'AllExceptLogs'){
    $myBackupType = "kIncremental&runTypes=kFull&runTypes=kSystem"
}else{
    $myBackupType = $backupType
}

foreach($job in $myjoblist){
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$maxRuns&runTypes=$myBackupType&excludeTasks=true&excludeNonRestoreableRuns=true" | Where-Object {$_.backupRun.snapshotsDeleted -ne $True -and
                                                                                                                                                             $_.backupRun.stats.startTimeUsecs -gt $afterUsecs -and                                                                                                                                                     
                                                                                                                                                             $_.backupRun.stats.endTimeUsecs -le $beforeUsecs}
    foreach($run in $runs){
        changeRetention $run
    }
}
