# usage:
# ./protectionReport.ps1 -vip mycluster `
#                        -username myusername `
#                        -showApps `
#                        -smtpServer 192.168.1.95 `
#                        -sendTo me@mydomain.net `
#                        -sendFrom them@mydomain.net

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][int]$daysBack = 7,  # number of days to include in report
    [Parameter()][string]$smtpServer,  # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25,  # outbound smtp port
    [Parameter()][array]$sendTo,  # send to address
    [Parameter()][string]$sendFrom,  # send from address
    [Parameter()][string]$outPath = '.'  # folder to write output file
)

if($outPath -ne '.'){
    if(! (Test-Path -PathType Container -Path $outPath)){
        $null = New-Item -ItemType Directory -Path $outPath -Force
    }
    if(! (Test-Path -PathType Container -Path $outPath)){
        Write-Host "OutPath $outPath not found!" -ForegroundColor Yellow
        exit
    }
}

$dateString = (get-date).ToString('yyyy-MM-dd')
$outFile = Join-Path -Path $outPath -ChildPath "ProtectionSummaryByCluster-$dateString.csv"

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -helios

"`nGathering report data...`n"

$startDate = usecsToDate (timeAgo $daysBack days)
$endDate = usecsToDate (timeAgo 1 second)

"Protection Summary By Cluster`nThis report provides summary of the total protection runs and the status on a per cluster basis." | Out-File -FilePath $outFile
"Report Duration: {0} - {1}" -f $startDate, $endDate | Out-File -FilePath $outFile -Append
"`nCluster Name,Task Type,Total Runs,Success,Errors,Warnings,Running,Success %,GiB Transferred" | Out-File -FilePath $outFile -Append

$totalArchival = @{
    'Cluster Count' = 0;
    'Total Runs' = 0;
    'Success' = 0;
    'Errors' = 0;
    'Warnings' = 0;
    'Running' = 0;
    'Success %' = 0;
    'Data Transferred' = 0
}

$totalBackup = @{
    'Cluster Count' = 0;
    'Total Runs' = 0;
    'Success' = 0;
    'Errors' = 0;
    'Warnings' = 0;
    'Running' = 0;
    'Data Transferred' = 0
}

