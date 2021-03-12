### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

$cluster = api get cluster

$outFile = $(Join-Path -Path $PSScriptRoot -ChildPath "nasObjectStats-$($cluster.name).csv")
"{0},{1},{2},{3},{4},{5},{6},{7}" -f "JobName",
                                     "Object",
                                     "Date", 
                                     "Duration in Minutes", 
                                     "Date Read GiB", 
                                     "Data Written GiB", 
                                     "Files Backed Up", 
                                     "Total Files" | Out-File -FilePath $outFile

# find nas backups
$searchResults = api get "/searchvms?entityTypes=kNetapp&entityTypes=kGenericNas&entityTypes=kIsilon&entityTypes=kFlashBlade&vmName=*"
$searchResults = $searchResults.vms

foreach($searchResult in $searchResults){
    $doc = $searchResult.vmDocument
    $jobName = $doc.jobName
    $objectName = $doc.objectName
    if($doc.versions.count -gt 0){
        $version = $doc.versions[0]
        $jobId = $doc.objectId.jobId
        $runStartTimeUsecs = $version.instanceId.jobStartTimeUsecs
        $runDate = usecsToDate $runStartTimeUsecs
        $run = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$runStartTimeUsecs&id=$jobId&onlyReturnDataMigrationJobs=false"
        $run = $run.backupJobRuns.protectionRuns[0].backupRun
        $task = $run.latestFinishedTasks | Where-Object {$_.base.sources[0].source.displayName -eq $objectName}
        $taskStartTimeUsecs = $task.base.startTimeUsecs
        $taskEndTimeUsecs = $task.base.endTimeUsecs
        $durationMinutes = [Math]::Round(($taskEndTimeUsecs - $taskStartTimeUsecs)/(1000000 * 60))
        $readGiB = [Math]::Round($task.base.totalBytesReadFromSource/(1024 * 1024 * 1024), 1)
        $writtenGiB = [Math]::Round($task.base.totalPhysicalBackupSizeBytes/(1024 * 1024 * 1024), 1)
        $task.currentSnapshotInfo.totalEntityCount
        $totalFiles = $task.currentSnapshotInfo.totalEntityCount
        $changedFiles = $task.currentSnapshotInfo.totalChangedEntityCount
        if(! $changedFiles){
            $changedFiles = 0
        }
        "$jobName - $objectName"
        "{0},{1},{2},{3},{4},{5},{6},{7}" -f $jobName,
                                            $objectName,
                                            $runDate,
                                            $durationMinutes, 
                                            $readGiB, 
                                            $writtenGiB, 
                                            $changedFiles, 
                                            $totalFiles | Out-File -FilePath $outFile -Append  
    }
}

"Output save to $outfile"