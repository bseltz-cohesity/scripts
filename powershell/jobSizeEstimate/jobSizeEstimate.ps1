# usage: ./backupNow.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -keepLocalFor 5 -archiveTo 'My Target' -keepArchiveFor 5 -replicateTo mycluster2 -keepReplicaFor 5 -enable

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][int]$fullFactor = 100,
    [Parameter()][switch]$recentFirstFull
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get job info
$job = (api get protectionJobs | Where-Object name -ieq $jobName)
if($job){
    $jobID = $job.id
}else{
    Write-Warning "Job $jobName not found!"
    exit 1
}

# get storage domain dedup ratio
$sd = api get viewBoxes?fetchStats=true | Where-Object id -eq $job.viewBoxId
$dedupRatio = [math]::Round(($sd.stats.usagePerfStats.dataInBytes/$sd.stats.usagePerfStats.dataInBytesAfterReduction),2)

# get run stats
$maxLogical = 0
$written = 0
$runs = api get "protectionRuns?jobId=$jobID&numRuns=99999" | Where-Object { $_.backupRun.snapshotsDeleted -eq $false }
foreach($run in $runs){
    $thisLogical = 0
    foreach($source in $run.backupRun.sourceBackupStatus){
        $thisLogical += $source.stats.totalLogicalBackupSizeBytes
        $written += $source.stats.totalPhysicalBackupSizeBytes
    }
    if($thisLogical -gt $maxLogical){
        $maxLogical = $thisLogical
    }
}

"`nJob Consumption for job: $($job.name)`n"
"   Logical Size MB: {0}" -f [math]::Round((($fullFactor/100)*$maxLogical/(1024*1024)),0)
"       Dedup Ratio: $dedupRatio"
$compressed = [math]::Round((($fullFactor/100)*$maxLogical/$dedupRatio),0)
"Compressed Size MB: {0}" -f [math]::Round(($compressed/(1024*1024)),0)
"    Incremental MB: {0}" -f [math]::Round(($written/(1024*1024)),0)
if($recentFirstFull){
    $total = $written
}else{
    $total = $compressed + $written
}
"          Total MB: {0}" -f [math]::Round(($total/(1024*1024)),0)
"          Total GB: {0}`n" -f [math]::Round(($total/(1024*1024*1024)),2)
