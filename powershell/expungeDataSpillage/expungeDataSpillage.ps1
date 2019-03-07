### usage: ./expungeDataSpillage.ps1 -vip mycluster -username admin [ -domain local ] -search 'partial/filepath' [ -delete ]

### note: -delete switch actually performs the delete, otherwise just perform a test run
### processing is logged at <scriptpath>/expungeLog.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$search, # file name or path to search for
    [Parameter()][switch]$delete # delete or just a test run
)

### logging 

$scriptdir = Split-Path -parent $PSCommandPath
$runDate = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$logfile = Join-Path -Path $scriptdir -ChildPath "expungeLog-$runDate.txt"
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

$archiveType = @{'0' = "kCloud"; '1' = "kTape" }

$clusters = @()
$instanceList = @()
$instanceNum = 1
$backupList = @()
$backupNum = 0

### source the cohesity-api helper code
. ./cohesityCluster.ps1

### authenticate to local and remote clusters
log "`nConnecting to local cluster $vip..."
$cluster = connectCohesityCluster -server $vip -username $username -domain $domain -quiet

$clusters += $cluster

$remotes = $cluster.get('remoteClusters')
foreach ($remote in $remotes){
    $remoteIP = $remote.remoteIps[0]
    log "Connecting to remote cluster $($remote.name)..."
    $cluster = connectCohesityCluster -server $remoteIP -username $username -domain $domain -quiet
    $clusters += $cluster                    
}

### search for file
$fileSearch = $search
log "`nSearching for $fileSearch...`n"

foreach($cluster in $clusters){
    $clusterName = $cluster.get('cluster').name
    $jobs = $cluster.get('protectionJobs')
    $restoreFiles = $cluster.get("/searchfiles?filename=$fileSearch")
    $highestId = $restoreFiles.files.count - 1
     if($highestId -ge 0){   
        0..$highestId | ForEach-Object{
            $selectedId = $_
            $restoreFile = $restoreFiles.files[$selectedId]
            
            if($restoreFile){
                ### get versions
                $clusterId = $restoreFile.fileDocument.objectId.jobUid.clusterId
                $clusterIncarnationId = $restoreFile.fileDocument.objectId.jobUid.clusterIncarnationId
                $entityId = $restoreFile.fileDocument.objectId.entity.id
                $encodedFileName = [System.Web.HttpUtility]::UrlEncode($restoreFile.fileDocument.filename)
                $origJobId = $restoreFile.fileDocument.objectId.jobUid.objectId
                $jobId = $restoreFile.fileDocument.objectId.jobId
                $runs = $cluster.get("protectionRuns?jobId=$jobId")
                $versions = $cluster.get("/file/versions?clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$entityId&filename=$encodedFileName&fromObjectSnapshotsOnly=false&jobId=$origJobId")

                foreach ($version in $versions.versions) {
                    $jobName = ($jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }).name
                    $objectName = $restoreFile.fileDocument.objectId.entity.displayName
                    $exactRun = $runs | Where-Object {$_.backupRun.jobRunId -eq $version.instanceId.jobInstanceId }
                    ### get locations
                    $locations = @()
                    foreach($replica in $version.replicaInfo.replicaVec){
                        if($replica.expiryTimeUsecs -ne 0){
                            if ($replica.target.type -ne 2) {
                                if($replica.target.type -eq 3){
                                    $target = $replica.target
                                }else{
                                    $target = @{'type' = 1}
                                }
                                $location = @{
                                    'cluster' = $cluster;
                                    'clusterName' = $clusterName;
                                    'target' = $target;
                                    'sourceId' = $restoreFile.fileDocument.objectId.entity.id;
                                }
                                $locations += $location
                            }
                        }
                    }

                    if($locations.count -gt 0){

                        $instance = $instanceList | Where-Object { $_.objectName -eq $objectName -and $_.jobName -eq $jobName -and $_.fileName -eq $restoreFile.fileDocument.filename}
                        if(! $instance){
                            $instance = @{
                                'objectName' = $objectName;
                                'jobName' = $jobName;
                                'fileName' = $restoreFile.fileDocument.filename
                                'instanceNum' = $instanceNum
                            }
                            $instanceNum++
                            $instanceList += $instance
                        }    

                        $backup = $backupList | Where-Object {$_.objectName -eq $objectName -and $_.jobName -eq $jobName -and $_.startTimeUsecs -eq $exactRun.copyRun[0].runStartTimeUsecs}
                        if($backup){
                            $backup.locations += $locations
                        }else{
                            $backup = @{
                                'objectName' = $objectName;
                                'jobName' = $jobName;
                                'startTimeUsecs' = $exactRun.copyRun[0].runStartTimeUsecs;
                                'versionNum' = $backupNum++;
                                'locations' = $locations;
                                'instanceNum' = $instance.instanceNum
                                'jobUid' = $exactRun.jobUid
                            }
                            $backupList += $backup 
                        }
                    }
                }
            }
        }
    }
}

