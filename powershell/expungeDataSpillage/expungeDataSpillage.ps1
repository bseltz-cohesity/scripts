# usage: ./expungeDataSpillage.ps1 -vip mycluster -username admin [ -domain local ] -search 'partial/filepath' [ -delete ]

# note: -delete switch actually performs the delete, otherwise just perform a test run
# processing is logged at <scriptpath>/expungeLog.txt

# version 2.0 performance rewrite

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][string]$vip,
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$search,  # file name or path to search for
    [Parameter()][switch]$delete  # delete or just a test run
)

# log setup 
$scriptdir = Split-Path -parent $PSCommandPath
$runDate = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$logfile = Join-Path -Path $scriptdir -ChildPath "expungeLog-$runDate.txt"
$global:logItem=''

function log($text){
    "$text"
    $Global:logItem += "$text`n"
}

log "- Started at $(get-date) -------`n"

# display run mode
if ($delete) {
    log "----------------------------------"
    log "  *PERMANENT DELETE MODE*         "
    log "  - selection will be deleted!!!"
    log "  - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "----------------------------------"
}else{
    log "--------------------------"
    log "    *TEST RUN MODE*  "
    log "    - not deleting"
    log "    - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "--------------------------"
}

$archiveType = @{'0' = "kCloud"; '1' = "kTape"; '2' = "kNas" }

$clusters = @()
$instanceList = @()
$instanceNum = 1
$clusterNames = @{}
$foreignDetections = @()
$runcache = @{}
$affectedObjects = @{}
$processedObjects = @()

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to local and remote clusters
log "`nConnecting to local cluster $vip..."
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey

$localCluster = api get cluster
$localClusterId = $localCluster.id
$clusters += $localCluster.name
$clusterNames[[string]$localClusterId] = $localCluster.name

# search for files
$fileSearch = $search
log "`nSearching for $fileSearch...`n"

$jobs = api get protectionJobs
$restoreFiles = api get "/searchfiles?filename=$fileSearch" # $localCluster.get("/searchfiles?filename=$fileSearch")
$highestId = $restoreFiles.files.count - 1

if($highestId -ge 0){   
    0..$highestId | ForEach-Object{
        $selectedId = $_
        $restoreFile = $restoreFiles.files[$selectedId]
        
        if($restoreFile){
            $job = $jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }
            $jobName = $job.name
            $policyId = $job.policyId
            $policyClusterId = $policyId.split(':')[0]
            $objectName = $restoreFile.fileDocument.objectId.entity.displayName

            $objectId = $restoreFile.fileDocument.objectId.entity.id
            $affectedObjects["$jobName`:$objectName"] = 'retained'

            $instance = $instanceList | Where-Object { $_.objectName -eq $objectName -and $_.jobName -eq $jobName -and $_.fileName -eq $restoreFile.fileDocument.filename}
            if(! $instance){
                $instance = @{
                    'objectName' = $objectName;
                    'jobName' = $jobName;
                    'fileName' = $restoreFile.fileDocument.filename
                    'objectId' = $objectId;
                    'jobId' = $job.id
                    'instanceNum' = $instanceNum
                    'jobUid' = $job.uid
                }
                $instanceNum++
                $instanceList += $instance
            }
        }
    }
}


