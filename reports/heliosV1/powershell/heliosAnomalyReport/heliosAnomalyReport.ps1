[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][int]$days = 7,
    [Parameter()][string]$objectName,
    [Parameter()][int]$anomalyStrength = 10
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
"""Cluster Name"",""Job Name"",""Job Type"",""Run Date"",""Object Name"",""File Name"",""Action""" | Out-File -FilePath $outfileName

$alerts = api get -mcm "alerts?alertCategoryList=kSecurity&alertStateList=kOpen&endDateUsecs=$uEnd&maxAlerts=1000&startDateUsecs=$uStart&_includeTenantInfo=true"

foreach($alert in $alerts | Where-Object {$_.alertDocument.alertName -eq 'DataIngestAnomalyAlert'}){
    $strength = ($alert.propertyList | Where-Object key -eq 'anomalyStrength').value
    $strength
    if($strength -ge $anomalyStrength){
        $clusterName = $alert.clusterName
        $jobName = ($alert.propertyList | Where-Object key -eq 'jobName').value
        $jobId = ($alert.propertyList | Where-Object key -eq 'jobId').value
        $object = ($alert.propertyList | Where-Object key -eq 'object').value
        if(!$objectName -or $objectName -eq $object){
            $objectType = ($alert.propertyList | Where-Object key -eq 'environment').value
            $jobStartTimeUsecs = ($alert.propertyList | Where-Object key -eq 'jobStartTimeUsecs').value
            Write-Host "$object ($(usecsToDate $jobStartTimeUsecs))"
            $snapshot2 = $alert.id.split(':')[1]
            $conn = heliosCluster $clusterName
            $changeLog = api get  "snapshots/changelog?jobId=$jobId&snapshot1TimeUsecs=$jobStartTimeUsecs&snapshot2TimeUsecs=$snapshot2&pageCount=50&pageNumber=0" -quiet
            foreach($result in $changeLog.results){
                $filename = $result.filename
                $operation = $result.operation
                Write-Host "    $filename"
                """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}""" -f $clusterName, $jobName, $objectType, $object, $filename, $operation.substring(1) | Out-File -FilePath $outfileName -Append
            }
        }    
    }
}
