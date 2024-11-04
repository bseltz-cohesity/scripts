[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][int]$days = 7,
    [Parameter()][string]$objectName,
    [Parameter()][int]$anomalyStrength = 10,
    [Parameter()][int]$sleepTime = 1,
    [Parameter()][int]$retryCount = 10,
    [Parameter()][int]$timeout = 20,
    [Parameter()][switch]$latestPerObject
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
$outfileName = "anomalyReport-$dateString.csv"

# headings
"""Cluster Name"",""Job Name"",""Job Type"",""Run Date"",""Object Name"",""Anomaly Strength"",""Files Affected"",""File Name"",""Operation""" | Out-File -FilePath $outfileName -Encoding utf8

$alerts = api get -mcm "alerts?alertCategoryList=kSecurity&alertStateList=kOpen&endDateUsecs=$uEnd&maxAlerts=1000&startDateUsecs=$uStart&_includeTenantInfo=true"
$foundObject = $false
$seenObject = @{}
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
        if($latestPerObject -and $object -in $seenObject.keys){
            continue
        }else{
            $seenObject[$object] = 1
        }
        $entityId = ($alert.propertyList | Where-Object key -eq 'entityId').value
        if(!$objectName -or $objectName -eq $object){
            $foundObject = $True
            $entityId = ($alert.propertyList | Where-Object key -eq 'entityId').value
            $objectType = ($alert.propertyList | Where-Object key -eq 'environment').value
            $jobStartTimeUsecs = ($alert.propertyList | Where-Object key -eq 'jobStartTimeUsecs').value
            $clusterId = ($alert.propertyList | Where-Object key -eq 'cid').value
            $clusterIncarnationId = ($alert.propertyList | Where-Object key -eq 'clusterIncarnationId').value
            $partitionId = ($alert.propertyList | Where-Object key -eq 'clusterPartitionId').value
            $anomalousJobInstanceId = ($alert.propertyList | Where-Object key -eq 'anomalousJobInstanceId').value
            $anomalousJobStartTimeUsecs = $alert.latestTimestampUsecs

            $statusQuery = @{
                "clusterId" = [Int64]$clusterId;
                "incarnationId" = [Int64]$clusterIncarnationId;
                "objectId" = [Int64]$entityId;
                "protectionGroupId" = [Int64]$jobId;
                "runStartTimeUsecs" = [Int64]$anomalousJobStartTimeUsecs
            }
            $status = api post -mcmv2 tags/snapshots/status @($statusQuery)

            $detailsQuery = @{
                "clusterIdentifiers" = @(
                    "$($status.snapshot.clusterId):$($status.snapshot.incarnationId)"
                );
                "tenantIds" = @($status.snapshot.tenantIds);
                "objectIds" = @(
                    $status.snapshot.objectId
                );
                "protectionGroupIds" = @(
                    "$($status.snapshot.clusterId):$($status.snapshot.incarnationId):$($status.snapshot.protectionGroupId)"
                );
                "fromRunStartTimeUsecs" = $anomalousJobStartTimeUsecs;
                "toRunStartTimeUsecs" = $anomalousJobStartTimeUsecs;
            }
            $details = api post -mcmv2 data-protect/copystats/details $detailsQuery
            $totalFiles = $details[0].indexingStats.deletedDocumentCount + $details[0].indexingStats.newDocumentCount + $details[0].indexingStats.updatedDocumentCount

            if($anomalousJobStartTimeUsecs){
                Write-Host "$object ($(usecsToDate $jobStartTimeUsecs)) files affected: $totalFiles"
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
                    "snapshotJobInstanceId" = [Int64]$status.snapshot.runId;
                    "snapshotTimeUsecs" = [Int64]$anomalousJobStartTimeUsecs;
                    "pageNumber" = 1;
                    "pageSize" = 100
                }
                $diffStatus = 'kRunning'
                $diffStatusCount = 0
                $filesCounted = 0
                
                while(1){
                    $diff = api post -v2 data-protect/objects/$entityId/snapshotDiff $diffParams -timeout $timeout
                    $diffStatus = $diff.status
                    $diffStatusCount += 1
                    if($diffStatus -eq 'kCompleted'){
                        foreach($fileOp in $diff.fileOperations){
                            $operation = $fileOp.operation.subString(1)
                            $filePath = $fileOp.filePath
                            $filesCounted += 1
                            """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}""" -f $clusterName, $jobName, $objectType, $(usecsToDate $jobStartTimeUsecs), $object, $strength, $totalFiles, $filePath, $operation | Out-File -FilePath $outfileName -Append
                        }
                        Write-Host "  $filesCounted of $totalFiles"
                        $diffParams.pageNumber += 1
                        $diffStatusCount = 0
                    }else{
                        Start-Sleep $sleepTime
                    }
                    if(($diffStatusCount -ge $retryCount) -or ($filesCounted -ge $totalFiles) ){
                        break
                    }
                }
                Write-Host ""
                if($filesCounted -eq 0){
                    "{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}" -f $clusterName, $jobName, $objectType, $(usecsToDate $jobStartTimeUsecs), $object, $strength, $totalFiles, 'file changes not computed' | Out-File -FilePath $outfileName -Append
                }
            }
        }    
    }
}

if($objectName -and $foundObject -eq $false){
    Write-Host "`nNo anomalies found for object $objectName" -ForegroundColor Yellow
}

"`nOutput saved to $outfilename`n"