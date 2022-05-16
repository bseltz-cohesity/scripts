### report job run statistics

### usage: ./jobRunStats.ps1 -vip mycluster -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][switch]$failedOnly,
    [Parameter()][switch]$lastDay,
    [Parameter()][int]$numDays = 0
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    if($emailMfaCode){
        apiauth -vip $vip -username $username -domain $domain -password $password -emailMfaCode
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password -mfaCode $mfaCode
    }
}

$cluster = api get cluster

$MB = 1024*1024

$dateString = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "RunStats-$($cluster.name)-$dateString.csv"
"JobName,JobType,Status,RunDate,RunType,DurationSec,LogicalMB,DataReadMB,DataWrittenMB,RunURL" | Out-File -FilePath $outfileName

$jobs = api get protectionJobs?isDeleted=false

if($lastDay){
    $numDays = 1
}

foreach ($job in $jobs){
    $jobName = $job.name
    $jobId = $job.id
    $jobType = $job.environment.substring(1)
    "$($job.name) ($($jobType))"
    if($numDays -gt 0){
        $runs = api get "protectionRuns?jobId=$($job.id)&excludeTasks=true&numRuns=9999&startTimeUsecs=$(timeAgo $numDays days)"
    }else{
        $runs = api get "protectionRuns?jobId=$($job.id)&excludeTasks=true&numRuns=9999"
    }
    
    foreach ($run in $runs){
        $nowTime = dateToUsecs (get-date)
        $startTime = $run.copyRun[0].runStartTimeUsecs
        $runId = $run.backupRun.jobRunId
        $endTime = $run.backupRun.stats.endTimeUsecs
        $duration = [math]::Round(($endTime - $startTime)/1000000,0)
        $runType = $run.backupRun.runType.substring(1)
        $readMBytes = [math]::Round($run.backupRun.stats.totalBytesReadFromSource / $MB, 2)
        $writeMBytes = [math]::Round($run.backupRun.stats.totalPhysicalBackupSizeBytes / $MB, 2)
        $logicalMBytes = [math]::Round($run.backupRun.stats.totalLogicalBackupSizeBytes / $MB, 2)
        $status = $run.backupRun.status.substring(1)
        $runURL = "https://$vip/protection/job/$jobId/run/$runId/$startTime/protection"
        if(! $failedOnly -or ($failedOnly -and $status -ne "Success")){
            "`t{0}`t{1}`t{2}`t{3}`t{4}`t{5}" -f (usecsToDate $startTime), $status, $runType, $duration, $readMBytes, $writeMBytes
            "$jobName,$jobType,$status,$(usecsToDate $startTime),$runType,$duration,$logicalMBytes,$readMBytes,$writeMBytes,$runURL" | Out-File -FilePath $outfileName -Append
        }
    }
}