### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][array]$clusterName = $null,
    [Parameter()][int]$daysBack = 7,
    [Parameter()][int]$maxLogBackupMinutes = 0,
    [Parameter()][switch]$runningOnly,
    [Parameter()][switch]$logsOnly,
    [Parameter()][string]$environment,
    [Parameter()][string]$smtpServer,
    [Parameter()][string]$smtpPort = 25,
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

$nowUsecs = dateToUsecs (get-date)
$daysBackUsecs = timeAgo $daysBack days
$script:maxLogBackupUsecs = $maxLogBackupMinutes * 60000000
# $cluster = api get cluster
$title = "Missed SLAs"

$script:missesRecorded = $false
$script:message = ""

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning')
$tail = ''
if($logsOnly){
    $tail = '&runTypes=kLog'
}
$jobTail = ''
if($environment){
    $jobTail = "&environments=$environment"
}

function reportSlaViolations(){
    $cluster = api get cluster
    Write-Host $cluster.name
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true$jobTail"
    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $jobId = $job.id
        $jobName = $job.name
        $slaPass = "Pass"
        $sla = $job.sla[0].slaMinutes
        $slaUsecs = $sla * 60000000
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=10&includeTenants=true&startTimeUsecs=$daysBackUsecs$tail"
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
            # if(!($startTimeUsecs -le $daysBackUsecs -and $status -in $finishedStates)){
            if($status -notin $finishedStates -or ! $runningOnly){
                if($status -ne 'Canceled'){
                    if($runTimeUsecs -gt $slaUsecs){
                        $slaPass = "Miss"
                        $reason = "SLA: $sla minutes"
                    }
                    if($maxLogBackupMinutes -gt 0 -and $run.localBackupInfo.runType -eq 'kLog' -and $runTimeUsecs -ge $script:maxLogBackupUsecs){
                        $slaPass = "Miss"
                        $reason = "Log SLA: $maxLogBackupMinutes minutes"
                    }
                }
            }
    
            $runTimeMinutes = [math]::Round(($runTimeUsecs / 60000000),0)
            if($slaPass -eq "Miss"){
                $script:missesRecorded = $True
                if($status -in $finishedStates){
                    $verb = "ran"
                }else{
                    $verb = "has been running"
                }
                $startTime = usecsToDate $startTimeUsecs
                $messageLine = "- [{0}] {1} ({2}) {3} for {4} minutes ({5})" -f $cluster.name, $jobName, $startTime, $verb, $runTimeMinutes, $reason
                Write-Host $messageLine
                $script:message += "$messageLine`n"
                break
            }
        }
    }
}

# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        output "`n$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            reportSlaViolations
        }
    }else{
        reportSlaViolations
    }
}

if($script:missesRecorded -eq $false){
    "No SLA misses recorded"
}else{
    if($smtpServer -and $sendTo -and $sendFrom){
        foreach($toaddr in $sendTo){
            "Sending report to $toaddr"
            Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title  -Body $script:message -WarningAction SilentlyContinue
        }
    }
}