foreach($cluster in heliosClusters){

    heliosCluster $cluster
    $report = (api get "/backupjobruns?_includeTenantInfo=true&allUnderHierarchy=false&endTimeUsecs=$(timeAgo 1 second)&excludeTasks=true&numRuns=-1&startTimeUsecs=$(timeAgo $daysBack days)").backupJobRuns.protectionRuns
    $totalBackupCount = $report.Count
    $successfulBackupCount = ($report.backupRun.base.publicStatus | Where-Object {$_ -eq 'kSuccess'}).Count
    $warningBackupCount = ($report.backupRun.base.publicStatus | Where-Object {$_ -eq 'kWarning'}).Count
    $failedBackupCount = ($report.backupRun.base.publicStatus | Where-Object {$_ -eq 'kFailure'}).Count
    $runningBackupCount = ($report.backupRun.base.publicStatus | Where-Object {$_ -eq 'kRunning'}).Count
    $bytesRead = 0
    $report.backupRun.base.totalBytesReadFromSource | ForEach-Object {$bytesRead += $_}
    $GiBRead = [math]::Round($bytesRead / (1024 * 1024 * 1024), 2)
    if($totalBackupCount -gt 0){
        $backupSuccessPercent = [math]::Round(100 - (100 * $failedBackupCount / $totalBackupCount), 0)
        "{0} (Backup) {1}/{2}/{3}/{4}/{5} ({6}) {7}" -f $cluster.name, $totalBackupCount, $successfulBackupCount, $warningBackupCount, $failedBackupCount, $runningBackupCount, $backupSuccessPercent, $GiBRead
        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""" -f $cluster.name, 'Backup', $totalBackupCount, $successfulBackupCount, $failedBackupCount, $warningBackupCount, $runningBackupCount, $backupSuccessPercent, $GiBRead | Out-File -FilePath $outFile -Append
        $totalBackup['Cluster Count'] += 1
        $totalBackup['Total Runs'] += $totalBackupCount
        $totalBackup['Success'] += $successfulBackupCount
        $totalBackup['Warnings'] += $warningBackupCount
        $totalBackup['Errors'] += $failedBackupCount
        $totalBackup['Running'] += $runningBackupCount
        $totalBackup['Data Transferred'] += $GiBRead
    }else{
        "{0} (Backup) No Data" -f $cluster.name
        """{0}"",""Backup"", No Data" -f $cluster.name | Out-File -FilePath $outFile -Append
    }
    $totalArchiveBytes = 0
    $runningArchive = ($report.copyRun.activeTasks | Where-Object {$_.snapshotTarget.type -eq 3})
    $finishedArchive = ($report.copyRun.finishedTasks | Where-Object {$_.snapshotTarget.type -eq 3})
    $runningArchive.archivalInfo.bytesTransferred | ForEach-Object{ $totalArchiveBytes += $_ }
    $finishedArchive.archivalInfo.bytesTransferred | ForEach-Object{ $totalArchiveBytes += $_ }
    $runningArchiveCount = $runningArchive.Count
    $totalArchiveCount = $finishedArchive.Count + $runningArchiveCount
    $successfulArchiveCount = ($finishedArchive.publicStatus | Where-Object {$_ -eq 'kSuccess'}).Count
    $warningArchiveCount = ($finishedArchive.publicStatus | Where-Object {$_ -eq 'kWarning'}).Count
    $failedArchiveCount = ($finishedArchive.publicStatus | Where-Object {$_ -eq 'kFailure'}).Count
    $GiBTransferred = [math]::Round($totalArchiveBytes/ (1024 * 1024 * 1024), 2)
    if($totalArchiveCount -gt 0){
        $archiveSuccessPercent = [math]::Round(100 - (100 * $failedArchiveCount / $totalArchiveCount), 0)
        "{0} (Archival) {1}/{2}/{3}/{4}/{5} ({6}) {7}" -f $cluster.name, $totalArchiveCount, $successfulArchiveCount, $warningArchiveCount, $failedArchiveCount, $runningArchiveCount, $archiveSuccessPercent, $GiBTransferred
        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""" -f $cluster.name, 'Archival', $totalArchiveCount, $successfulArchiveCount, $failedArchiveCount, $warningArchiveCount, $runningArchiveCount, $archiveSuccessPercent, $GiBTransferred | Out-File -FilePath $outFile -Append
        $totalArchival['Cluster Count'] += 1
        $totalArchival['Total Runs'] += $totalArchiveCount
        $totalArchival['Success'] += $successfulArchiveCount
        $totalArchival['Warnings'] += $warningArchiveCount
        $totalArchival['Errors'] += $failedArchiveCount
        $totalArchival['Running'] += $runningArchiveCount
        $totalArchival['Data Transferred'] += $GiBTransferred
    }
}

"`nTask Type,Cluster Count,Total Runs,Success,Errors,Warnings,Running,Success %,GiB Transferred" | Out-File -FilePath $outFile -Append
$successBackupPercent = 0
if($totalBackup['Total Runs'] -gt 0){
    $successBackupPercent = [math]::Round(100 - (100 * $totalBackup['Errors'] / $totalBackup['Total Runs']), 0)
    "Backup,""{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}""" -f $totalBackup['Cluster Count'], $totalBackup['Total Runs'], $totalBackup['Success'], $totalBackup['Errors'], $totalBackup['Warnings'], $totalBackup['Running'], $successBackupPercent, $totalBackup['Data Transferred'] | Out-File -FilePath $outFile -Append
}
$successArchivePercent = 0
if($totalArchival['Total Runs'] -gt 0){
    $successArchivePercent = [math]::Round(100 - (100 * $totalArchival['Errors'] / $totalArchival['Total Runs']), 0)
    "Archival,""{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}""" -f $totalArchival['Cluster Count'], $totalArchival['Total Runs'], $totalArchival['Success'], $totalArchival['Errors'], $totalArchival['Warnings'], $totalArchival['Running'], $successArchivePercent, $totalArchival['Data Transferred'] | Out-File -FilePath $outFile -Append
}

"`nOutput Saved to $outFile`n"

# send email
if($smtpServer -and $sendTo -and $sendFrom){
    write-host "sending output to $([string]::Join(", ", $sendTo))"
    $subject = "Helios Protection Summary Report $startDate - $endDate"
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $subject -Attachments $outFile -WarningAction SilentlyContinue
    }
}
