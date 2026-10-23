# usage: ./pulseLogs.ps1 -vip mycluster -username myuser -domain mydomain.net -jobName 'My Job'

# process commandline arguments
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
    [Parameter()][string]$outPath = './pulseLogs',
    [Parameter()][array]$jobName,
    [Parameter()][int]$daysBack = 1
)

$null = New-Item -ItemType Directory -Path $outPath -Force

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

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

$daysBackUsecs = timeAgo $daysBack days

# v2 protection groups
$jobs = api get -v2 "data-protect/protection-groups?includeTenants=true"

# write events (v2 ProgressTaskEvent: occuredAtUsecs, message) to the log file
function writeEvents($events, $outFile){
    foreach($event in $events){
        "$(usecsToDate $event.occuredAtUsecs): $($event.message)" | Out-File -FilePath $outFile -Append
    }
}

foreach($job in $jobs.protectionGroups | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $False} | Sort-Object -Property name){
    if(! $jobName -or $job.name -in $jobName){
        "$($job.name)"
        $runs = Get-Runs -jobId $job.id -startTimeUsecs $daysBackUsecs -includeObjectDetails -includeRunning -includeDeleted
        foreach($run in $runs){
            $runId = $run.id
            if($run.PSObject.Properties['localBackupInfo']){
                $backupInfo = $run.localBackupInfo
            }elseif($run.PSObject.Properties['originalBackupInfo']){
                $backupInfo = $run.originalBackupInfo
            }else{
                continue
            }
            $runStatus = $backupInfo.status
            $runDate = usecsToDate $backupInfo.startTimeUsecs
            $outFile = Join-Path -Path $outPath -ChildPath "$($job.name)-$($runDate.ToString('yyyy-MM-dd-hh-mm-ss'))-$($runStatus)-logs.txt"
            "    $runDate -> $outFile"

            if(! (Test-Path -Path $outFile)){
                # v2 run progress including event logs
                $progress = api get -v2 "data-protect/runs/$runId/progress?includeFinishedTasks=true&includeEventLogs=true&includeTenants=true"
                $progressObjects = @()
                if($progress.localRun -and $progress.localRun.PSObject.Properties['objects']){
                    $progressObjects = @($progress.localRun.objects)
                }
                foreach($object in $run.objects){
                    $sourceName = $object.object.name
                    $sourceStatus = $object.localSnapshotInfo.snapshotInfo.status
                    if(! $sourceStatus){
                        $sourceStatus = $object.localSnapshotInfo.status
                    }
                    "`n$sourceName ($sourceStatus)`n" | Out-File -FilePath $outFile -Append
                    $thisObjectProgress = @($progressObjects | Where-Object {$_.id -eq $object.object.id})
                    # child objects (e.g. SQL/Oracle databases) are not in the run-level progress: query by task path
                    $taskId = $object.localSnapshotInfo.snapshotInfo.progressTaskId
                    if($taskId){ # $thisObjectProgress.Count -eq 0 -and 
                        $runTaskPath = $taskId.split('/')[0]
                        $parentId = $object.object.sourceId
                        if(! $parentId){
                            $parentId = $object.object.id
                        }
                        $encodedTaskPath = [uri]::EscapeDataString($taskId)
                        $childProgress = api get -v2 "data-protect/runs/$runId/progress?runTaskPath=$runTaskPath&objects=$parentId&objectTaskPaths=$encodedTaskPath&includeFinishedTasks=true&includeEventLogs=true&includeTenants=true"
                        if($childProgress.localRun){
                            if($childProgress.localRun.PSObject.Properties['objects']){
                                $thisObjectProgress = @($childProgress.localRun.objects | Where-Object {$_.id -eq $object.object.id})
                                if($thisObjectProgress.Count -eq 0){
                                    $thisObjectProgress = @($childProgress.localRun.objects)
                                }
                            }else{
                                $thisObjectProgress = @($childProgress.localRun)
                            }
                        }
                    }
                    foreach($objectProgress in $thisObjectProgress){
                        # events from failed attempts first, then the final attempt
                        foreach($attempt in $objectProgress.failedAttempts){
                            writeEvents $attempt.events $outFile
                        }
                        writeEvents $objectProgress.events $outFile
                    }
                }
            }
        }
    }
}