### display discovered runs
log "Found the file in the following protection runs:`n"
foreach ($backup in $backupList){
    log ("    {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
}

### selection menu
if($instanceList.Count -gt 0){
    log "`nSearch Results:`n"
    foreach ($instance in $instanceList){
        log "$($instance.instanceNum): $($instance.fileName)"
        log "   $($instance.jobName)::$($instance.objectName)"
        log "--"
    }
    log "0: Select All`n"
}else{
    log "`n* No Results Found *"
    log "`n- Ended at $(get-date) -------`n`n"
    if($delete){
        $global:logItem | Out-File $logfile -Append
    }
    exit
}

### prompt for selection
$selectedId='x'
while(!($selectedId -is [int] -and (-1 -gt $selectedId -le $instanceNum))){
    $selectedId = read-host -Prompt "Please select ID to expunge"    
    if($selectedId -ne '' -and $null -ne ($selectedId -as [int])){ 
        $selectedId = [int]$selectedId
        log "`n$selectedId selected`n" 
    }
}

function selectForDelete($instance){
    foreach ($backup in $backupList){
        if($backup.instanceNum -eq $instance.instanceNum){
            $backup['selected']=$True
        }
    } 
}

if($selectedId -eq 0){
    foreach($instance in $instanceList){
        selectForDelete $instance
    }
}else{
    selectForDelete $instanceList[$selectedId-1]
}

### display selected runs
log "The following protection runs have been selected for deletion:`n"
foreach ($backup in $backupList){
    if($backup.contains('selected')){
        log ("  (Selected) {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
    }else{
        log ("             {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
    }
}

### process deletes
if($delete){
    log "`nDeleting selected backups...`n"
    foreach($backup in $backupList){
        if($backup.Contains('selected')){
            log ("  Deleting {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
            foreach($location in $backup.locations){
                $updateProtectionJobRunsParam = @{
                    'jobRuns' = @(
                        @{
                            'copyRunTargets'    = @();
                            'runStartTimeUsecs' = $backup.startTimeUsecs;
                            'jobUid'            = $backup.jobUid;
                            'sourceIds'         = @(
                                $location.sourceId
                            )
                        }
                    )
                }
                if($location.target.type -eq 1){
                    log ("                        from {0}" -f $location.clusterName)
                    $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += @{
                            'daysToKeep' = 0;
                            'type'       = 'kLocal'
                        }
                }
                if($location.target.type -eq 3){
                    log ("                        from {0}" -f $location.target.archivalTarget.name)
                    $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += @{
                        'daysToKeep' = 0;
                        'type' = 'kArchival';
                        'archivalTarget' = @{
                            'vaultName' = $location.target.archivalTarget.name;
                            'vaultId'= $location.target.archivalTarget.vaultId;
                            'vaultType' = $archiveType[[string]$location.target.archivalTarget.type]
                        }
                    }

                }
                $result = $location.cluster.put("protectionRuns", $updateProtectionJobRunsParam)
                $location['deleted'] = $True
            }
        }
    }
}

### display processed results
log "`nEnd state of protection runs:`n"
foreach ($backup in $backupList){

    $deleted=$True
    foreach($location in $backup.locations){
        if($location.contains('deleted') -eq $false){
            $deleted = $false 
        }
    }
    if($deleted -eq $false){
        log ("  (Retained) {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
    }else{
        log ("  (Deleted)  {0}: {1} from {2}: {3}" -f $backup.versionNum, $backup.objectName, $backup.jobName, (usecsToDate $backup.startTimeUsecs))
    }
}

log "`n- Ended at $(get-date) -------`n`n"
if($delete){
    $global:logItem | Out-File $logfile -Append
}
