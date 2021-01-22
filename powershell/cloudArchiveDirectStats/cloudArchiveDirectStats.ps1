[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$clusterName = $cluster.name

$dateString = (get-date).ToString("yyyy-MM-dd")
$outfileName = "$clusterName-CAD-Stats-$dateString.csv"
"Job Name,Object Name,Size (MiB),Run Date,Transferred (MiB),External Target" | Out-File -FilePath $outfileName

$jobs = api get protectionJobs | Where-Object {$_.isDirectArchiveEnabled -eq $True}
$search = api get "/searchvms?entityTypes=kNetapp&entityTypes=kGenericNas&entityTypes=kIsilon&entityTypes=kFlashBlade&entityTypes=kPure&vmName=*"
$protectedObjects = $search.vms | Where-Object {$_.vmDocument.jobName -in $jobs.name} | Sort-Object -Property {$_.vmDocument.jobName}

foreach($protectedObject in $protectedObjects){
    $doc = $protectedObject.vmDocument
    $jobName = $doc.jobName
    $objectName = $doc.objectName
    $jobId = $doc.objectId.jobId
    foreach($version in $doc.versions){
        $startTimeUsecs = $version.instanceId.jobStartTimeUsecs
        $vaultName = $version.replicaInfo.replicaVec[0].target.archivalTarget.name
        $run = api get "/backupjobruns?exactMatchStartTimeUsecs=$startTimeUsecs&id=$jobId"
        $archive = ($run.backupJobRuns.protectionRuns[0].copyRun).finishedTasks | Where-Object {$_.snapshotTarget.type -eq 3}
        $transferred = $archive.archivalInfo.logicalBytesTransferred / (1024 * 1024)
        $size = $archive.archivalInfo.bytesTransferred / (1024 * 1024)
        "{0},{1},{2:n1},{3},{4:n1},{5}" -f $jobName, $objectName, $size, (usecsToDate $startTimeUsecs), $transferred, $vaultName | Tee-Object -FilePath $outfileName -Append
    }
}

"`nOutput written to $outfileName"