### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][string]$outPath = '.'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')

$now = Get-Date
$nowUsecs = dateToUsecs $now
$dateString = $now.ToString('yyyy-MM-dd')


$cluster = api get cluster
$title = "Missed SLAs on $($cluster.name)"
$outFile = $(Join-Path -Path $outPath -ChildPath "slaStatus-$($cluster.name)-$dateString.csv")

$missesRecorded = $false
$message = ""

"jobName,Last Run,Status,Duration,SLA Setting,SLA Status" | Out-File -FilePath $outFile

"`nCollecting Job Stats...`n"
foreach($job in (api get protectionJobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false} | Sort-Object -Property name)){
    $jobId = $job.id
    $jobName = $job.name
    $jobName
    $slaPass = "Pass"
    $sla = $job.incrementalProtectionSlaTimeMins
    $slaUsecs = $sla * 60000000
    $runs = api get "protectionRuns?jobId=$jobId&excludeTasks=true&numRuns=2"
    foreach($run in $runs){
        $startTimeUsecs = $run.backupRun.stats.startTimeUsecs
        $status = $run.backupRun.status
        if($status -in $finishedStates){
            $endTimeUsecs = $run.backupRun.stats.endTimeUsecs
            $runTimeUsecs = $endTimeUsecs - $startTimeUsecs
        }else{
            $runTimeUsecs = $nowUsecs - $startTimeUsecs
        }
        if($runTimeUsecs -gt $slaUsecs){
            $slaPass = "Miss"
        }
        $runTimeMinutes = [math]::Round(($runTimeUsecs / 60000000),0)
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
        "{0},{1},{2},{3},{4},{5}" -f $jobName, (usecsToDate $startTimeUsecs), $status.subString(1), $runTimeMinutes, $sla, $slaPass  | Out-File -FilePath $outFile -Append
        if($run.backupRun.status -in $finishedStates){
            break
        }
    }
}

if($missesRecorded -eq $false){
    "`nNo SLA misses recorded"
}

"`nOutput saved to $outFile`n"

