[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][switch]$EntraId,
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
    [Parameter()][switch]$replicationOnly,
    [Parameter()][int]$timeoutSeconds = 600,
    [Parameter()][array]$objectUuid,
    [Parameter()][array]$objectName,
    [Parameter()][array]$filters,
    [Parameter()][string]$filterList,
    [Parameter()][string]$filterProperty,
    [Parameter()][switch]$showRecord,
    [Parameter()][switch]$ccsOnly,
    [Parameter()][int]$MaxRunspaces = 20
)

function gatherList {
    param($Param = $null, $FilePath = $null, $Required = $true, $Name = 'items')
    $items = @()
    if($Param){ $Param | ForEach-Object { $items += $_ } }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object { $items += [string]$_ }
        } else {
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow; exit
        }
    }
    if($Required -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow; exit
    }
    return ($items | Sort-Object -Unique)
}

$filterTextList = @(gatherList -FilePath $filterList -Name 'filter text list' -Required $false)

# authenticate
. (Join-Path $PSScriptRoot 'cohesity-api.ps1')
apiauth -vip $vip -username $username -domain 'local' -helios -entraIdAuthentication $EntraId
$context = getContext

$allClusters = @()
if(!$ccsOnly){
    $allClusters = (api get -mcmv2 'cluster-mgmt/info').cohesityClusters
}
$regions = api get -mcmv2 'dms/regions'
if($includeCCS -or $ccsOnly){
    foreach ($region in $regions.regions){
        setApiProperty -object $region -name 'clusterName' -Value $region.name
        $allClusters = @($allClusters + $region)
    }
}

$selectedClusters = $allClusters
if($clusterNames.Length -gt 0){
    $selectedClusters = $allClusters | Where-Object {
        $_.clusterName -in $clusterNames -or $_.clusterId -in $clusterNames
    }
    $unknownClusters = $clusterNames | Where-Object {
        $_ -notin @($allClusters.clusterName)-and $_ -notin @($allClusters.clusterId)
    }
    if($unknownClusters){
        Write-Host "Clusters not found:`n $($unknownClusters -join ', ')" -ForegroundColor Yellow; exit
    }
}

# Date ranges
$today = Get-Date
if($startDate -ne '' -and $endDate -ne ''){ $uStart = dateToUsecs $startDate; $uEnd = dateToUsecs $endDate }
elseif($thisCalendarMonth){ $uStart = dateToUsecs ($today.Date.AddDays(-($today.Day - 1))); $uEnd = dateToUsecs $today }
elseif($lastCalendarMonth){
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.Day - 1)).AddMonths(-1))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.Day - 1)).AddSeconds(-1))
} else {
    $uStart = timeAgo $days 'days'; $uEnd = dateToUsecs $today
}

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd  ).ToString('yyyy-MM-dd')
$dayRangeUsecs = $dayRange * 86400000000

$ranges = @()
$thisUend = $uEnd
$thisUstart = $uStart
while ($true){
    if(($thisUend - $uStart)-gt $dayRangeUsecs){
        $thisUstart = $thisUend - $dayRangeUsecs
        $ranges    += @{ start = $thisUstart; end = $thisUend }
        $thisUend = $thisUstart - 1
    } else {
        $ranges += @{ start = $uStart; end = $thisUend }
        break
    }
}

# pre-filters
$excludeLogsFilter = @{
    attribute = 'backupType'; filterType = 'In'
    inFilterParams = @{
        attributeDataType = 'String'
        stringFilterValues = @('kRegular','kFull','kSystem')
        attributeLabels = @('Incremental','Full','System')
    }
}

$environmentFilter = @{
    attribute = 'environment'; filterType = 'In'
    inFilterParams = @{
        attributeDataType = 'String'
        stringFilterValues = @($environment)
        attributeLabels = @($environment)
    }
}

$replicationFilter = @{
    attribute = 'activityType'; filterType = 'In'
    inFilterParams = @{
        attributeDataType = 'String'
        stringFilterValues = @('Replication')
        attributeLabels = @('Replication')
    }
}

# Object UUID
if($objectName){
    foreach ($oName in $objectName){
        $deletedSearch = api get -v2 "data-protect/search/objects?searchString=$oName&isDeleted=true"
        $search = api get -v2 "data-protect/search/objects?searchString=$oName"
        $allObjects = @(($search.objects + $deletedSearch.objects)| Where-Object { $_.name -eq $oName })
        if($allObjects.Count -eq 0){ Write-Host "Object $oName not found" -ForegroundColor Yellow; exit 1 }
        $objectUuid = @($objectUuid + $allObjects.globalId | Sort-Object -Unique)
    }
}

