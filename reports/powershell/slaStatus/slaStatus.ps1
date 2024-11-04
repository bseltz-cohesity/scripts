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
    [Parameter()][string]$outPath = '.',
    [Parameter()][int]$days = 1,
    [Parameter()][switch]$lastRunOnly,
    [Parameter()][int]$numRuns = 1000
)

### source the cohesity-api helper code
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

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')
$goodStates = @('kSuccess', 'kFailure', 'kWarning')
$now = Get-Date
$nowUsecs = timeAgo 1 minutes
$dateString = $now.ToString('yyyy-MM-dd')
$daysAgoUsecs = timeAgo $days days
if($lastRunOnly){
    $numRuns = 1
}
$cluster = api get cluster
$title = "Missed SLAs on $($cluster.name)"
$outFile = $(Join-Path -Path $outPath -ChildPath "slaStatus-$($cluster.name)-$dateString.csv")

$missesRecorded = $false
$message = ""

"Job Name,Run Date,Run Type,Status,Run Minutes,SLA Minutes,SLA Status,Replication Minutes" | Out-File -FilePath $outFile

"`nCollecting Job Stats...`n"
foreach($job in (api get protectionJobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false} | Sort-Object -Property name)){
    $jobId = $job.id
    $jobName = $job.name
    $jobName
    $sla = $job.incrementalProtectionSlaTimeMins
    if(!$sla){
        $sla = 60
    }
    $endUsecs = $nowUsecs

    while($True){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true&startTimeUsecs=$daysAgoUsecs"
        foreach($run in $runs){
            $slaPass = "Pass"
            $startTimeUsecs = $run.backupRun.stats.startTimeUsecs
            $status = $run.backupRun.status
            $runType = $run.backupRun.runType
            if($status -in $finishedStates){
                $endTimeUsecs = $run.backupRun.stats.endTimeUsecs
                $runTimeUsecs = $endTimeUsecs - $startTimeUsecs
            }else{
                $runTimeUsecs = $nowUsecs - $startTimeUsecs
            }
            $runTimeMinutes = [math]::Round(($runTimeUsecs / 60000000),0)
            if($runTimeMinutes -gt $sla){
                $slaPass = "Miss"
            }
            $replicationMinutes = 'N/A'
            $replicationRun = $run.copyRun | Where-Object {$_.target.type -eq 'kRemote'}
            if($replicationRun){
                if($replicationRun[0].status -in $goodStates){
                    $replicationUsecs = $replicationRun[0].stats.endTimeUsecs - $replicationRun[0].stats.startTimeUsecs
                    $replicationMinutes = [math]::Round(($replicationUsecs / 60000000),0)
                }
            }
            if($slaPass -eq "Miss"){
                $missesRecorded = $True
                if($run.backupRun.status -in $finishedStates){
                    $verb = "ran"
                }else{
                    $verb = "has been running"
                }
                $messageLine = "{0} (Missed SLA) {1} for {2} minutes (SLA: {3} minutes)" -f $jobName, $verb, $runTimeMinutes, $sla
                $messageLine
                $message += "$messageLine`n"
            }
            "{0},{1},{2},{3},{4},{5},{6},{7}" -f $jobName, (usecsToDate $startTimeUsecs), $runType.subString(1), $status.subString(1), $runTimeMinutes, $sla, $slaPass, $replicationMinutes | Out-File -FilePath $outFile -Append
            if($lastRunOnly){
                break
            }
        }
        if(! $lastRunOnly -and $runs.Count -eq $numRuns){
            $endUsecs = $runs[-1].backupRun.stats.endTimeUsecs - 1
        }else{
            break
        }
    }
}

if($missesRecorded -eq $false){
    "`nNo SLA misses recorded"
}

"`nOutput saved to $outFile`n"

