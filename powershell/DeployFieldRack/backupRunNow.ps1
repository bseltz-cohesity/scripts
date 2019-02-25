### usage: ./backupRunNow.ps1 -vip mycluster -username admin [ -domain local ] -jobName 'VM Backup' -daysToKeep 5 -targetCluster mydrcluster

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName, #protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$daysToKeep #days to keep backup
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find the job and policy
$job = api get protectionJobs | Where-Object { $_.name -ieq $jobName }
if($job){
    $pol = api get protectionPolicies/$($job.policyId)
}else{
    Write-Warning "Job $jobName not found..."
    exit
}

### RunProtectionJobParam object
$jobdata = @{
    "copyRunTargets" = @(
      @{
        "daysToKeep" = [int] $daysToKeep;
        "replicationTarget" = @{
          "clusterId" = $pol.snapshotReplicationCopyPolicies[0].target.clusterId;
          "clusterName" = $pol.snapshotReplicationCopyPolicies[0].target.clusterName
        };
        "type" = "kRemote"
      }
    );
    "sourceIds" = @();
    "runType" = "kRegular"
  }

### run protectionJob
api post ('protectionJobs/run/' + $job.id) $jobdata
"Running $jobName..."
