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
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][int]$days = 7,
    [Parameter()][switch]$ignoreAdds,
    [Parameter()][switch]$ignoreRemoves,
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# output file
$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "jobObjectHistory-$($cluster.name)-$dateString.csv")
$startTimeUsecs = timeAgo $days days

"Job Name,Last Modified By,Last Modified Date,Action,Object,Object Modified Date" | Out-File -FilePath $outputfile
$jobs = api get protectionJobs | Where-Object {$_.isActive -ne $False -and $_.isDeleted -ne $True}

$eventCounter = 0
foreach($job in $jobs | Sort-Object -Property name){
    $jobNameReported = $False
    "`n$($job.name)`n"
    $previousSourceList = @()
    $runs = api get "protectionRuns?jobId=$($job.id)&runTypes=kRegular&runTypes=kFull&numRuns=9999&startTimeUsecs=$startTimeUsecs" | Where-Object {$_.backupRun.snapshotsDeleted -ne $true}
    foreach($run in $runs | Sort-Object -Property {$_.backupRun.stats.startTimeUsecs}){
        "    $(usecsToDate $run.backupRun.stats.startTimeUsecs)"
        $sourceList = $run.backupRun.sourceBackupStatus.source.name
        if($previousSourceList -ne @()){
            $added = $sourceList | Where-Object {$_ -notin $previousSourceList} | sort
            $removed = $previousSourceList | Where-Object {$_ -notin $sourceList} | sort
            if($added.Count -gt 0 -or $removed.Count -gt 0){
                if($jobNameReported -eq $False){
                    "`n$($job.name)  (Last Modified by $($job.modifiedByUser) at $(usecsToDate $job.modificationTimeUsecs))`n"
                    $jobNameReported = $True
                }
                "    $(usecsToDate $run.backupRun.stats.startTimeUsecs)"
                if(! $ignoreAdds){
                    foreach($add in $added){
                        $eventCounter += 1
                        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}""" -f $job.name, $job.modifiedByUser, (usecsToDate $job.modificationTimeUsecs), "Added", $add, (usecsToDate $run.backupRun.stats.startTimeUsecs) | Out-File -FilePath $outputfile -Append
                        "        ********     Added: $add"
                    }
                }
                if(! $ignoreRemoves){
                    foreach($remove in $removed){
                        $eventCounter += 1
                        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}""" -f $job.name, $job.modifiedByUser, (usecsToDate $job.modificationTimeUsecs), "Removed", $remove, (usecsToDate $run.backupRun.stats.startTimeUsecs) | Out-File -FilePath $outputfile -Append
                        "        ********   Removed: $remove"
                    }
                }
            }
        }
        $previousSourceList = $sourceList
    }
}
"`nOutput saved to $outputfile`n"

if($smtpServer -and $sendFrom -and $sendTo -and $eventCounter -gt 0){
    write-host "sending report to $([string]::Join(", ", $sendTo))"
    ### send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "Cohesity $($cluster.name) Job Object History Report" -Attachments $outputfile -WarningAction SilentlyContinue
    }
}
