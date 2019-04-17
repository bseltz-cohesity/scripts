# usage: ./backupNow.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -keepLocalFor 5 -archiveTo 'My Target' -keepArchiveFor 5 -replicateTo mycluster2 -keepReplicaFor 5 -enable

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # job to run
    [Parameter()][int]$keepLocalFor = 5,  # keep local snapshot for x days
    [Parameter()][string]$replicateTo = $null,  # optional - remote cluster to replicate to
    [Parameter()][int]$keepReplicaFor = 5,  # keep replica for x days
    [Parameter()][string]$archiveTo = $null,  # optional - target to archive to
    [Parameter()][int]$keepArchiveFor = 5,  # keep archive for x days
    [Parameter()][switch]$enable,  # enable a disabled job, run it, then disable when done
    [Parameter()][ValidateSet(“kRegular”,”kFull”,”kLog”)][string]$backupType = 'kRegular'
)

# source the cohesity-api helper code
. ./cohesity-api

# authenticate
apiauth -vip $vip -username $username -domain $domain

# find the jobID
$job = (api get protectionJobs | Where-Object name -ieq $jobName)
if($job){
    $jobID = $job.id
    $environment = $job.environment
    if($environment -notin ('kOracle', 'kSQL') -and $backupType -eq 'kLog'){
        Write-Warning "BackupType kLog not applicable to $environment jobs"
        exit 1
    }
}else{
    Write-Warning "Job $jobName not found!"
    exit 1
}

# get last run id
$runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
$newRunId = $lastRunId = $runs[0].backupRun.jobRunId

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure')

# wait for existing job run to finish
"waiting for existing job run to finish..."
while ($runs[0].backupRun.status -notin $finishedStates){
    sleep 5
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
}

# set local retention
$copyRunTargets = @(
    @{
        "type" = "kLocal";
        "daysToKeep" = $keepLocalFor
    }
)

# add replication target and retention
if ($replicateTo) {
    $remote = api get remoteClusters | Where-Object {$_.name -eq $replicateTo}
    if ($remote) {
        $copyRunTargets = $copyRunTargets + @{
            "daysToKeep" = $keepReplicaFor;
            "replicationTarget" = @{
              "clusterId" = $remote.clusterId;
              "clusterName" = $remote.name
            };
            "type" = "kRemote"
          }
    }
    else {
        Write-Warning "Remote Cluster $replicateTo not found!"
        exit 1
    }
}

# add archival target and retention
if($archiveTo){
    $vault = api get vaults | Where-Object {$_.name -eq $archiveTo}
    if($vault){
        $copyRunTargets = $copyRunTargets + @{
            "archivalTarget" = @{
              "vaultId" = $vault.id;
              "vaultName" = $vault.name;
              "vaultType" = "kCloud"
            };
            "daysToKeep" = $keepArchiveFor;
            "type" = "kArchival"
          }
    }else{
        Write-Warning "Archive target $archiveTo not found!"
        exit 1
    }
}

# Finalize RunProtectionJobParam object
$jobdata = @{
   "runType" = $backupType
   "copyRunTargets" = $copyRunTargets
}

# enable job
if($enable){
    $lastRunTime = (api get "protectionRuns?jobId=$jobId&numRuns=1").backupRun.stats.startTimeUsecs
    while($True -eq (api get protectionJobs/$jobID).isPaused){
        $null = api post protectionJobState/$jobID @{ 'pause'= $false }
        sleep 2
    }
}

# run job
"Running $jobName..."
$null = api post ('protectionJobs/run/' + $jobID) $jobdata

# wait for new job run to appear
while($newRunId -eq $lastRunId){
    sleep 2
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
    $newRunId = $runs[0].backupRun.jobRunId
}

# wait for job run to finish
while ($runs[0].backupRun.status -notin $finishedStates){
    sleep 5
    $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=10"
}

# disable job
if($enable){
    while($True -ne (api get protectionJobs/$jobID).isPaused){
        if($lastRunTime -lt (api get "protectionRuns?jobId=$jobId&numRuns=1").backupRun.stats.startTimeUsecs){
            $null = api post protectionJobState/$jobID @{ 'pause'= $true }
        }else{
            sleep 2
        }
    }
}

"Job finished with status: $($runs[0].backupRun.status)"

if($runs[0].backupRun.status -eq 'kSuccess'){
    exit 0
}else{
    exit 1
}

