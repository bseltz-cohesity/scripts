[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][int]$days = 7,
    [Parameter()][string]$objectName,
    [Parameter()][int]$anomalyStrength = 10,
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'GiB'
)

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

function normalize($val){
    if(!$val){
        $val = 0
    }
    if($val -eq -1){
        $val = 0
    }
    return ("{0:n0}" -f $val)
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain 'local' -helios

### determine start and end dates
$today = Get-Date
$uStart = timeAgo $days 'days'
$uEnd = dateToUsecs $today

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

# outfile
$dateString = ($today).ToString('yyyy-MM-dd')
$outfileName = "anomalyReport-$dateString.tsv"

# headings
"Cluster Name`tJob Name`tJob Type`tRun Date`tObject Name`tAnomaly Strength`tFiles Deleted`tFiles Added`tFiles Changed`tFiles Unchanged`tEntropy`tData Read ($unit)`tData Written ($unit)" | Out-File -FilePath $outfileName

$alerts = api get -mcm "alerts?alertCategoryList=kSecurity&alertStateList=kOpen&maxAlerts=1000&endDateUsecs=$uEnd&startDateUsecs=$uStart&_includeTenantInfo=true"
foreach($alert in $alerts | Where-Object {$_.alertDocument.alertName -eq 'DataIngestAnomalyAlert'}){
    $strength = ($alert.propertyList | Where-Object key -eq 'anomalyStrength').value
    if($strength -ge $anomalyStrength){
        $clusterName = $alert.clusterName
        $jobName = ($alert.propertyList | Where-Object key -eq 'jobName').value
        $jobId = ($alert.propertyList | Where-Object key -eq 'jobId').value
        $object = ($alert.propertyList | Where-Object key -eq 'object').value
        $entityId = ($alert.propertyList | Where-Object key -eq 'entityId').value
        $latestTimestampUsecs = $alert.latestTimestampUsecs
        if(!$objectName -or $objectName -eq $object){
            $objectType = ($alert.propertyList | Where-Object key -eq 'environment').value
            $lastKnownGoodUsecs = ($alert.propertyList | Where-Object key -eq 'jobStartTimeUsecs').value
            $clusterId = ($alert.propertyList | Where-Object key -eq 'cid').value
            $clusterIncarnationId = ($alert.propertyList | Where-Object key -eq 'clusterIncarnationId').value
            Write-Host "$object ($(usecsToDate $latestTimestampUsecs))"
            # }
            $detailParams = @{
                "protectionGroupIds" = @(
                    "$($clusterId):$($clusterIncarnationId):$($jobId)"
                );
                "objectIds" = @(
                    [Int64]$entityId
                );
                "fromRunStartTimeUsecs" = [Int64]$lastKnownGoodUsecs;
                "tenantIds" = @();
                "toRunStartTimeUsecs" = [Int64]$latestTimestampUsecs;
                "clusterIdentifiers" = @(
                    "$($clusterId):$($clusterIncarnationId)"
                )
            }
            $details = api post -mcmv2 "data-protect/copystats/details" $detailParams
            $filesDeleted = normalize $details[0].indexingStats.deletedDocumentCount
            $filesAdded = normalize $details[0].indexingStats.newDocumentCount
            $filesChanged = normalize $details[0].indexingStats.updatedDocumentCount
            $filesUnchanged = normalize $details[0].indexingStats.notUpdatedDocumentCount
            $entropy = "{0:n2}" -f $details[0].storageMetrics.compressionRatio # [math]::Round($details[0].storageMetrics.compressionRatio, 3)
            $dataWritten = toUnits $details[0].storageMetrics.dataWrittenBytes
            $dataRead = toUnits $details[0].storageMetrics.dataReadBytes
            "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}`t{9}`t{10}`t{11}`t{12}" -f $clusterName, 
                                                                              $jobName, 
                                                                              $objectType,
                                                                              (usecsToDate $latestTimestampUsecs),
                                                                              $object,
                                                                              $strength,
                                                                              $filesDeleted,
                                                                              $filesAdded,
                                                                              $filesChanged,
                                                                              $filesUnchanged,
                                                                              $entropy,
                                                                              $dataRead,
                                                                              $dataWritten | Out-File -FilePath $outfileName -Append
        
        }   
    }
}

"`nOutput saved to $outfilename`n"
