[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][int]$days = 7,
    [Parameter()][string]$objectName,
    [Parameter()][int]$anomalyStrength = 10,
    [Parameter()][int]$sleepTime = 10,
    [Parameter()][int]$retryCount = 10,
    [Parameter()][int]$maxFiles = 100
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain 'local' -helios

### determine start and end dates
$today = Get-Date
$uStart = timeAgo $days 'days'
$uEnd = dateToUsecs ($today)

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

# outfile
$dateString = ($today).ToString('yyyy-MM-dd')
$outfileName = "anomalyReport-$dateString.tsv"

# headings
"Cluster Name`tJob Name`tJob Type`tRun Date`tObject Name`tAnomaly Strength`tFiles Affected`tFile Name`tOperation" | Out-File -FilePath $outfileName

$alerts = api get -mcm "alerts?alertCategoryList=kSecurity&alertStateList=kOpen&endDateUsecs=$uEnd&maxAlerts=1000&startDateUsecs=$uStart&_includeTenantInfo=true"

foreach($alert in $alerts | Where-Object {$_.alertDocument.alertName -eq 'DataIngestAnomalyAlert'}){
    $strength = ($alert.propertyList | Where-Object key -eq 'anomalyStrength').value
    if($strength -ge $anomalyStrength){
        $clusterName = $alert.clusterName
        $latestSnapshotTimeStamp = $alert.latestTimestampUsecs
        $jobName = ($alert.propertyList | Where-Object key -eq 'jobName').value
        $jobId = ($alert.propertyList | Where-Object key -eq 'jobId').value
        $jobInstanceId = ($alert.propertyList | Where-Object key -eq 'jobInstanceId').value
        $jobStartTimeUsecs = ($alert.propertyList | Where-Object ket -eq 'jobStartTimeUsecs').value
        $object = ($alert.propertyList | Where-Object key -eq 'object').value
        $entityId = ($alert.propertyList | Where-Object key -eq 'entityId').value
        if(!$objectName -or $objectName -eq $object){
            $objectType = ($alert.propertyList | Where-Object key -eq 'environment').value
            $jobStartTimeUsecs = ($alert.propertyList | Where-Object key -eq 'jobStartTimeUsecs').value
            $clusterId = ($alert.propertyList | Where-Object key -eq 'cid').value
            $clusterIncarnationId = ($alert.propertyList | Where-Object key -eq 'clusterIncarnationId').value
            $partitionId = ($alert.propertyList | Where-Object key -eq 'clusterPartitionId').value
            $anomalousJobInstanceId = ($alert.propertyList | Where-Object key -eq 'anomalousJobInstanceId').value
            $anomalousJobStartTimeUsecs = ($alert.propertyList | Where-Object key -eq 'anomalousJobStartTimeUsecs').value
            if($anomalousJobStartTimeUsecs){
                Write-Host "$object ($(usecsToDate $jobStartTimeUsecs))"
                $snapshot2 = $alert.id.split(':')[1]
                $conn = heliosCluster $clusterName
    
                $diffParams = @{
                    "baseSnapshotJobInstanceId" = [Int64]$jobInstanceId;
                    "baseSnapshotTimeUsecs" = [Int64]$jobStartTimeUsecs;
                    "clusterId" = [Int64]$clusterId;
                    "entityType" = $objectType;
                    "incarnationId" = [Int64]$clusterIncarnationId;
                    "jobId" = [Int64]$jobId;
                    "partitionId" = [Int64]$partitionId;
                    "snapshotJobInstanceId" = [Int64]$anomalousJobInstanceId;
                    "snapshotTimeUsecs" = [Int64]$anomalousJobStartTimeUsecs;
                    "pageNumber" = 1;
                    "pageSize" = 50
                }
                $changeLogStats = api get -mcm "snapshots/changeLogStats?clusterId=$clusterId&entityId=$entityId&jobId=$jobId&snapshotTimeUsecs=$latestSnapshotTimeStamp"
                $totalFiles = $changeLogStats.total
                $diffStatus = 'kRunning'
                $diffStatusCount = 0
                $filesCounted = 0
                
                while(1){
                    $diff = api post -v2 data-protect/objects/$entityId/snapshotDiff $diffParams
                    $diffStatus = $diff.status
                    $diffStatusCount += 1
                    if($diffStatus -eq 'kCompleted'){
                        foreach($fileOp in $diff.fileOperations){
                            $operation = $fileOp.operation.subString(1)
                            $filePath = $fileOp.filePath
                            $filesCounted += 1
                            if($maxFiles -eq 0 -or $filesCount -le $maxFiles){
                                # Write-Host "    $operation  $filePath"
                                "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}" -f $clusterName, $jobName, $objectType, $(usecsToDate $jobStartTimeUsecs), $object, $strength, $totalFiles, $filePath, $operation | Out-File -FilePath $outfileName -Append
                            }
                            
                        }
                        $diffParams.pageNumber += 1
                        $diffStatusCount = 0
                    }else{
                        Start-Sleep $sleepTime
                    }
                    if(($diffStatusCount -ge $retryCount) -or ($filesCounted -eq $totalFiles) -or ($maxFiles -gt 0 -and $filesCounted -ge $maxFiles)){
                        Write-Host "    retrieved $filesCounted of $totalFiles files"
                        break
                    }
                }
                if($filesCounted -eq 0){
                    "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}" -f $clusterName, $jobName, $objectType, $(usecsToDate $jobStartTimeUsecs), $object, $strength, $totalFiles, 'file changes not computed' | Out-File -FilePath $outfileName -Append
                }
            }
        }    
    }
}

"`nOutput saved to $outfilename`n"