function deleteInstance($instance){
    $deletions = 0
    log "`nProcessing $($instance.fileName)...`n"
    log "Deleting object $($instance.objectName) from affected runs of job: $($instance.jobName)"
    $affectedObjects["$($instance.jobName)`:$($instance.objectName)"] = 'processed'
    foreach($cluster in $clusters){

        $clusterName = $cluster
        $jobs = api get protectionJobs
        $restoreFiles = api get "/searchfiles?filename=$($instance.fileName)"
        foreach ($restoreFile in $restoreFiles.files){
            $job = $jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }
            if($instance.objectName -eq $restoreFile.fileDocument.objectId.entity.displayName -and `
            $instance.jobName -eq $job.name){
                $clusterId = $restoreFile.fileDocument.objectId.jobUid.clusterId
                $clusterIncarnationId = $restoreFile.fileDocument.objectId.jobUid.clusterIncarnationId
                $entityId = $restoreFile.fileDocument.objectId.entity.id
                $encodedFileName = [System.Web.HttpUtility]::UrlEncode($restoreFile.fileDocument.filename)
                $origJobId = $restoreFile.fileDocument.objectId.jobUid.objectId
                $jobId = $restoreFile.fileDocument.objectId.jobId
                $job = $jobs | Where-Object { $_.id -eq $restoreFile.fileDocument.objectId.jobId }
                $policyId = $job.policyId
                $policyClusterId = $policyId.split(':')[0]
                if(! $runcache.ContainsKey("$clusterId-$jobId")){
                    $runs = api get "protectionRuns?jobId=$jobId&numRuns=999999&excludeNonRestoreableRuns=true&excludeTasks=true"
                    $runcache["$clusterId-$jobId"] = $runs
                }else{
                    $runs = $runcache["$clusterId-$jobId"]
                }
                $versions = api get "/file/versions?clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$entityId&filename=$encodedFileName&fromObjectSnapshotsOnly=false&jobId=$origJobId"

                foreach ($version in $versions.versions) {
                    $exactRun = $runs | Where-Object {$_.backupRun.jobRunId -eq $version.instanceId.jobInstanceId }
                    foreach($replica in $version.replicaInfo.replicaVec){
                        $updateProtectionJobRunsParam = @{
                            'jobRuns' = @(
                                @{
                                    'copyRunTargets'    = @();
                                    'runStartTimeUsecs' = $exactRun.backupRun.stats.startTimeUsecs;
                                    'jobUid'            = $instance.jobUid
                                }
                            )
                        }
                        if($replica.expiryTimeUsecs -ne 0 -and $replica.expiryTimeUsecs -gt (dateToUsecs (get-date))){
                            if ($replica.target.type -ne 2) {
                                if($replica.target.type -eq 1) {
                                    log "  $clusterName ($(usecsToDate $exactRun.backupRun.stats.startTimeUsecs))"
                                    $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += @{
                                        'daysToKeep' = 0;
                                        'type'       = 'kLocal'
                                    }
                                    $updateProtectionJobRunsParam.jobRuns[0].sourceIds = @($entityId)
                                }
                                if($replica.target.type -eq 3) {
                                    log "  $($replica.target.archivalTarget.name) ($(usecsToDate $exactRun.backupRun.stats.startTimeUsecs))"
                                    $updateProtectionJobRunsParam.jobRuns[0].copyRunTargets += @{
                                        'daysToKeep' = 0;
                                        'type' = 'kArchival';
                                        'archivalTarget' = @{
                                            'vaultName' = $replica.target.archivalTarget.name;
                                            'vaultId'= $replica.target.archivalTarget.vaultId;
                                            'vaultType' = $archiveType[[string]$replica.target.archivalTarget.type]
                                        }
                                    }
                                }
                                if ($updateProtectionJobRunsParam.jobRuns[0].copyRunTargets.count -gt 0){
                                    $deletions++
                                    if($delete){
                                        $null = api put "protectionRuns" $updateProtectionJobRunsParam
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if($deletions -eq 0){
        log "  no objects left to delete"
    }
}

# list affected objects
log ("`nMatches were found in the following objects")
log ("-------------------------------------------")
foreach($affectedObject in ($affectedObjects.Keys | Sort-Object)){
    $jobName, $objectName = $affectedObject.split(":")
    log ("$objectName`t(in job: $jobName)")
}

# selection menu
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

$choices = 0..($instanceNum - 1)

# prompt for selections
$selections = @()
$doneSelecting = $false
$askAgain = $false

"`nSelect Files to Expunge:"
while($false -eq $doneSelecting -or $askAgain -eq $True){
    $askAgain = $false
    $newselections = read-host -Prompt "Enter one or more (comma separated) id(s)"
    $newselections = $newselections.Replace(' ','')
    $newselections = $newselections.split(',')
    $newselections | ForEach-Object {
        $newselection = $_
        if($newselection -eq 0){
            $selections = @(0)
            break
        }
        if($newselection -in $choices){
            if($newselection -notin $selections){
                $selections += $newselection
                $doneSelecting = $True
            }
        }else{
            Write-Warning "$newselection is not a valid choice"
            $askAgain = $True
        }
    }
}

if($selections[0] -eq 0){
    log ("`nAll Items Selected")
}else{
    log ("`nItem(s) $([string]::join(', ',$selections)) Selected")
}

# process selections
if(0 -in $selections){
    foreach($instance in $instanceList){
        deleteInstance $instance
    }    
}else{
    foreach($selection in $selections){
        deleteInstance $instanceList[$selection-1]
    }
}

# report process summary
log ("`nSummary of Processed Objects")
log ("-------------------------------------")
foreach($affectedObject in ($affectedObjects.Keys | Sort-Object)){
    $jobName, $objectName = $affectedObject.split(":")
    $processed = $affectedObjects[$affectedObject]
    if($delete){
        if($processed -eq 'processed'){
            $processed = 'deleted'
        }
    }
    log ("($processed) $jobName`:$objectName")
}

"`nNote: Deleted objects may still be returned in search results until the index has been purged"

"`nWarning: please run the script against any other clusters where the spillage may have replicated to"

# close log
log "`n- Ended at $(get-date) -------`n`n"
$global:logItem | Out-File $logfile -Append
