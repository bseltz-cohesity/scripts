### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$objectName, # source server
    [Parameter(Mandatory = $True)][string]$jobName # narrow search by job name
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# find backups for source server
$searchResults = api get "/searchvms?vmName=$objectName"
$searchResults = $searchResults.vms | Where-Object {$_.vmDocument.objectName -eq $objectName}

# narrow search by job name
if($jobName){
    $searchResults = $searchResults | Where-Object {$_.vmDocument.jobName -eq $jobName}
}

if(!$searchResults){
    if($jobName){
        Write-Host "$objectName is not protected by $jobName" -ForegroundColor Yellow
    }else{
        Write-Host "$objectName is not protected" -ForegroundColor Yellow
    }
    exit 1
}

$searchResult = ($searchResults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$doc = $searchResult.vmDocument

if($doc.versions.count -gt 0){
    $objectNameEncoded = $objectName.Replace('\','-').Replace('/','-').Replace(':','-')
    $jobNameEncoded = $jobName.Replace('\','-').Replace('/','-').Replace(':','-')
    $outFile = $(Join-Path -Path $PSScriptRoot -ChildPath "objectRunStats-$jobNameEncoded-$objectNameEncoded.csv")
    "Gathering Stats from the following dates:"
    "{0},{1},{2},{3},{4},{5},{6}" -f "Date",
                                     "Day of Week", 
                                     "Duration in Minutes", 
                                     "Date Read GiB", 
                                     "Data Written GiB", 
                                     "Files Backed Up", 
                                     "Total Files" | Out-File -FilePath $outFile
}

foreach($version in $doc.versions){
    $jobId = $doc.objectId.jobId
    $runStartTimeUsecs = $version.instanceId.jobStartTimeUsecs
    $runDate = usecsToDate $runStartTimeUsecs
    $runs = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$runStartTimeUsecs&id=$jobId&onlyReturnDataMigrationJobs=false"
    $run = $runs.backupJobRuns.protectionRuns[0].backupRun
    $task = $run.latestFinishedTasks | Where-Object {$_.base.sources[0].source.displayName -eq $objectName}
    $taskStartTimeUsecs = $task.base.startTimeUsecs
    $taskEndTimeUsecs = $task.base.endTimeUsecs
    $durationMinutes = [Math]::Round(($taskEndTimeUsecs - $taskStartTimeUsecs)/(1000000 * 60))
    $readGiB = [Math]::Round($task.base.totalBytesReadFromSource/(1024 * 1024 * 1024), 1)
    $writtenGiB = [Math]::Round($task.base.totalPhysicalBackupSizeBytes/(1024 * 1024 * 1024), 1)
    $totalFiles = $task.currentSnapshotInfo.totalEntityCount
    $changedFiles = $task.currentSnapshotInfo.totalChangedEntityCount
    if(! $changedFiles){
        $changedFiles = 0
    }
    "  $runDate"
    "{0},{1},{2},{3},{4},{5},{6}" -f $runDate,
                                     $runDate.DayOfWeek, 
                                     $durationMinutes, 
                                     $readGiB, 
                                     $writtenGiB, 
                                     $changedFiles, 
                                     $totalFiles | Out-File -FilePath $outFile -Append
}

if($doc.versions.count -gt 0){
    "Output saved to $outFile"
}else{
    "Nothng found for $objectName"
}
