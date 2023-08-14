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
    [Parameter()][string]$clusterName = $null,
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][int]$days = 7,
    [Parameter()][int]$failureCount = 1,
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "strikeReport-$($cluster.name)-$dateString.csv"

# headings
"Job Name,Latest Backup,Backup Type,Object Name,Message" | Out-File -FilePath $outfileName

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

$startUsecs = timeAgo $days 'days'
$totalStrikeouts = 0

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $failures = @{}
    $reportFailures = @{}
    $failureTime = @{}
    $messages = @{}
    $job.name
    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$failureCount&startTimeUsecs=$startUsecs&includeTenants=true&includeObjectDetails=true&runTypes=kSystem,kFull,kIncremental"
    if($runs.runs.Count -gt 0){
        $status = $runs.runs.localBackupInfo.status
        if('Succeeded' -notin $status -and 'SucceededWithWarning' -notin $status){
            $runStartTime = usecsToDate $runs.runs[0].localBackupInfo.startTimeUsecs
            foreach($run in $runs.runs){
                foreach($object in $run.objects){
                    $objectName = $object.object.name
                    if($object.localSnapshotInfo.snapshotInfo.status -eq 'kFailed'){
                        $message = $object.localSnapshotInfo.failedAttempts[0].message
                        if("$($job.name);;$($objectName);;Backup" -notin $failures.Keys){
                            $failures["$($job.name);;$($objectName);;Backup"] = 1
                            $messages["$($job.name);;$($objectName);;Backup"] = $message
                        }else{
                            $failures["$($job.name);;$($objectName);;Backup"] += 1
                        }
                        if($failures["$($job.name);;$($objectName);;Backup"] -ge $failureCount){
                            $reportFailures["$($job.name);;$($objectName);;Backup"] = $messages["$($job.name);;$($objectName);;Backup"]
                            $failureTime["$($job.name);;$($objectName);;Backup"] = $runStartTime
                        }
                    }
                }
            }
        }
    }
    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=1000&startTimeUsecs=$startUsecs&includeTenants=true&includeObjectDetails=true&runTypes=kLog"
    if($runs.runs.Count -gt 0){
        $status = $runs.runs.localBackupInfo.status
        if('Succeeded' -notin $status -and 'SucceededWithWarning' -notin $status){
            $runStartTime = usecsToDate $runs.runs[0].localBackupInfo.startTimeUsecs
            foreach($run in $runs.runs){
                foreach($object in $run.objects){
                    $objectName = $object.object.name
                    if($object.localSnapshotInfo.snapshotInfo.status -eq 'kFailed'){
                        $message = $object.localSnapshotInfo.failedAttempts[0].message
                        if("$($job.name);;$($objectName);;Log Backup" -notin $failures.Keys){
                            $failures["$($job.name);;$($objectName);;Log Backup"] = 1
                            $messages["$($job.name);;$($objectName);;Log Backup"] = $message
                        }else{
                            $failures["$($job.name);;$($objectName);;Log Backup"] += 1
                        }
                        if($failures["$($job.name);;$($objectName);;Log Backup"] -ge $failureCount){
                            $reportFailures["$($job.name);;$($objectName);;Log Backup"] = $messages["$($job.name);;$($objectName);;Log Backup"]
                            $failureTime["$($job.name);;$($objectName);;Log Backup"] = $runStartTime
                        }
                    }
                }
            }
        }
    }
    foreach($failureKey in $reportFailures.Keys | Sort-Object){
        $totalStrikeouts += 1
        $jobName, $objectName, $runType = $failureKey -split ';;'
        $message = [string]$reportFailures[$failureKey].replace("`n", "").replace(",",";")
        if($message.length -gt 150){
            $message = $message.subString(0,150)
        }
        $runStartTime = $failureTime[$failureKey]
        "    {0} ({1}) [{2}] {3}" -f $jobName, $runStartTime, $runType, $objectName
        "{0},{1},{2},{3},{4}" -f $jobName, $runStartTime, $runType, $objectName, $message | Out-File -FilePath $outfileName -Append
    }
}

"`nTotal Strikeouts: $totalStrikeouts `nOutput saved to $outfilename`n"

if($smtpServer -and $sendFrom -and $sendTo){
    write-host "sending report to $([string]::Join(", ", $sendTo))"
    ### send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "$clusterName Strike Report ($totalStrikeouts)" -Body "`nTotal Strikeouts: $totalStrikeouts`n`n" -Attachments $outfileName -WarningAction SilentlyContinue
    }
}
