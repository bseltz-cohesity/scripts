[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][switch]$thisCalendarMonth,
    [Parameter()][switch]$lastCalendarMonth,
    [Parameter()][int]$days = 7,
    [Parameter()][int]$dayRange = 180,
    [Parameter()][array]$clusterNames,
    [Parameter()][string]$reportName = 'Protection Runs',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][string]$outputPath = '.',
    [Parameter()][switch]$includeCCS,
    [Parameter()][switch]$excludeLogs,
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment,
    [Parameter()][switch]$replicationOnly
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
apiauth -vip $vip -username $username -domain 'local' -helios

$allClusters = heliosClusters
$regions = api get -mcmv2 dms/regions
if($includeCCS){
    foreach($region in $regions.regions){
        $allClusters = @($allClusters + $region)
    }
}

# select clusters to include
$selectedClusters = $allClusters
if($clusterNames.length -gt 0){
    $selectedClusters = $allClusters | Where-Object {$_.name -in $clusterNames -or $_.id -in $clusterNames}
    $unknownClusters = $clusterNames | Where-Object {$_ -notin @($allClusters.name) -and $_ -notin @($allClusters.id)}
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

$gotHeadings = $False
$headings = @()

Write-Host "`nRetrieving report data...`n"

$usecColumns = @()
$epochColums = @()
$sortColumn = ''
$sortDecending = $False

$data = @()

foreach($cluster in ($selectedClusters)){
    if($cluster.name -in @($regions.regions.name)){
        $systemId = $cluster.id
    }else{
        $systemId = "$($cluster.clusterId):$($cluster.clusterIncarnationId)"
    }
    Write-Host "$($cluster.name) " -NoNewline
  
    foreach($range in $ranges){
        $csvlines = @()
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
                        "systemNames" = @("$($cluster.name)")
                    }
                }
            );
            "sort"     = $null;
            "timezone" = $timeZone;
            "limit"    = @{
                "size" = 50000;
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
        $preview = api post -reportingV2 "components/$reportNumber/preview" $reportParams
        Write-Host "($($preview.component.data.Count) rows)" 
        if($preview.component.data.Count -eq 50000){
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
        if(!$gotHeadings){
            $attributes.attributeName -join ',' | Out-File -FilePath $csvFileName
        }
        $data = @($data + $preview.component.data) # | Export-CSV -Append -Path $csvFileName
    }
}

$data | Export-CSV -Append -Path $csvFileName

$csv = Import-CSV -Path $csvFileName

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

if($sortDecending){
    $csv = $csv | Sort-Object -Property $sortColumn -Descending
}else{
    $csv = $csv | Sort-Object -Property $sortColumn
}

$csv | Export-CSV -Path $csvFileName

Write-Host "`nCSV output saved to $csvFileName`n"
