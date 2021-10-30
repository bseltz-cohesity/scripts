### report job run statistics

### usage: ./logicalSizeReport.ps1 -vip mycluster -username admin [ -domain local ] -jobName 'RMAN Dump' [ -numRuns 7 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][int]$numRuns = 31
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$GB = 1024*1024*1024

$job = api get protectionJobs | Where-Object { $_.name -eq $jobName }
if(! $job){
    write-host "Job $jobName not found" -ForegroundColor Yellow
    exit
}

$runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns"

"`nLogical Size History for $jobName`n"
"          Date/Time`tSize (GB)"
"          =========`t=========`n"

foreach($run in $runs){
    $size = [math]::Round((($run.backupRun.stats.totalSourceSizeBytes)/$GB),2)
    $startTime = usecsToDate $run.backupRun.stats.startTimeUsecs
    "{0}`t{1}" -f $startTime, $size
}