# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,          # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,     # username (local or AD)
    [Parameter()][string]$domain = 'local'               # local or AD domain
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$jobs = api get protectionJobs?environments=kGenericNas | Where-Object {$_.isActive -ne $false -and $_.isDeleted -eq $True}

foreach($job in $jobs){
    $run = api get "protectionRuns?jobId=$($job.id)&numRuns=1"
    $jobId = $job.id
    $startTimeUsecs = $run.backupRun.stats.startTimeUsecs
    $jobRun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&id=$jobId"
    $replTasks = $jobRun.backupJobRuns.protectionRuns[0].copyRun.finishedTasks | Where-Object {$_.snapshotTarget.type -eq 2}
    $jobRun.backupJobRuns.protectionRuns[0].copyRun.activeTasks.finishedCopySubTasks
    $subTasks = $replTasks.finishedCopySubTasks
    foreach($subTask in $subTasks){
        $rid = $subTask.taskUid.objectId
        $remoteCluster = $subTask.snapshotTarget.replicationTarget.clusterName
        $entityName = $subTask.entity.displayName
        "dummy:dummy:dummy:1,{0}:{1}:{2}:{3}" -f $job.name, $entityName, $remoteCluster, $rid
    }
}

"`nExample:`n"
"iris_cli cluster update-gflag gflag-name=bridge_madrox_ancestor_rid_hint gflag-value=""dummy:dummy:dummy:1,{0}:{1}:{2}:{3}"" reason=""madrox seed"" effective-now=true service-name=bridge" -f $job.name, $entityName, $remoteCluster, $rid
"`n(replace deleted job with new job)`n"