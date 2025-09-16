### process commandline arguments
[CmdletBinding()]
param (
   [Parameter()][string]$vip='helios.cohesity.com', #the cluster to connect to (DNS name or IP)
   [Parameter()][string]$username='helios', #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][array]$include, # cluster names to include
   [Parameter()][array]$exclude, # cluster names to exclude
   [Parameter()][int]$maxMinutes,
   [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
   [Parameter()][string]$smtpPort = 25, #outbound smtp port
   [Parameter()][array]$sendTo, #send to address
   [Parameter()][string]$sendFrom #send from address
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -helios

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')

$nowUsecs = dateToUsecs (get-date)
$missesRecorded = $false

$message = '<html><body style="font-family: Helvetica, Arial, sans-serif; font-size: 12px; background-color: #f1f3f6; color: #444444;">'
$message += '<div style="background-color: #fff; width:fit-content; padding: 2px 6px 8px 6px; font-weight: 300; box-shadow: 1px 2px 4px #cccccc; border-radius: 4px;">'
$message += '<p style="font-weight: bold;">Helios SLA Miss Report ({0})</p>' -f (Get-Date)

$title = "Missed SLAs"

foreach($cluster in heliosClusters){
    if(($include.Count -eq 0 -or $cluster.name -in $include) -and $cluster.name -notin $exclude){
        $thisCluster = heliosCluster $cluster
        "`n$($cluster.name.ToUpper())`n"
        $clusterReported = $false

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
                if($maxMinutes -and $runTimeMinutes -gt $maxMinutes){
                    $slaPass = "Miss"
                }
                if($slaPass -eq "Miss"){
                    $missesRecorded = $True
                    if($run.backupRun.status -in $finishedStates){
                        $verb = "ran"
                    }else{
                        $verb = "has been running"
                    }
                    if($false -eq $clusterReported){
                        $message += '<hr style="border: 1px solid #eee;"/><span style="font-weight: bold;">{0}</span><br/>' -f $cluster.name.ToUpper()
                        $clusterReported = $True
                    }
                    $messageline = '<span style="margin-left: 20px; font-weight: normal; color: #000;">{0}:</span> <span style="font-weight: 300;">Backup {1} for {2} minutes (SLA: {3} minutes)</span><br/>' -f $jobName.ToUpper(), $verb, $runTimeMinutes, $sla
                                    
                    "- {0} (Missed SLA) {1} for {2} minutes (SLA: {3} minutes)" -f $jobName, $verb, $runTimeMinutes, $sla
                    $message += "$messageLine`n"
                }
                if($run.backupRun.status -in $finishedStates){
                    break
                }
            }
        }
    }
}

if($missesRecorded -eq $false){
    "No SLA misses recorded"
}else{
    $message += '</body></html>'
    $outFile = $(Join-Path -Path $PSScriptRoot -ChildPath "heliosSlaMonitor-$((get-date).tostring('yyyy-MM-dd_hh-mm')).html")
    $message | Out-File -FilePath $outFile
    if($smtpServer -and $sendTo -and $sendFrom){
        foreach($toaddr in $sendTo){
            "Sending report to $toaddr"
            Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $message -WarningAction SilentlyContinue
        }
    }
}

Write-Host "`nOutput saved to $outFile`n"