[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][switch]$EntraId,
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][switch]$thisCalendarMonth,
    [Parameter()][switch]$lastCalendarMonth,
    [Parameter()][int]$days = 7,
    [Parameter()][int]$dayRange = 180,
    [Parameter()][array]$clusterNames,
    [Parameter(Mandatory = $True)][string]$reportName = 'Protection Runs',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][string]$outputPath = '.',
    [Parameter()][switch]$includeCCS,
    [Parameter()][switch]$excludeLogs,
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment,
    [Parameter()][switch]$replicationOnly,
    [Parameter()][int]$timeoutSeconds = 600,
    [Parameter()][switch]$dbg
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain 'local' -helios -entraIdAuthentication $EntraId

# $allClusters = heliosClusters
$allClusters = (api get -mcmv2 cluster-mgmt/info).cohesityClusters
$regions = api get -mcmv2 dms/regions
if($includeCCS){
    foreach($region in $regions.regions){
        setApiProperty -object $region -name 'clusterName' -Value $region.name
        $allClusters = @($allClusters + $region)
    }
}

# select clusters to include
$selectedClusters = $allClusters
if($clusterNames.length -gt 0){
    $selectedClusters = $allClusters | Where-Object {$_.clusterName -in $clusterNames -or $_.clusterId -in $clusterNames}
    $unknownClusters = $clusterNames | Where-Object {$_ -notin @($allClusters.clusterName) -and $_ -notin @($allClusters.clusterId)}
    if($unknownClusters){
        Write-Host "Clusters not found:`n $($unknownClusters -join ', ')" -ForegroundColor Yellow
        exit
    }
}

# date range
$today = Get-Date

if($startDate -ne '' -and $endDate -ne ''){
    $uStart = dateToUsecs $startDate
    $uEnd = dateToUsecs $endDate
}elseif ($thisCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)))
    $uEnd = dateToUsecs ($today)
}elseif ($lastCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddMonths(-1))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddSeconds(-1))
}else{
    $uStart = timeAgo $days 'days'
    $uEnd = dateToUsecs ($today)
}

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

$dayRangeUsecs = $dayRange * 86400000000

# build time ranges
$ranges = @()
$gotAllRanges = $False
$thisUend = $uEnd
$thisUstart = $uStart
while($gotAllRanges -eq $False){
    if(($thisUend - $uStart) -gt $dayRangeUsecs){
        $thisUstart = $thisUend - $dayRangeUsecs
        $ranges = @($ranges + @{'start' = $thisUstart; 'end' = $thisUend})
        $thisUend = $thisUstart - 1
    }else{
        $ranges = @($ranges + @{'start' = $uStart; 'end' = $thisUend})
        $gotAllRanges = $True
    }
}

$excludeLogsFilter = @{
    "attribute" = "backupType";
    "filterType" = "In";
    "inFilterParams" = @{
        "attributeDataType" = "String";
        "stringFilterValues" = @(
            "kRegular",
            "kFull",
            "kSystem"
        );
        "attributeLabels" = @(
            "Incremental",
            "Full",
            "System"
        )
    }
}

$environmentFilter = @{
    "attribute" = "environment";
    "filterType" = "In";
    "inFilterParams" = @{
        "attributeDataType" = "String";
        "stringFilterValues" = @(
            $environment
        );
        "attributeLabels" = @(
            $environment
        )
    }
}

$replicationFilter = @{
    "attribute" = "activityType";
    "filterType" = "In";
    "inFilterParams" = @{
        "attributeDataType" = "String";
        "stringFilterValues" = @(
            "Replication"
        );
        "attributeLabels" = @(
            "Replication"
        )
    }
}

# get list of available reports
$reports = api get -reportingV2 reports
$report = $reports.reports | Where-Object {$_.title -eq $reportName}
if(! $report){
    Write-Host "Invalid report name: $reportName" -ForegroundColor Yellow
    Write-Host "`nAvailable report names are:`n"
    Write-Host (($reports.reports.title | Sort-Object) -join "`n")
    exit
}
$reportNumber = $report.componentIds[0]
$title = $report.title

# output files
$csvFileName = $(Join-Path -Path $outputPath -ChildPath "$($title.replace('/','-').replace('\','-'))_$($start)_$($end).csv")
$tmpCsv =  $(Join-Path -Path $outputPath -ChildPath "tmpCsv")

$gotHeadings = $False
$headings = @()

Write-Host "`nRetrieving report data...`n"

$usecColumns = @()
$epochColums = @()
$sortColumn = ''
$sortDecending = $False