$objectUuidFilter = @{
    attribute = 'objectUuid'; filterType = 'In'
    inFilterParams = @{
        attributeDataType = 'String'
        stringFilterValues = @($objectUuid)
    }
}

# Report selection

$reports = api get -reportingV2 'reports'
$report = $reports.reports | Where-Object { $_.title -eq $reportName }
if(!$report){
    Write-Host "Invalid report name: $reportName" -ForegroundColor Yellow
    Write-Host "`nAvailable report names are:`n"
    Write-Host (($reports.reports.title | Sort-Object)-join "`n")
    exit
}
$reportNumber = $report.componentIds[0]
$title = $report.title

# output path
$csvFileName = Join-Path $outputPath "$($title.Replace('/','-').Replace('\','-'))_$($start)_$($end).csv"
if(!(Test-Path $outputPath)){ New-Item -ItemType Directory -Path $outputPath | Out-Null }
$fullOutputPath = (Resolve-Path $outputPath).Path
$tmpDir = Join-Path $fullOutputPath 'tmpRunspaceCSV'
if(!(Test-Path $tmpDir)){ New-Item -ItemType Directory -Path $tmpDir | Out-Null }

Write-Host "`nRetrieving report data...`n"

# Build work items  (one per cluster × range combination)
$workItems = [System.Collections.Generic.List[hashtable]]::new()
foreach ($cluster in ($selectedClusters | Sort-Object -Property clusterName)){
    $systemId = if($cluster.clusterName -in @($regions.regions.name)){
        $cluster.id
    } else {
        "$($cluster.clusterId):$($cluster.clusterIncarnationId)"
    }
    foreach ($range in $ranges){
        $workItems.Add(@{
            ClusterName = $cluster.clusterName
            SystemId = $systemId
            Range = $range
            ReportNumber = $reportNumber
            TimeZone = $timeZone
            TimeoutSec = $timeoutSeconds
            ExcludeLogs = $excludeLogs.IsPresent
            HasEnvironment = ($null -ne $environment -and $environment.Count -gt 0)
            Environment = $environmentFilter
            ReplicationOnly = $replicationOnly.IsPresent
            Replication = $replicationFilter
            HasObjectUuid = ($null -ne $objectUuid -and $objectUuid.Count -gt 0)
            ObjectUuid = $objectUuidFilter
            OutputDir = $tmpDir
            Vip = $vip
            ApiContext = $context
            PsScriptRoot2 = $PSScriptRoot
        })
    }
}

# Runspace script
$runspaceScript = {
    param([hashtable]$Item)
    Write-Host "running"
    . (Join-Path $Item.PsScriptRoot2 'cohesity-api.ps1')
    setContext $Item.ApiContext
    # Build report params
    $reportParams = @{
        filters = @(
            @{
                attribute = 'date'
                filterType = 'TimeRange'
                timeRangeFilterParams = @{
                    lowerBound = [int64]$Item.Range.start
                    upperBound = [int64]$Item.Range.end
                }
            },
            @{
                attribute = 'systemId'
                filterType = 'Systems'
                systemsFilterParams = @{
                    systemIds = @("$($Item.SystemId)")
                    systemNames = @("$($Item.ClusterName)")
                }
            }
        )
        sort = $null
        timezone = $Item.TimeZone
        limit = @{ size = 100000 }
    }

    if($Item.ExcludeLogs){ $reportParams.filters += $Item.Environment }
    if($Item.ExcludeLogs){ $reportParams.filters = @($reportParams.filters | Where-Object { $_ -ne $Item.Environment }); $reportParams.filters += @{ attribute='backupType';filterType='In';inFilterParams=@{attributeDataType='String';stringFilterValues=@('kRegular','kFull','kSystem');attributeLabels=@('Incremental','Full','System')}} }
    if($Item.HasEnvironment){ $reportParams.filters += $Item.Environment }
    if($Item.ReplicationOnly){ $reportParams.filters += $Item.Replication }
    if($Item.HasObjectUuid){ $reportParams.filters += $Item.ObjectUuid }

    $dt1 = Get-Date
    try {
        $preview = api post -reportingV2 "components/$($Item.ReportNumber)/preview" $reportParams -TimeoutSec $Item.TimeoutSec
        $safeCluster = $Item.ClusterName -replace '[\\/:*?"<>|]', '_'
        $tmpFile = Join-Path $Item.OutputDir "$safeCluster`_$($Item.Range.start).csv"
        $preview.component.data | Export-Csv -Path $tmpFile -NoTypeInformation
    } catch {
        Write-Host "Error"
        return @{
            ClusterName = $Item.ClusterName
            RangeStart = $Item.Range.start
            Error = $_.Exception.Message
            Rows = 0
            Seconds = 0
            Preview = $null
        }
    }
    $seconds = [math]::Round(((Get-Date)- $dt1).TotalSeconds)

    return @{
        ClusterName = $Item.ClusterName
        RangeStart = $Item.Range.start
        Error = $null
        Rows = @($preview.component.data).Count
        Seconds = $seconds
        TmpFile = $tmpFile
        Attributes = $preview.component.config.xlsxParams.attributeConfig
        Preview = $null
    }
}

