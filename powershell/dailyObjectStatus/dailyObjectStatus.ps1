# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$numRuns = 2,
    [Parameter()][switch]$yesterdayOnly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# date range
$now = Get-Date
$midnight = Get-Date -Hour 0 -Minute 0 -Second 0
$yesterday = $midnight.AddDays(-1)
$nowUsecs = dateToUsecs $now
$midnightUsecs = dateToUsecs $midnight
$yesterdayUsecs = dateToUsecs $yesterday
if($yesterdayOnly){
    $endTimeUsecs = $midnightUsecs
}else{
    $endTimeUsecs = $nowUsecs
}

# output file
$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "dailyObjectStatus-$($cluster.name)-$dateString.csv")
"Job Name,Job Type,Object Name,Status,Last Run,Message" | Out-File -FilePath $outputfile

$jobs = api get protectionJobs | Where-Object {$_.isActive -ne $False -and $_.isDeleted -ne $True}

foreach($job in $jobs | Sort-Object -Property name){
    "`n{0} ({1})`n" -f $job.name, $job.environment.subString(1)
    $runs = api get "protectionRuns?jobId=$($job.id)&startTimeUsecs=$yesterdayUsecs&endTimeUsecs=$endTimeUsecs&numRuns=$numRuns"
    $finishedRuns = $runs | Where-Object {$_.backupRun.status -in @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')}
    $myRun = $null
    if($finishedRuns.Count -eq 0){
        # still running
        if($runs.Count -gt 0){
            $myRun = $runs[0]
        }
    }else{
        # finished
        $myRun = $finishedRuns[0]
    }
    if($myRun){
        $runStartTimeUsecs = $myRun.backupRun.stats.startTimeUsecs 
        foreach($source in $myRun.backupRun.sourceBackupStatus | Sort-Object -Property {$_.source.name}){
            $sourceName = $source.source.name
            if($source.source.environment -eq 'kO365' -and $source.source.office365ProtectionSource.PSObject.Properties['primarySMTPAddress']){
                $sourceName = $source.source.office365ProtectionSource.primarySMTPAddress
            }
            $status = $source.status.subString(1)
            $message = $source.error
            "  {0} ({1})" -f $sourceName, $status
            "{0},{1},{2},{3},{4},""{5}""" -f $job.name, $job.environment.subString(1), $sourceName, $status, (usecsToDate $runStartTimeUsecs), $message | Out-File -FilePath $outputfile -Append
        }
    }
}
"`nOutput saved to $outputfile`n"
