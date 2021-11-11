[CmdletBinding()]
param (
    [Parameter()][string]$username='helios',
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][switch]$thisCalendarMonth,
    [Parameter()][switch]$lastCalendarMonth,
    [Parameter()][int]$days = 0,
    [Parameter()][ValidateSet('MiB','GiB','TiB')][string]$unit = 'MiB'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip 'helios.cohesity.com' -username $username -domain 'local'

$conversion = @{'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

### determine start and end dates
$today = Get-Date

if($startDate -ne '' -and $endDate -ne ''){
    $uStart = dateToUsecs $startDate
    $uEnd = dateToUsecs $endDate
}elseif ($days -ne 0) {
    $uStart = dateToUsecs ($today.Date.AddDays(-$days))
    $uEnd = dateToUsecs $today.Date.AddSeconds(-1)
}elseif ($thisCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddMonths(1).AddSeconds(-1))    
}elseif ($lastCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddMonths(-1))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddSeconds(-1))
}else{
    $uStart = dateToUsecs ($today.Date.AddDays(-31))
    $uEnd = dateToUsecs $today.Date.AddSeconds(-1)
}

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "heliosStoragePerObjectReport_$start_$end.csv"

"Cluster Name,Source Name,Object Name,Environment,Snapshots,Logical $unit,$unit Read,$unit Written,$unit Daily Change,Tags" | Out-File -FilePath $outfileName

$reports = api get -reportingV2 reports?userContext=MCM
$report = $reports.reports | Where-Object id -eq 'storage-consumption-object'

$reportParams = @{
    "filters"  = @(
        @{
            "attribute"             = "date";
            "filterType"            = "TimeRange";
            "timeRangeFilterParams" = @{
                "lowerBound" = $uStart;
                "upperBound" = $uEnd
            }
        }
    );
    "sort"     = $null;
    "timezone" = "America/New_York";
    "limit"    = @{
        "size" = 10000
    }
}

$preview = api post -reportingV2 components/300/preview $reportParams

$clusters = $preview.component.data.system | Sort-Object -Unique

foreach($cluster in $clusters){
    heliosCluster $cluster
    $vms = api get protectionSources/virtualMachines
    foreach($object in $preview.component.data | Where-Object system -eq $cluster | Sort-Object -Property objectName){
        $clusterName = $object.system
        $sourceName = $object.sourceName
        $objectName = $object.objectName
        $objectType = $object.environment
        $uuid = $object.objectUuid
        if($objectType -eq 'kVMware'){
            $vm = $vms | Where-Object {$_.vmWareProtectionSource.id.uuid -eq $uuid.split('_')[1]}
            $tags = $vm.vmWareProtectionSource.tagAttributes.name -join ';'

        }
        $logicalSize = toUnits $object.maxSourceLogicalSizeBytes
        $dataRead = toUnits $object.sumSourceDeltaSizeBytes
        $dataWritten = toUnits $object.sumDataWrittenSizeBytes
        $changeRate = toUnits $object.dailyChangeRate
        $snapshots = $object.snapshots
        if($snapshots -gt 0){
            """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}""" -f $clusterName, $sourceName, $objectName, $objectType.subString(1), $snapshots, $logicalSize, $dataRead, $dataWritten, $changeRate, $tags | Tee-Object -FilePath $outfileName -Append
        }
    }
}