$date1 = Get-Date
$x = 0
foreach($cluster in $selectedClusters | Sort-Object -Property clusterName){
    $y = 0
    if($cluster.clusterName -in @($regions.regions.name)){
        $systemId = $cluster.id
    }else{
        $systemId = "$($cluster.clusterId):$($cluster.clusterIncarnationId)"
    }
    Write-Host "$($cluster.clusterName) " -NoNewline
  
    foreach($range in $ranges){
        $reportParams = @{
            "filters"  = @(
                @{
                    "attribute"             = "date";
                    "filterType"            = "TimeRange";
                    "timeRangeFilterParams" = @{
                        "lowerBound" = [int64]$range.start;
                        "upperBound" = [int64]$range.end
                    }
                }
                @{
                    "attribute" = "systemId";
                    "filterType" = "Systems";
                    "systemsFilterParams" = @{
                        "systemIds" = @("$systemId");
                        "systemNames" = @("$($cluster.clusterName)")
                    }
                }
            );
            "sort"     = $null;
            "timezone" = $timeZone;
            "limit"    = @{
                "size" = 100000;
            }
        }
        if($excludeLogs){
            $reportParams.filters = @($reportParams.filters + $excludeLogsFilter)
        }
        if($environment){
            $reportParams.filters = @($reportParams.filters + $environmentFilter)
        }
        if($replicationOnly){
            $reportParams.filters = @($reportParams.filters + $replicationFilter)
        }
        if($dbg){
            $reportParams | toJson
        }
        $dt1 = Get-Date
        $preview = api post -reportingV2 "components/$reportNumber/preview" $reportParams -TimeoutSec $timeoutSeconds
        $dt2 = Get-Date
        $seconds = [math]::Round(($dt2 - $dt1).totalSeconds)
        Write-Host " ($($preview.component.data.Count) rows - $seconds secs)" 
        if($preview.component.data.Count -eq 100000){
            Write-Host "Hit limit of records. Try reducing -dayRange (e.g. -dayRange 1)" -ForegroundColor Yellow
            exit
        }
        $attributes = $preview.component.config.xlsxParams.attributeConfig
        # sort data on first colums
        $sortColumn = $attributes[0].attributeName
        if($attributes[0].PSObject.Properties['format'] -and $attributes[0].format -eq 'timestamp'){
            $sortDecending = $True
        }

        foreach($attribute in $attributes){
            if($attribute.PSObject.Properties['format'] -and $attribute.format -eq 'timestamp'){
                $epochColums = @($epochColums + $attribute.attributeName)
            }elseif($attribute.attributeName -match 'usecs'){
                $usecColumns = @($usecColumns + $attribute.attributeName)
            }
        }
        # headings
        if(!$gotHeadings -and $x -eq 0){
            $attributes.attributeName -join ',' | Out-File -FilePath $csvFileName
        }

        if($y -eq 0){
            $preview.component.data | Export-CSV -Path $tmpCsv
            $y = 1
        }else{
            $preview.component.data | Export-CSV -Path $tmpCsv -Append
        }
    }
    $csv = Import-CSV -Path $tmpCsv
    Remove-Item -Path $tmpCsv -force
    if($csv.Count -eq 0){
        continue
    }

    foreach($column in $attributes.attributeName){
        $csv | ForEach-Object{
            if($_.$column -is [System.Array]){
                $_.$column = [string](@($_.$column | Sort-Object -Unique) -join '; ')
            }
        }
    }
    
    # exclude environments
    if($excludeEnvironment){
        $csv = $csv | Where-Object environment -notin $excludeEnvironment
    }
    
    # convert timestamps to dates
    foreach($epochColum in ($epochColums | Sort-Object -Unique)){
        $csv | Where-Object{ $_.$epochColum -ne $null -and $_.$epochColum -ne 0} | ForEach-Object{
            $_.$epochColum = usecsToDate $_.$epochColum
        }
    }
    
    # convert usecs to seconds
    foreach($usecColumn in ($usecColumns | Sort-Object -Unique)){
        $csv | ForEach-Object{
            $_.$usecColumn = [int]($_.$usecColumn / 1000000)
        }
    }
    
    # merge ranges
    if($ranges.Count -gt 1){
        # merge protected objects
        if($reportName -eq 'protected objects'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.system}, {$_.sourceName}, {$_.objectType}, {$_.objectName}, {$_.groupName}
            foreach($group in $groups){
                $records = $group.group | Sort-Object -Property lastRunTime
                $primaryRecord = $records[-1]
                $primaryRecord.numSuccessfulBackups = ($records.numSuccessfulBackups | Measure-Object -sum).sum
                $primaryRecord.numUnsuccessfulBackups = ($records.numUnsuccessfulBackups | Measure-Object -sum).sum
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
        # merge failures
        if($reportName -eq 'failures'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.system}, {$_.sourceName}, {$_.objectType}, {$_.objectName}, {$_.groupName}
            foreach($group in $groups){
                $records = $group.group | Sort-Object -Property lastFailedRunUsecs
                $primaryRecord = $records[-1]
                $primaryRecord.failedBackups = ($records.failedBackups | Measure-Object -sum).sum
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
        # merge protected / unprotected objects
        if($reportName -eq 'protected / unprotected objects'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.systems}, {$_.sourceName}, {$_.objectType}, {$_.environment}, {$_.objectName}
            foreach($group in $groups){
                $records = $group.group
                $primaryRecord = $records[0]
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
        # merge protection group summary
        if($reportName -eq 'protection group summary'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.system}, {$_.sourceEnvironment}, {$_.groupName}
            foreach($group in $groups){
                $records = $group.group | Sort-Object -Property lastRunTimeUsecs
                $primaryRecord = $records[-1]
                $primaryRecord.successfulBackups = ($records.successfulBackups | Measure-Object -sum).sum
                $primaryRecord.failedBackups = ($records.failedBackups | Measure-Object -sum).sum
                $primaryRecord.dataIngestBytes = ($records.dataIngestBytes | Measure-Object -sum).sum
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
    }
    
    if($sortDecending){
        $csv = $csv | Sort-Object -Property $sortColumn -Descending
    }else{
        $csv = $csv | Sort-Object -Property $sortColumn
    }
    if($x -eq 0){
        $csv | Export-CSV -Path $csvFileName
        $x = 1
    }else{
        $csv | Export-CSV -Path $csvFileName -Append
    }
}
$date2 = Get-Date
$reportSeconds = ($date2 - $date1).totalSeconds
Write-Host "`nTotal time: $([math]::Round($reportSeconds)) seconds"

Write-Host "`nCSV output saved to $csvFileName`n"
