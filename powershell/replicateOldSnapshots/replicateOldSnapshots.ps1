# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][switch]$excludeLogs,
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][int]$olderThan,
    [Parameter()][int]$newerThan,
    [Parameter(Mandatory=$True)][string]$replicateTo,
    [Parameter()][switch]$resync,
    [Parameter()][int]$keepFor = 0,
    [Parameter()][switch]$commit
)

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

$cluster = api get cluster

### get replication target info
$remote = api get remoteClusters | Where-Object {$_.name -eq $replicateTo}
if(!$remote){
    Write-Warning "Replication target $replicateTo not found"
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

$jobs = api get -v2 "data-protect/protection-groups" # ?isDeleted=false"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

# set time range
$startTime = [Int64]($cluster.createdTimeMsecs * 1000)
$nowUsecs = dateToUsecs (Get-Date)
$endTime = dateToUsecs (Get-Date)
if($olderThan){
    $endTime = timeAgo $olderThan Days
}
if($newerThan){
    $startTime = timeAgo $newerThan Days
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $runsToReplicate = @{}
    $clusterId, $clusterIncarnationId, $v1JobId = $job.id -split ':'
    $jobuid = @{
        "clusterId" = [Int64]$clusterId;
        "clusterIncarnationId" =  [Int64]$clusterIncarnationId;
        "id" = [Int64]$v1JobId
    }
    $endUsecs = $endTime
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        Write-Host $job.name
        while($True){
            $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&startTimeUsecs=$startTime&endTimeUsecs=$endUsecs"
            foreach($run in $runs.runs){
                if(! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
                    if($run.PSObject.Properties['localBackupInfo']){
                        $backupInfo = $run.localBackupInfo
                    }else{
                        $backupInfo = $run.originalBackupInfo
                    }
                    $runStartTime = usecsToDate $backupInfo.startTimeUsecs
                    $status = $backupInfo.status
                    if($backupInfo.PSObject.Properties['endTimeUsecs']){
                        if(! $excludeLogs -or $backupInfo.runType -ne 'kLog'){
                            # check for replication
                            $replicated = $False
                            if($run.PSObject.Properties['replicationInfo']){
                                if($run.replicationInfo.PSObject.Properties['replicationTargetResults']){
                                    foreach($represult in $run.replicationInfo.replicationTargetResults){
                                        if($represult.clusterName -eq $replicateTo -and $represult.status -eq 'Succeeded'){
                                            $replicated=$True
                                            if($resync){
                                                $replicated = $False
                                            }
                                        }
                                    }
                                }
                            } 
                            if($replicated -eq $False){
                                $startTimeUsecs = $backupInfo.startTimeUsecs
                                if($keepfor -gt 0){
                                    $expireTimeUsecs = $startTimeUsecs + [Int64]($keepfor * 86400000000)
                                }else{
                                    $thisRun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&excludeTasks=true&id=$v1JobId"
                                    $expireTimeUsecs = $thisRun[0].backupJobRuns.protectionRuns[0].copyRun.finishedTasks[0].expiryTimeUsecs
                                }
    
                                $daysToKeep = [math]::Round(($expireTimeUsecs - $nowUsecs) / 86400000000, 0)
                                if($daysToKeep -eq 0){
                                    $daysToKeep = 1
                                }
                                if($commit){
                                    # create replication task definition
                                    $replicationTask = @{
                                        "jobRuns" = @(
                                            @{
                                                "copyRunTargets" = @(
                                                    @{
                                                        "replicationTarget" = @{
                                                            "clusterId" = $remote.clusterId;
                                                            "clusterName" = $remote.name
                                                        };
                                                        "daysToKeep" = [Int64]$daysToKeep;
                                                        "type" = "kRemote"
                                                    }
                                                );
                                                "runStartTimeUsecs" =  $startTimeUsecs;
                                                "jobUid" = $jobuid
                                            }
                                        )
                                    }
                                    Write-Host "  Replicating  $runStartTime  for $daysToKeep days"
                                    $runsToReplicate["$startTimeUsecs"] = $replicationTask
                                }else{
                                    Write-Host "  Would replicate $runStartTime for $daysToKeep days"
                                }    
                            }else{
                                Write-Host "  Already replicated $runStartTime"
                            }
                        }
                    }
                }
            }
            if($runs.runs.Count -eq $numRuns){
                if($run.PSObject.Properties['localBackupInfo']){
                    $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
                }else{
                    $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs - 1
                }
            }else{
                break
            }
        }
        if($runsToReplicate.Keys.Count -gt 0){
            Write-Host "    Performing replications in time order..."
        }
        foreach($startTimeUsecs in $runsToReplicate.Keys | sort){
            Write-Host "        $(usecsToDate $startTimeUsecs)"
            $null = api put protectionRuns $runsToReplicate["$startTimeUsecs"]
        }
    }
}

