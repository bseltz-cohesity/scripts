### process commandline arguments
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
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory=$True)][string]$myName,
    [Parameter()][switch]$wait,
    [Parameter()][int]$sleepTimeSec = 360,
    [Parameter()][switch]$interactive,
    [Parameter()][int64]$cacheWaitTime = 60,
    [Parameter()][int64]$timeoutSec = 300
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

if(! $interactive){
    Start-Sleep $cacheWaitTime
    if($sleepTimeSec -lt 120){
        $sleepTimeSec = 120
    }
}else{
    if($sleepTimeSec -lt 30){
        $sleepTimeSec = 30
    }
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')

$search = api get /searchvms?vmName=$myName -timeout $timeoutSec
$searchResults = $search.vms | Where-Object {$_.vmDocument.objectName -eq $myName}
if(! $searchResults){
    Write-Host "No backups found for $myName"
    exit 0
}

$backupsRunning = $False
foreach($result in $searchResults){
    $jobName = $result.vmDocument.jobName
    $jobId = $result.vmDocument.objectId.jobId
    $lastRunTime = $result.vmDocument.versions[0].instanceId.jobStartTimeUsecs + 1
    $sourceId = $result.vmDocument.objectId.entity.id
    $newRuns = api get "protectionRuns?jobId=$jobId&startTimeUsecs=$lastRunTime&sourceId=$sourceId&numRuns=1&useCachedData=true" -timeout $timeoutSec
    if($newRuns){
        if($newRuns[0].backupRun.status -notin $finishedStates){
            $sourceBackupStatus = $newRuns[0].backupRun.sourceBackupStatus | Where-Object {$_.source.id -eq $sourceId}
            $progressPath = $sourceBackupStatus.progressMonitorTaskPath
            $progressMonitor = api get "/progressMonitors?taskPathVec=$progressPath&excludeSubTasks=true&includeFinishedTasks=false" -timeout $timeoutSec
            $progress = $progressMonitor.resultGroupVec[0].taskVec[0].progress
            if(! $progress.PSObject.Properties['endTimeSecs']){
                $backupsRunning = $True
                Write-Host "$jobName is currently backing me up"
                if($wait){
                    Write-Host "Waiting for backup to finish..."
                    while($True){
                        Start-Sleep $sleepTimeSec
                        $progressMonitor = api get "/progressMonitors?taskPathVec=$progressPath&excludeSubTasks=true&includeFinishedTasks=false" -timeout $timeoutSec
                        $progress = $progressMonitor.resultGroupVec[0].taskVec[0].progress
                        if($progress.PSObject.Properties['endTimeSecs']){
                            Write-Host "Backup completed"
                            break
                        }
                    }
                }else{
                    exit 1
                }
            }
        }
    }
}
if($backupsRunning -eq $False){
    Write-Host "no backups running"
}
exit 0