# Runspace pool
$pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $MaxRunspaces)
$pool.Open()
$jobs = [System.Collections.Generic.List[hashtable]]::new()
$date1 = Get-Date

foreach ($item in $workItems){
    $ps = [PowerShell]::Create().AddScript($runspaceScript).AddParameter('Item', $item)
    $ps.RunspacePool = $pool
    $jobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke()})
}

# Collect results as they complete
$results = [System.Collections.Generic.List[hashtable]]::new()
foreach ($job in $jobs){
    $result = $job.PS.EndInvoke($job.Handle)
    $job.PS.Dispose()
    if($result){
        $r = $result[0]
        if($r.Error){
            Write-Host "$($r.ClusterName): ERROR - $($r.Error)" -ForegroundColor Red
        } else {
            Write-Host "$($r.ClusterName)  ($($r.Rows) rows - $($r.Seconds) secs)"
        }
        $results.Add($r)
    }
}

$pool.Close()
$pool.Dispose()

# Collect column metadata from any successful result
$attributes = ($results | Where-Object { $_.Attributes } | Select-Object -First 1).Attributes
$sortColumn = ''
$sortDesc = $false
$epochCols = @()
$usecCols = @()

if($attributes){
    $sortColumn = $attributes[0].attributeName
    if($attributes[0].PSObject.Properties['format'] -and $attributes[0].format -eq 'timestamp'){
        $sortDesc = $true
    }
    foreach ($attr in $attributes){
        if($attr.PSObject.Properties['format'] -and $attr.format -eq 'timestamp'){
            $epochCols += $attr.attributeName
        } elseif($attr.attributeName -match 'usecs'){
            $usecCols  += $attr.attributeName
        }
    }
}

# Write CSV header
if($attributes){
    $attributes.attributeName -join ',' | Out-File -FilePath $csvFileName
}

# Group results by cluster so we can merge ranges per cluster (original logic)
$byCluster = $results | Where-Object { !$_.Error -and $_.Rows -gt 0 } | Group-Object -Property ClusterName

