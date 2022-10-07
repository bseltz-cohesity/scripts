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
    [Parameter()][int]$daysBack = 7,
    [Parameter()][int]$maxLogBackupMinutes = 0,
    [Parameter()][string]$smtpServer,
    [Parameter()][string]$smtpPort = 25,
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -tenant $tenant

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

$nowUsecs = dateToUsecs (get-date)
$daysBackUsecs = timeAgo $daysBack days
$maxLogBackupUsecs = $maxLogBackupMinutes * 60000000
$cluster = api get cluster
$title = "Missed SLAs on $($cluster.name)"

$missesRecorded = $false
$message = ""

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning')

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $jobId = $job.id
    $jobName = $job.name
    $slaPass = "Pass"
    $sla = $job.sla[0].slaMinutes
    $slaUsecs = $sla * 60000000
    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=2&endTimeUsecs=$endUsecs&includeTenants=true"
    foreach($run in $runs.runs){
        if($run.PSObject.Properties['localBackupInfo']){
            $startTimeUsecs = $run.localBackupInfo.startTimeUsecs
            $status = $run.localBackupInfo.status
            if($run.localBackupInfo.PSObject.Properties['endTimeUsecs']){
                $endTimeUsecs = $run.localBackupInfo.endTimeUsecs
            }
        }else{
            $startTimeUsecs = $run.archivalInfo.archivalTargetResults[0].startTimeUsecs
            $status = $run.archivalInfo.archivalTargetResults[0].status
            if($run.archivalInfo.archivalTargetResults[0].PSObject.Properties['endTimeUsecs']){
                $endTimeUsecs = $run.archivalInfo.archivalTargetResults[0].endTimeUsecs
            }
        }
        
        if($status -in $finishedStates){
            $runTimeUsecs = $endTimeUsecs - $startTimeUsecs
        }else{
            $runTimeUsecs = $nowUsecs - $startTimeUsecs
        }
        if(!($startTimeUsecs -le $daysBackUsecs -and $status -in $finishedStates)){
            if($status -ne 'Canceled'){
                if($runTimeUsecs -gt $slaUsecs){
                    $slaPass = "Miss"
                    $reason = "SLA: $sla minutes"
                }
                if($maxLogBackupMinutes -gt 0 -and $run.localBackupInfo.runType -eq 'kLog' -and $runTimeUsecs -ge $maxLogBackupUsecs){
                    $slaPass = "Miss"
                    $reason = "Log SLA: $maxLogBackupMinutes minutes"
                }
            }
        }

        $runTimeMinutes = [math]::Round(($runTimeUsecs / 60000000),0)
        if($slaPass -eq "Miss"){
            $missesRecorded = $True
            if($status -in $finishedStates){
                $verb = "ran"
            }else{
                $verb = "has been running"
            }
            $startTime = usecsToDate $startTimeUsecs
            $messageLine = "- {0} ({1}) {2} for {3} minutes ({4})" -f $jobName, $startTime, $verb, $runTimeMinutes, $reason
            $messageLine
            $message += "$messageLine`n"
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
