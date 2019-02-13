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
$global:logItem=''

function log($text){
    "$text"
    $Global:logItem += "$text`n"
}

log "- Started at $(get-date) -------`n"

### display run mode

if ($delete) {
    log "----------------------------------"
    log "  *PERMANENT DELETE MODE*         "
    log "  - selection will be deleted!!!"
    log "  - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "----------------------------------"
}
else {
    log "--------------------------"
    log "    *TEST RUN MODE*  "
    log "    - not deleting"
    log "    - not logging"
    log "--------------------------"
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
log "`nSearching for $fileSearch...`n"
$restoreFiles = api get "/searchfiles?filename=$fileSearch"

### display files
$id = 0
$highestId = 0
log "Search Results:"
log "----"
foreach ($restoreFile in $restoreFiles.files){
    log "$($id): $($restoreFile.fileDocument.filename)"
    log "$(($jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }).name)::$($restoreFile.fileDocument.objectId.entity.displayName)"
    log "----"
    $highestId = $id
    $id += 1
}

if($id -gt 0){
    log "$($id): Select All"
    log "----"
}else{
    log "`n* No Results Found *"
    log "`n- Ended at $(get-date) -------`n`n"
    if($delete){
        $global:logItem | Out-File $logfile -Append
    }
    exit
}

### prompt for ID to select one from result set
$selectedId='x'
while(!($selectedId -is [int] -and (-1 -gt $selectedId -le $id))){
    $selectedId = read-host -Prompt "Please select ID to expunge"    
    if($selectedId -ne '' -and ($selectedId -as [int]) -ne $null){ 
        $selectedId = [int]$selectedId
        log "`n$selectedId selected" 
    }
}

function expunge($selectedId) {
    $restoreFile = $restoreFiles.files[$selectedId]

    ### gather info for log
    log "`nFileName: $($restoreFile.fileDocument.filename)"
    log "   JobName: $(($jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }).name)"
    log "ObjectName: $($restoreFile.fileDocument.objectId.entity.displayName)"

    ### get versions
    $clusterId = $restoreFile.fileDocument.objectId.jobUid.clusterId
    $clusterIncarnationId = $restoreFile.fileDocument.objectId.jobUid.clusterIncarnationId
    $entityId = $restoreFile.fileDocument.objectId.entity.id
    $encodedFileName = [System.Web.HttpUtility]::UrlEncode($restoreFile.fileDocument.filename)
    $jobId = $restoreFile.fileDocument.objectId.jobId

    "`nSearching for versions to delete..."
    $versions = api get "/file/versions?clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$entityId&filename=$encodedFileName&fromObjectSnapshotsOnly=false&jobId=$jobId"

    $runs = api get protectionRuns?jobId=$jobId

    ### delete protected object from each affected version
    foreach ($version in $versions.versions) {
        $exactRun = $runs | Where-Object {$_.backupRun.jobRunId -eq $version.instanceId.jobInstanceId }
        log "`nDeleting $($restoreFile.fileDocument.objectId.entity.displayName) from $($exactRun.jobName): $(usecsToDate $exactRun.copyRun[0].runStartTimeUsecs)"
        $updateProtectionJobRunsParam = @{
            'jobRuns' = @(
                @{
                    'copyRunTargets'    = @();
                    'runStartTimeUsecs' = $exactRun.copyRun[0].runStartTimeUsecs;
                    'jobUid'            = $exactRun.jobUid;
                    'sourceIds'         = @(
                        $restoreFile.fileDocument.objectId.entity.id
                    )
                }
            )
        }
        ### delete local snapshot, remote replicas and archive targets
        foreach ($replica in $version.replicaInfo.replicaVec) {

            $newCopyRunTarget = @{
                'daysToKeep' = 0;
                'type'       = $replicaType[[string]$replica.target.type]
            }
            if ($replica.target.type -eq 1) {
                log "    Local Snapshot"
            }
            if ($replica.target.type -eq 3) {
                $newCopyRunTarget['archivalTarget'] = @{}
                $newCopyRunTarget['archivalTarget']['vaultName'] = $replica.target.archivalTarget.name
                $newCopyRunTarget['archivalTarget']['vaultId'] = $replica.target.archivalTarget.vaultId
                $newCopyRunTarget['archivalTarget']['vaultType'] = $archiveType[[string]$replica.target.archivalTarget.type]
                log "    Archive on $($replica.target.archivalTarget.name)"
            }
            if ($replica.target.type -eq 2) {
                $newCopyRunTarget['replicationTarget'] = @{}
                $newCopyRunTarget['replicationTarget']['clusterId'] = $replica.target.replicationTarget.clusterId
                $newCopyRunTarget['replicationTarget']['clusterName'] = $replica.target.replicationTarget.clusterName
                log "    Replica on $($replica.target.replicationTarget.clusterName)"
            }
            $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += $newCopyRunTarget
        }
        ### execute the deletion
        if ($delete) {
            $result = api put protectionRuns $updateProtectionJobRunsParam
        }
    }
    if ($delete) {
        $versions = api get "/file/versions?clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$entityId&filename=$encodedFileName&fromObjectSnapshotsOnly=false&jobId=$jobId"
        if ($versions.versions -eq $null) {
            log "`n*** All selected instances have been successfully deleted ***"
        }
        else {
            log "`nxxx There appears to be instances remaining - please investigate xxx"
        }
    }
}

if($selectedId -eq $id){
    0..$highestId | ForEach-Object{
       expunge $_ 
    }
}else{
    expunge $selectedId
}

log "`n- Ended at $(get-date) -------`n`n"
if($delete){
    $global:logItem | Out-File $logfile -Append
}