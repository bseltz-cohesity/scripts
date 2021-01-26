[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'MiB',
    [Parameter()][string]$startDate,
    [Parameter()][string]$endDate
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$clusterName = $cluster.name

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

$dateString = (get-date).ToString("yyyy-MM-dd")
$outfileName = "$clusterName-CAD-Stats-$dateString.csv"
"Job Name,Object Name,Run Date,Logical Size ($unit),Logical Transferred ($unit),Phyisical Transferred ($unit),External Target" | Out-File -FilePath $outfileName

$jobs = api get protectionJobs | Where-Object {$_.isDirectArchiveEnabled -eq $True}
$search = api get "/searchvms?entityTypes=kNetapp&entityTypes=kGenericNas&entityTypes=kIsilon&entityTypes=kFlashBlade&entityTypes=kPure&vmName=*"
$protectedObjects = $search.vms | Where-Object {$_.vmDocument.jobName -in $jobs.name} | Sort-Object -Property {$_.vmDocument.jobName}

if($startDate){
    $startDateUsecs = dateToUsecs $startDate
}

if($endDate){
    $endDateUsecs = dateToUsecs $endDate
}

foreach($protectedObject in $protectedObjects){
    $doc = $protectedObject.vmDocument
    $jobName = $doc.jobName
    $objectName = $doc.objectName
    $jobId = $doc.objectId.jobId
    foreach($version in $doc.versions){
        $startTimeUsecs = $version.instanceId.jobStartTimeUsecs
        if(((! $endDateUsecs) -or ($startTimeUsecs -le $endDateUsecs)) -and ((! $startDateUsecs) -or ($startTimeUsecs -ge $startDateUsecs))){
            $vaultName = $version.replicaInfo.replicaVec[0].target.archivalTarget.name
            $run = api get "/backupjobruns?exactMatchStartTimeUsecs=$startTimeUsecs&id=$jobId"
            $archive = ($run.backupJobRuns.protectionRuns[0].copyRun).finishedTasks | Where-Object {$_.snapshotTarget.type -eq 3}
            $logicalTransferred = $archive.archivalInfo.logicalBytesTransferred
            $physicalTransferred = $archive.archivalInfo.bytesTransferred
            $logicalSize = $run.backupJobRuns.protectionRuns[0].backupRun.base.totalLogicalBackupSizeBytes
            "{0},{1},{2},""{3:n1}"",""{4:n1}"",""{5:n1}"",{6}" -f $jobName, $objectName, (usecsToDate $startTimeUsecs), (toUnits $logicalSize), (toUnits $logicalTransferred), (toUnits $physicalTransferred), $vaultName | Tee-Object -FilePath $outfileName -Append    
        }
    }
}

"`nOutput written to $outfileName"