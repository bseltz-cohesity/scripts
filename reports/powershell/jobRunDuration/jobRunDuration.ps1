# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][array]$jobNames  # job to run
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$dateString = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$outfileName = "jobRunDuration-$dateString.csv"
"JobName,StartTime,Duration (Seconds), MB Read" | Out-File -FilePath $outfileName

$jobs = api get protectionJobs
if(! $jobNames){
    $jobNames = $jobs.name
}
foreach($jobName in ($jobNames | Sort-Object -Property name)){
    $job = $jobs | Where-Object name -eq $jobName
    if(! $job){
        write-host "$jobName not found" -ForegroundColor Yellow
    }else{
        foreach($j in $job){
            $runs = api get "protectionRuns?jobId=$($j.id)&startTimeUsecs=$(timeAgo 24 hours)&runTypes=kRegular"
            if(! $runs -or $runs.Count -eq 0){
                $runs = api get "protectionRuns?jobId=$($j.id)&numRuns=1&runTypes=kRegular"
            }
            foreach($run in $runs | Where-Object {$_.backupRun.status -eq 'kSuccess'}){
                $startTimeUsecs = $run.backupRun.stats.startTimeUsecs
                $startTime = usecsToDate $startTimeUsecs
                $endTimeUsecs = $run.backupRun.stats.endTimeUsecs
                $durationUsecs = $endTimeUsecs - $startTimeUsecs
                $durationSeconds = [math]::Round(($durationUsecs / 1000000),0) 
                $dataReadMBytes = [math]::Round(($run.backupRun.stats.totalBytesReadFromSource / (1024 * 1024)), 2)
                "{0}`t{1}`t{2} seconds`t{3} MB read" -f $jobName, $startTime, $durationSeconds, $dataReadMBytes
                "{0},{1},{2},{3}" -f $jobName, $startTime, $durationSeconds, $dataReadMBytes | out-file -FilePath $outfileName -Append
            }
        }
    }
}
"Output written to $outfileName"

