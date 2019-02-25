### usage: ./extendRetention.ps1 -vip mycluster -username admin -jobName myjobname -daysToKeep 365

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter(Mandatory = $True)][string]$jobName, #Name of the job to pause
    [Parameter(Mandatory = $True)][int]$daysToKeep #days to extend retention
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find run to extend
$job = api get protectionJobs | Where-Object { $_.name -ieq $jobName }
if($job){
    $backupInfo = api get /backupjobs/$($job.id)
    $runs = api get protectionRuns?jobId=$($job.id) | Where-Object { $_.copyRun[0].status -eq 'kSuccess' }
    if($runs){
        $run = $runs[0]
    }else{
        Write-Warning "No Successful Backup Runs Prensent!"
        exit
    }
}else{
    Write-Warning "Job $jobName not found..."
    exit
}

$extendTask = @{
    "jobRuns" = @(
      @{
        "copyRunTargets" = @(
          @{
            "daysToKeep" = $daysToKeep;
            "type" = "kLocal"
          }
        );
        "runStartTimeUsecs" = $run.copyRun[0].runStartTimeUsecs;
        "jobUid" = @{
          "clusterId" = $backupInfo.backupJob.remoteJobUids[0].clusterId;
          "clusterIncarnationId" = $backupInfo.backupJob.remoteJobUids[0].clusterIncarnationId;
          "id" = $backupInfo.backupJob.remoteJobUids[0].objectId
        }
      }
    )
  }
'exending retention of latest source backup...'
$extend = api put protectionRuns $extendTask
