### usage: ./expungeDataSpillage.ps1 -vip mycluster -username admin [ -domain local ] -search 'partial/filepath' [ -delete ]

### note: -delete switch actually performs the delete, otherwise just perform a test run
### processing is logged at <scriptpath>/expungeLog.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$search, #file name or path to download
    [Parameter()][switch]$delete
)

$scriptdir = Split-Path -parent $PSCommandPath
$logfile = Join-Path -Path $scriptdir -ChildPath 'expungeLog.txt'

### display run mode

if ($delete) {
    "----------------------------------"
    "  *PERMANENT DELETE MODE*         "
    "  - selection will be deleted!!!"
    "  - logging to $logfile"
    "  - press CTRL-C to exit"
    "----------------------------------"
}
else {
    "--------------------------"
    "    *TEST RUN MODE*       "
    "    - not deleting"
    "    - not logging"
    "--------------------------"
}

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$replicaType = @{'1' = 'kLocal'; '2' = 'kReplica'; '3' = 'kArchival'}
$archiveType = @{'0' = "kCloud"; '1' = "kTape" }
$jobs = api get protectionJobs

### provide file to search for
$fileSearch = $search
"Searching for $fileSearch..."
$restoreFiles = api get "/searchfiles?filename=$fileSearch"

### display files
$id = 0
"Search Results:"
"----"
foreach ($restoreFile in $restoreFiles.files){
    "$($id): $($restoreFile.fileDocument.filename)"
    "$(($jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }).name)::$($restoreFile.fileDocument.objectId.entity.displayName)"
    "----"
    $id += 1
}

### prompt for ID to select one from result set
$selectedId='x'
while(!($selectedId -is [int] -and $restoreFiles.files[$selectedId])){
    $selectedId = read-host -Prompt "Please select ID to expunge"    
    if($selectedId -ne '' -and ($selectedId -as [int]) -ne $null){ $selectedId = [int]$selectedId }
}

$restoreFile = $restoreFiles.files[$selectedId]

### gather info for log
$logItem = "- Started at $(get-date) -------`n"
$logItem += "FileName: $($restoreFile.fileDocument.filename)`n"
$logItem += "JobName: $(($jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }).name)`n"
$logItem += "ObjectName: $($restoreFile.fileDocument.objectId.entity.displayName)`n"

### get versions
$clusterId = $restoreFile.fileDocument.objectId.jobUid.clusterId
$clusterIncarnationId = $restoreFile.fileDocument.objectId.jobUid.clusterIncarnationId
$entityId = $restoreFile.fileDocument.objectId.entity.id
$encodedFileName = [System.Web.HttpUtility]::UrlEncode($restoreFile.fileDocument.filename)
$jobId = $restoreFile.fileDocument.objectId.jobId

"Searching for versions to delete..."
$versions = api get "/file/versions?clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$entityId&filename=$encodedFileName&fromObjectSnapshotsOnly=false&jobId=$jobId"

$runs = api get protectionRuns?jobId=$jobId

### delete protected object from each affected version
foreach ($version in $versions.versions){
    $exactRun = $runs | Where-Object {$_.backupRun.jobRunId -eq $version.instanceId.jobInstanceId }
    "Deleting $($restoreFile.fileDocument.objectId.entity.displayName) from $($exactRun.jobName): $(usecsToDate $exactRun.copyRun[0].runStartTimeUsecs)"
    $logItem += "Deleting $($restoreFile.fileDocument.objectId.entity.displayName) from $($exactRun.jobName): $(usecsToDate $exactRun.copyRun[0].runStartTimeUsecs)`n"
    $updateProtectionJobRunsParam = @{
        'jobRuns' = @(
            @{
                'copyRunTargets' = @();
                'runStartTimeUsecs' = $exactRun.copyRun[0].runStartTimeUsecs;
                'jobUid' = $exactRun.jobUid;
                'sourceIds' = @(
                    $restoreFile.fileDocument.objectId.entity.id
                )
            }
        )
    }
    ### delete local snapshot, remote replicas and archive targets
    foreach ($replica in $version.replicaInfo.replicaVec){

        $newCopyRunTarget = @{
            'daysToKeep' = 0;
            'type' = $replicaType[[string]$replica.target.type]
        }
        if($replica.target.type -eq 1){
            "  Local Snapshot"
            $logItem += "  Local Snapshot`n"
        }
        if($replica.target.type -eq 3){
            $newCopyRunTarget['archivalTarget']=@{}
            $newCopyRunTarget['archivalTarget']['vaultName'] = $replica.target.archivalTarget.name
            $newCopyRunTarget['archivalTarget']['vaultId'] = $replica.target.archivalTarget.vaultId
            $newCopyRunTarget['archivalTarget']['vaultType'] = $archiveType[[string]$replica.target.archivalTarget.type]
            "  Archive on $($replica.target.archivalTarget.name)"
            $logItem += "  Archive on $($replica.target.archivalTarget.name)`n"
        }
        if($replica.target.type -eq 2){
            $newCopyRunTarget['replicationTarget']=@{}
            $newCopyRunTarget['replicationTarget']['clusterId']=$replica.target.replicationTarget.clusterId
            $newCopyRunTarget['replicationTarget']['clusterName']=$replica.target.replicationTarget.clusterName
            "  Replica on $($replica.target.replicationTarget.clusterName)"
            $logItem += "  Replica on $($replica.target.replicationTarget.clusterName)`n"
        }
        $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += $newCopyRunTarget
    }
    ### execute the deletion
    if($delete){
        api put protectionRuns $updateProtectionJobRunsParam
    }
}
$logItem += "- Ended at $(get-date) -------`n`n"
#$logItem | Out-File $logfile -Append
if($delete){
    $logItem | Out-File $logfile -Append
}
