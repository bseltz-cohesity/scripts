### usage: ./createShares.ps1 -vip mycluster -username myusername -domain mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$consoleWidth = $Host.UI.RawUI.WindowSize.Width

$title = 'Helios Job Failure Report'
$message = '<html><body style="font-family: Helvetica, Arial, sans-serif; font-size: 12px; background-color: #f1f3f6; color: #444444;">'
$message += '<div style="background-color: #fff; width:fit-content; padding: 2px 6px 8px 6px; font-weight: 300; box-shadow: 1px 2px 4px #cccccc; border-radius: 4px;">'
$message += '<p style="font-weight: bold;">Helios Job Failure Report ({0})</p>' -f (Get-Date)
$failureCount = 0

foreach($cluster in heliosClusters){
    $failureDetected = $false
    heliosCluster $cluster
    $jobs = api get protectionJobs | Sort-Object -Property name
    foreach($job in $jobs){
        if($job.isDeleted -ne $true -and $job.isPaused -ne $true -and $job.isActive -ne $false){
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=2" | where-object {$_.backupRun.status -eq 'kFailure'}
            if($runs.count -gt 0){
                $failureCount += 1
                if($failureDetected -eq $false){
                    "`n{0}" -f $cluster.name.ToUpper()
                    $message += '<hr style="border: 1px solid #eee;"/><span style="font-weight: bold;">{0}</span><br/>' -f $cluster.name.ToUpper()
                    $failureDetected = $true
                }
                "  {0} ({1}) {2}" -f $job.name.ToUpper(), $job.environment.substring(1), (usecsToDate $runs[0].backupRun.stats.startTimeUsecs)
                $message += '<span style="margin-left: 20px; font-weight: normal; color: #000;">{0}:</span> <span style="font-weight: 300;">({1}) {2}</span><br/>' -f $job.name.ToUpper(), $job.environment.substring(1), (usecsToDate $runs[0].backupRun.stats.startTimeUsecs)
                        
                foreach($source in $runs[0].backupRun.sourceBackupStatus){
                    if($source.status -eq 'kFailure'){
                        $objectReport = "      {0} ({1})" -f $source.source.name.ToUpper(), $source.error                   
                        if($objectReport.length -gt $consoleWidth){
                            $objectReport = "$($objectReport.substring(0,($consoleWidth-5)))...)"
                        }
                        $objectReport
                        $objectError = $source.error
                        if(($objectError.length + $source.source.name.length) -gt 80){
                            $objectError = "$($objectError.substring(0,(80 - 3 - $source.source.name.length)))..."
                        }
                        $message += '<span style="margin-left: 60px; font-weight: normal; color: #000;">{0}:</span> <span style="font-weight: 300;">{1}</span><br/>' -f $source.source.name.ToUpper(), $objectError
                    }
                }
            }  
        }
    }   
}

$message += '</body></html>'
$message | out-file -FilePath 'heliosJobFailures.html'

if($failureCount -and $smtpServer -and $sendTo -and $sendFrom){
    write-host "`nsending report to $([string]::Join(", ", $sendTo))"
    ### send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $message -WarningAction SilentlyContinue
    }
}