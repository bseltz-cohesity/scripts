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

$jobs = api get protectionJobs

$lastProgressPath = ''
foreach($job in $jobs | Where-Object {$_.isActive -ne $False} | Sort-Object -Property name){
    if(! $jobName -or $job.name -in $jobName){
        "$($job.name)"
        $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$daysBackUsecs" # | Where-Object {$_.backupRun.snapshotsDeleted -eq $false}
        foreach($run in $runs){
            $runId = $run.backupRun.jobRunId
            $runStatus = $run.backupRun.status
            $runDate = usecsToDate $run.backupRun.stats.startTimeUsecs
            $outFile = Join-Path -Path $outPath -ChildPath "$($job.name)-$($runDate.ToString('yyyy-MM-dd-hh-mm-ss'))-$($runStatus)-logs.txt"
            "    $runDate -> $outFile"
            if(! (Test-Path -Path $outFile)){
                foreach($source in $run.backupRun.sourceBackupStatus){
                    $sourceName = $source.source.name
                    $sourceStatus = $source.status
                    "`n$sourceName ($sourceStatus)`n" | Out-File -FilePath $outFile -Append
                    $progressPath, $taskPath = $source.progressMonitorTaskPath.split('/')
                    if($lastProgressPath -ne $progressPath){
                        $taskMon = api get "/progressMonitors?taskPathVec=$progressPath&includeFinishedTasks=true&excludeSubTasks=false"
                        $lastProgressPath = $progressPath
                    }
                    $thisTask = $taskMon.resultGroupVec[0].taskVec | Where-Object {$_.taskPath -eq $progressPath}
                    $thisSubTask = $thisTask.subTaskVec | Where-Object {$_.taskPath -eq $taskPath}
                    $events = $thisSubTask.progress.eventVec
                    foreach($event in $events){
                        "$(usecsToDate ($event.timeStampSecs * 1000000)): $($event.eventMsg)" | Out-File -FilePath $outFile -Append
                    }
                }
            }
        }
    }
}
