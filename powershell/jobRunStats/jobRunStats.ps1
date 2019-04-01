### report job run statistics

### usage: ./jobRunStats.ps1 -vip mycluster -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$failedOnly,
    [Parameter()][switch]$lastDay
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$MB = 1024*1024

$dateString = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$outfileName = "RunStats-$dateString.csv"
"JobName,JobType,Status,RunDate,RunType,DurationSec,LogicalMB,DataReadMB,DataWrittenMB,RunURL" | Out-File -FilePath $outfileName

$jobs = api get protectionJobs?isDeleted=false

foreach ($job in $jobs){
    $jobName = $job.name
    $jobId = $job.id
    $jobType = $job.environment.substring(1)
    "$($job.name) ($($jobType))"
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=999999"

    foreach ($run in $runs){
        $nowTime = dateToUsecs (get-date)
        $startTime = $run.copyRun[0].runStartTimeUsecs
        if(! $lastDay -or ($lastDay -and ($nowTime - $startTime -le 86400000000))){
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
}