$firstCluster = $true
foreach ($clusterGroup in $byCluster){
    # Merge all range temp files for this cluster
    $allRows = [System.Collections.Generic.List[object]]::new()
    foreach ($r in $clusterGroup.Group){
        if($r.TmpFile -and (Test-Path $r.TmpFile)){
            Import-Csv -Path $r.TmpFile | ForEach-Object { $allRows.Add($_)}
            Remove-Item -Path $r.TmpFile -Force
        }
    }
    if($allRows.Count -eq 0){ continue }

    $csv = $allRows.ToArray()

    # Flatten array-valued columns
    foreach ($col in $attributes.attributeName){
        $csv | ForEach-Object {
            if($_.$col -is [System.Array]){
                $_.$col = [string](@($_.$col | Sort-Object -Unique)-join '; ')
            }
        }
    }

    if($showRecord){ $csv[0] | ConvertTo-Json -Depth 99; exit }

    # post-filters
    if($filters){
        foreach ($filter in $filters){
            if($filter -match '<='){ $op = '<='; $fattrib,$fvalue = $filter -split '<=' }
            elseif($filter -match '>='){ $op = '>='; $fattrib,$fvalue = $filter -split '>=' }
            elseif($filter -match '!='){ $op = '!='; $fattrib,$fvalue = $filter -split '!=' }
            elseif($filter -match '=='){ $op = '=='; $fattrib,$fvalue = $filter -split '==' }
            elseif($filter -match '>'){ $op = '>';  $fattrib,$fvalue = $filter -split '>'  }
            elseif($filter -match '<'){ $op = '<';  $fattrib,$fvalue = $filter -split '<'  }
            else    { Write-Host "`nInvalid filter format: $filter`n" -ForegroundColor Yellow; exit }

            $fattrib = $fattrib.Trim(); $fvalue = $fvalue.Trim()
            if($csv -and !$csv[0].PSObject.Properties[$fattrib]){
                Write-Host "`nInvalid filter attribute: $fattrib`n" -ForegroundColor Yellow; exit
            }
            $csv = switch ($op){
                '<='  { $csv | Where-Object { [double]$_.$fattrib -le [double]$fvalue } }
                '>='  { $csv | Where-Object { [double]$_.$fattrib -ge [double]$fvalue } }
                '!='  { $csv | Where-Object { $_.$fattrib -ne $fvalue } }
                '=='  { $csv | Where-Object { $_.$fattrib -eq $fvalue } }
                '>'   { $csv | Where-Object { [double]$_.$fattrib -gt [double]$fvalue } }
                '<'   { $csv | Where-Object { [double]$_.$fattrib -lt [double]$fvalue } }
            }
        }
    }

    if($filterList -and $filterProperty){
        if($csv -and !$csv[0].PSObject.Properties[$filterProperty]){
            Write-Host "`nInvalid filter attribute: $filterProperty`n" -ForegroundColor Yellow; exit
        }
        $csv = $csv | Where-Object { $_.$filterProperty -in $filterTextList }
    }

    if($excludeEnvironment){
        $csv = $csv | Where-Object environment -notin $excludeEnvironment
    }

    # Convert epoch timestamps
    foreach ($col in ($epochCols | Sort-Object -Unique)){
        $csv | Where-Object { $_.$col -ne $null -and $_.$col -ne 0 } | ForEach-Object {
            $_.$col = usecsToDate $_.$col
        }
    }

    # Convert usecs to seconds
    foreach ($col in ($usecCols | Sort-Object -Unique)){
        $csv | ForEach-Object { $_.$col = [int]($_.$col / 1000000)}
    }

    # Merge date ranges for aggregate reports (logic identical to original)
    if($ranges.Count -gt 1){
        if($reportName -eq 'protected objects'){
            $newCSV = @()
            $csv | Group-Object { $_.system },{ $_.sourceName },{ $_.objectType },{ $_.objectName },{ $_.groupName } | ForEach-Object {
                $recs = $_.Group | Sort-Object lastRunTime
                $prim = $recs[-1]
                $prim.numSuccessfulBackups = ($recs.numSuccessfulBackups | Measure-Object -Sum).Sum
                $prim.numUnsuccessfulBackups = ($recs.numUnsuccessfulBackups | Measure-Object -Sum).Sum
                $newCSV += $prim
            }
            $csv = $newCSV
        }
        if($reportName -eq 'failures'){
            $newCSV = @()
            $csv | Group-Object { $_.system },{ $_.sourceName },{ $_.objectType },{ $_.objectName },{ $_.groupName } | ForEach-Object {
                $recs = $_.Group | Sort-Object lastFailedRunUsecs
                $prim = $recs[-1]
                $prim.failedBackups = ($recs.failedBackups | Measure-Object -Sum).Sum
                $newCSV += $prim
            }
            $csv = $newCSV
        }
        if($reportName -eq 'protected / unprotected objects'){
            $newCSV = @()
            $csv | Group-Object { $_.systems },{ $_.sourceName },{ $_.objectType },{ $_.environment },{ $_.objectName } | ForEach-Object {
                $newCSV += $_.Group[0]
            }
            $csv = $newCSV
        }
        if($reportName -eq 'protection group summary'){
            $newCSV = @()
            $csv | Group-Object { $_.system },{ $_.sourceEnvironment },{ $_.groupName } | ForEach-Object {
                $recs = $_.Group | Sort-Object lastRunTimeUsecs
                $prim = $recs[-1]
                $prim.successfulBackups = ($recs.successfulBackups | Measure-Object -Sum).Sum
                $prim.failedBackups = ($recs.failedBackups | Measure-Object -Sum).Sum
                $prim.dataIngestBytes = ($recs.dataIngestBytes | Measure-Object -Sum).Sum
                $newCSV += $prim
            }
            $csv = $newCSV
        }
    }

    # Sort
    $csv = if($sortDesc){ 
        $csv | Sort-Object -Property $sortColumn -Descending
    }else{ 
        $csv | Sort-Object -Property $sortColumn
    }

    # Append to master CSV
    if($firstCluster){
        $csv | Export-Csv -Path $csvFileName -NoTypeInformation
        $firstCluster = $false
    } else {
        $csv | Export-Csv -Path $csvFileName -Append -NoTypeInformation
    }
}

# Cleanup temp dir
if(Test-Path $tmpDir){ Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }

$reportSeconds = ((Get-Date)- $date1).TotalSeconds
Write-Host "`nTotal time: $([math]::Round($reportSeconds)) seconds"
Write-Host "`nCSV output saved to $csvFileName`n"
