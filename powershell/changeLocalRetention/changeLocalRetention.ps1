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

# filter on job name (V2 protection groups API)
$jobs = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.isDeleted -ne $True}
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

# a run backed up directly on this cluster has 'localBackupInfo'; a run replicated in from
# another cluster has 'originalBackupInfo' instead (no 'localBackupInfo' at all)
function getRunBackupInfo($run){
    if($run.PSObject.Properties['localBackupInfo'] -and $run.localBackupInfo){
        return $run.localBackupInfo
    }elseif($run.PSObject.Properties['originalBackupInfo'] -and $run.originalBackupInfo){
        return $run.originalBackupInfo
    }else{
        return $null
    }
}

# same local/replicated split applies per-object: 'localSnapshotInfo' for locally backed up
# objects, 'originalBackupInfo' for objects that arrived via replication
function getObjectExpiry($object){
    if($object.PSObject.Properties['localSnapshotInfo'] -and $object.localSnapshotInfo -and $object.localSnapshotInfo.snapshotInfo -and $null -ne $object.localSnapshotInfo.snapshotInfo.expiryTimeUsecs){
        return $object.localSnapshotInfo.snapshotInfo.expiryTimeUsecs
    }elseif($object.PSObject.Properties['originalBackupInfo'] -and $object.originalBackupInfo -and $object.originalBackupInfo.snapshotInfo -and $null -ne $object.originalBackupInfo.snapshotInfo.expiryTimeUsecs){
        return $object.originalBackupInfo.snapshotInfo.expiryTimeUsecs
    }else{
        return $null
    }
}

function changeRetention($run, $backupInfo, $jobUrlId, $jobName){
    # V2 run object (from data-protect/protection-groups/{id}/runs, with includeObjectDetails=true)
    $startDateUsecs = $backupInfo.startTimeUsecs
    $startDate = usecsToDate $startDateUsecs
    $newExpireUsecs = [int64](dateToUsecs $startDate.addDays($daysToKeep))
    $newExpireDate = usecsToDate $newExpireUsecs

    # current expiry lives per-object (there's no run-level expiry field in V2) - all objects in
    # a run share the same retention, so the first object with a valid expiry is representative
    $oldExpireUsecs = $null
    foreach($object in $run.objects){
        $expiry = getObjectExpiry $object
        if($null -ne $expiry){
            $oldExpireUsecs = $expiry
            break
        }
    }
    if($null -eq $oldExpireUsecs){
        Write-Host "No snapshot expiry found for $jobName ($($startDate)) - skipping" -ForegroundColor Yellow
        return
    }

    if($newExpireUsecs -gt $oldExpireUsecs){
        $daysToChange = [int][math]::Round(($newExpireUsecs - $oldExpireUsecs) / 86400000000)
    }else{
        $daysToChange = -([int][math]::Round(($oldExpireUsecs - $newExpireUsecs) / 86400000000))
    }
    if($daysToChange -eq 0){
        Write-Host "Retention for $jobName ($($startDate)) to $newExpireDate remains unchanged"
    }else{
        if(!$allowReduction -and $daysToChange -lt 0){
            Write-Host "Would reduce Retention for $jobName ($($startDate)) to $newExpireDate - skipping"
        }else{
            if($commit){
                $editRun = @{
                    'updateProtectionGroupRunParams' = @(
                        @{
                            'runId'                     = $run.id;
                            'replicationSnapshotConfig' = @{};
                            'localSnapshotConfig'       = @{
                                'daysToKeep' = $daysToChange
                            }
                        }
                    )
                }
                write-host "Changing retention for $jobName ($($startDate)) to $newExpireDate"
                $null = api put -v2 "data-protect/protection-groups/$jobUrlId/runs" $editRun
            }else{
                Write-Host "Would change retention for $jobName ($($startDate)) to $newExpireDate"
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
    $myBackupType = "kIncremental,kFull,kSystem"
}elseif($backupType -eq 'kRegular'){
    # V1 'kRegular' is called 'kIncremental' in the V2 API
    $myBackupType = "kIncremental"
}else{
    $myBackupType = $backupType
}

foreach($job in $myjoblist){
    $runs = (api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$maxRuns&runTypes=$myBackupType&startTimeUsecs=$afterUsecs&endTimeUsecs=$beforeUsecs&excludeNonRestorableRuns=true&includeObjectDetails=true").runs
    foreach($run in $runs){
        $backupInfo = getRunBackupInfo $run
        if(!$backupInfo){
            continue
        }
        if($run.isLocalSnapshotsDeleted -eq $True){
            continue
        }
        if($backupInfo.startTimeUsecs -le $afterUsecs -or $backupInfo.endTimeUsecs -gt $beforeUsecs){
            continue
        }
        changeRetention $run $backupInfo $job.id $job.name
    }
}
