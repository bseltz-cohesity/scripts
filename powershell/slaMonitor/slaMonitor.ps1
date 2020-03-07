### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
   [Parameter()][string]$smtpPort = 25, #outbound smtp port
   [Parameter()][array]$sendTo, #send to address
   [Parameter()][string]$sendFrom #send from address
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')

$nowUsecs = dateToUsecs (get-date)

$cluster = api get cluster
$title = "Missed SLAs on $($cluster.name)"

$missesRecorded = $false
$message = ""

foreach($job in (api get protectionJobs | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $false} | Sort-Object -Property name)){
    $jobId = $job.id
    $jobName = $job.name
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
        if($run.backupRun.status -in $finishedStates){
            break
        }
    }
}

if($missesRecorded -eq $false){
    "No SLA misses recorded"
}else{
    if($smtpServer -and $sendTo -and $sendFrom){
        foreach($toaddr in $sendTo){
            "Sending report to $toaddr"
            Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title  -Body $message -WarningAction SilentlyContinue
        }
    }
}
