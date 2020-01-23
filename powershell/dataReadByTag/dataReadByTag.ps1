# usage: ./dataReadByTag.ps1 -vip mycluster `
#                            -username myuser `
#                            -domain mydomain.net `
#                            -jobName 'My Job' `
#                            -tags mytag1, mytag2, mytag3 `
#                            -smtpServer 192.168.1.95 `
#                            -sendTo someuser@mydomain.net, anotheruser@mydomain.net `
#                            -sendFrom thisuser@mydomain.net

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # name of job to inspect
    [Parameter(Mandatory = $True)][array]$tags,  # list of tags to find
    [Parameter()][string]$smtpServer,  #outbound smtp server
    [Parameter()][string]$smtpPort = 25,  #outbound smtp port
    [Parameter()][array]$sendTo,  #send to address
    [Parameter()][string]$sendFrom  #send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get job info
$job = (api get protectionJobs | Where-Object name -ieq $jobName)
if($job){
    $jobId = $job.id
}else{
    Write-Warning "Job $jobName not found!"
    exit 1
}

$clusterName = (api get cluster).name
$nowDate = (get-date).ToString("yyyy-MM-dd hh:mm:ss")
$fileDate = $nowDate.Replace(' ', '_').Replace(':', '-')
$fileName = "dataByTag_$($clusterName)_$($jobId)_$($fileDate).csv"

# gather data read by tag
$readByTag = @{}

$runs = api get "protectionRuns?jobId=$jobId&excludeTasks=true&startTimeUsecs=$(timeAgo 31 days)" | Where-Object {$_.backupRun.snapshotsDeleted -ne $True}
$groupedByDay = $runs | Group-Object -Property {(usecsToDate $_.copyRun[0].runStartTimeUsecs).DayOfYear}, {(usecsToDate $_.copyRun[0].runStartTimeUsecs).Year}

foreach($run in $runs){
    $startTimeUsecs = $run.backupRun.stats.startTimeUsecs
    $thisrun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&id=$jobId&onlyReturnDataMigrationJobs=false"
    foreach($task in $thisrun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks){
        $dataRead = $task.base.totalBytesReadFromSource
        $vmTags = $task.base.sources[0].source.vmwareEntity.tagAttributesVec | Where-Object {$_.name -in $tags}
        if($vmTags){
            $tagName = $vmTags[0].name
        }else{
            $tagName = 'Unspecified'
        }
        if($tagName -in $readByTag.Keys){
            $readByTag[$tagName] += $dataRead
        }else{
            $readByTag[$tagName] = $dataRead
        }
    }
}

# output
$sinceDate = usecsToDate $startTimeUsecs
"Data Read since $($sinceDate) ($($groupedByDay.Count) days):"

"Cluster,{0}" -f $clusterName | Out-File -FilePath $fileName
"Job Name,{0}" -f $job.name | out-file -FilePath $fileName -Append
"Date,{0}" -f $nowDate | out-file -FilePath $fileName -Append
"Days Collected,{0}" -f $groupedByDay.Count | Out-File -FilePath $fileName -Append
"`nTag,MB Read" | Out-File -FilePath $fileName -Append

foreach($tagName in ($readByTag.Keys | sort)){
    $MBread = [math]::Round(($readByTag[$tagName]/(1024*1024)), 0)
    "  {0}:  {1} MB" -f $tagName, $MBread
    "{0},{1}" -f $tagName, $MBread | Out-File -FilePath $fileName -Append
}

# send email
if($smtpServer -and $sendTo -and $sendFrom){
    write-host "sending output to $([string]::Join(", ", $sendTo))"
    $subject = "Data Read by Tag: $clusterName - $jobName - $nowDate"
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $subject -Attachments $fileName -WarningAction SilentlyContinue
    }
}
