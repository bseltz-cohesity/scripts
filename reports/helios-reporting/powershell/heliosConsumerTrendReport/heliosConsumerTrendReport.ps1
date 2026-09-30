# . . . . . . . . . . . . . . . . . . .
#  heliosConsumerTrendReport.ps1
#  Builds a monthly storage-consumption trend report from Helios for:
#    - Storage Consumption by Views
#    - Storage Consumption by Protection Groups
#  and pivots the results into a single CSV with one row per
#  view / protection group and monthly columns for
#  dataIngestedRetainedBytes and scRetainedBytes, plus scRetainedBytes
#  growth columns.
#
#  Authenticates once, then pulls every cluster x month x report
#  combination through a single shared runspace pool (reusing the same
#  Helios session) instead of shelling out per report/month.
# . . . . . . . . . . . . . . . . . . .

[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$EntraId,
    [Parameter()][string]$startDate,                # first day of the first month, e.g. '2025-10-01'. Defaults to numMonths back from last completed month
    [Parameter()][int]$numMonths = 12,
    [Parameter()][array]$clusterNames,
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][string]$outputPath = '.',
    [Parameter()][int]$timeoutSeconds = 600,
    [Parameter()][int]$MaxRunspaces = 20,
    [Parameter()][int]$retryCount = 2,               # extra retry passes for any cluster/month/report call that errors out
    [Parameter()][switch]$exportRawData,             # also write the raw (un-pivoted, un-converted) monthly rows for each report
    [Parameter()][ValidateSet('MiB','GiB')][string]$units = 'MiB',
    [Parameter()][switch]$progress,                  # print a line for each cluster/month/report call as it completes
    [Parameter()][switch]$htmlReport                 # also write an HTML report with a scRetained-over-time chart per entity
)

# byte -> unit conversion for the pivoted output (raw data export, if requested, stays in bytes)
$unitDivisor = if($units -eq 'GiB'){ 1024 * 1024 * 1024 } else { 1024 * 1024 }
function toUnits($bytes){
    if($null -eq $bytes){ return 0 }
    return [math]::Round([double]$bytes / $unitDivisor, 2)
}

# . . . . . . . . . . . . . . . . . . .
# authenticate (once)
# . . . . . . . . . . . . . . . . . . .
. (Join-Path $PSScriptRoot 'cohesity-api.ps1')
apiauth -vip $vip -username $username -domain 'local' -helios -entraIdAuthentication $EntraId -tenant $tenant
if(!$cohesity_api.authorized){
    Write-Host "`nAuthentication failed - aborting" -ForegroundColor Yellow
    exit
}
$context = getContext

# . . . . . . . . . . . . . . . . . . .
# clusters (CCS regions are excluded - CCS has neither views nor protection groups)
# . . . . . . . . . . . . . . . . . . .
$allClusters = api get -mcm clusters/connectionStatus

$selectedClusters = $allClusters
if($clusterNames.Length -gt 0){
    $selectedClusters = $allClusters | Where-Object {
        $_.name -in $clusterNames -or $_.clusterId -in $clusterNames
    }
    $unknownClusters = $clusterNames | Where-Object {
        $_ -notin @($allClusters.name) -and $_ -notin @($allClusters.clusterId)
    }
    if($unknownClusters){
        Write-Host "Clusters not found:`n $($unknownClusters -join ', ')" -ForegroundColor Yellow; exit
    }
}
if(@($selectedClusters).Count -eq 0){
    Write-Host "No clusters found" -ForegroundColor Yellow; exit
}

# . . . . . . . . . . . . . . . . . . .
# report definitions - resolve each report's component id once
# . . . . . . . . . . . . . . . . . . .
$reportConfigs = @(
    @{ Name = 'Storage Consumption by Views';             Category = 'View';              IdField = 'viewId';  NameField = 'viewName';  SystemField = 'systemName' },
    @{ Name = 'Storage Consumption by Protection Groups';  Category = 'Protection Group';  IdField = 'groupId'; NameField = 'groupName'; SystemField = 'system' }
)

$reports = api get -reportingV2 'reports'
foreach($config in $reportConfigs){
    $report = $reports.reports | Where-Object { $_.title -eq $config.Name }
    if(!$report){
        Write-Host "Invalid report name: $($config.Name)" -ForegroundColor Yellow
        Write-Host "`nAvailable report names are:`n"
        Write-Host (($reports.reports.title | Sort-Object) -join "`n")
        exit
    }
    $config.ReportNumber = $report.componentIds[0]
}
$configByCategory = @{}
foreach($config in $reportConfigs){ $configByCategory[$config.Category] = $config }

# output path
if(!(Test-Path $outputPath)){ New-Item -ItemType Directory -Path $outputPath | Out-Null }
$fullOutputPath = (Resolve-Path $outputPath).Path

# . . . . . . . . . . . . . . . . . . .
# build the list of monthly date ranges
# . . . . . . . . . . . . . . . . . . .
if($startDate){
    $parsedStart = [datetime]$startDate
    $baseMonth = Get-Date -Year $parsedStart.Year -Month $parsedStart.Month -Day 1
} else {
    $today = Get-Date
    $lastCompleteMonth = (Get-Date -Year $today.Year -Month $today.Month -Day 1).AddDays(-1)  # last day of previous month
    $lastCompleteMonthStart = Get-Date -Year $lastCompleteMonth.Year -Month $lastCompleteMonth.Month -Day 1
    $baseMonth = $lastCompleteMonthStart.AddMonths(-($numMonths - 1))
}

$monthRanges = @()
for($i = 0; $i -lt $numMonths; $i++){
    $monthStart = $baseMonth.AddMonths($i)
    $monthEnd = $monthStart.AddMonths(1).AddDays(-1)
    $startStr = $monthStart.ToString('yyyy-MM-dd')
    $endStr = $monthEnd.ToString('yyyy-MM-dd')
    $monthRanges += [ordered]@{
        Label      = $monthStart.ToString('yyyy-MM')
        Start      = $startStr
        End        = $endStr
        StartUsecs = dateToUsecs $startStr
        EndUsecs   = dateToUsecs $endStr
    }
}

Write-Host "`nMonths to retrieve:`n$(($monthRanges | ForEach-Object { "  $($_.Label)  ($($_.Start) to $($_.End))" }) -join "`n")`n"

# . . . . . . . . . . . . . . . . . . .
# helper: build a fresh row (ordered) for a view/protection group, with all
# monthly columns pre-initialized to 0 so entities missing from a given
# month's report still show up with a value
# . . . . . . . . . . . . . . . . . . .
function newEntityRow($category, $system, $name, $id){
    $row = [ordered]@{
        Category = $category
        System   = $system
        Name     = $name
        Id       = $id
    }
    foreach($m in $monthRanges){
        $row["$($m.Label) dataIngestedRetained ($units)"] = 0
        $row["$($m.Label) scRetained ($units)"] = 0
    }
    return $row
}

$entities = [System.Collections.Generic.Dictionary[string,System.Collections.Specialized.OrderedDictionary]]::new()
$rawRows = @{}
foreach($config in $reportConfigs){ $rawRows[$config.Category] = [System.Collections.Generic.List[object]]::new() }

# . . . . . . . . . . . . . . . . . . .
# build work items: one per cluster x month x report
# . . . . . . . . . . . . . . . . . . .
$workItems = [System.Collections.Generic.List[hashtable]]::new()
foreach ($cluster in ($selectedClusters | Sort-Object -Property name)){
    $systemId = "$($cluster.clusterId):$($cluster.clusterIncarnationId)"
    foreach($range in $monthRanges){
        foreach($config in $reportConfigs){
            $workItems.Add(@{
                ClusterName  = $cluster.name
                SystemId     = $systemId
                Range        = $range
                Config       = $config
                TimeZone     = $timeZone
                TimeoutSec   = $timeoutSeconds
                ApiContext   = $context
                PsScriptRoot2 = $PSScriptRoot
            })
        }
    }
}

Write-Host "Retrieving $($workItems.Count) cluster/month/report combinations across $(@($selectedClusters).Count) cluster(s)...`n"

# . . . . . . . . . . . . . . . . . . .
# runspace script - runs one cluster/month/report combo, reusing the
# already-authenticated context (no re-login per call)
# . . . . . . . . . . . . . . . . . . .
$runspaceScript = {
    param([hashtable]$Item)
    . (Join-Path $Item.PsScriptRoot2 'cohesity-api.ps1')
    setContext $Item.ApiContext

    $reportParams = @{
        filters = @(
            @{
                attribute = 'date'
                filterType = 'TimeRange'
                timeRangeFilterParams = @{
                    lowerBound = [int64]($Item.Range.StartUsecs)
                    upperBound = [int64]($Item.Range.EndUsecs)
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

    try {
        $preview = api post -reportingV2 "components/$($Item.Config.ReportNumber)/preview" $reportParams -timeout $Item.TimeoutSec -quiet
        if($null -eq $preview -or $null -eq $preview.component){
            # api() retries internally and can still come back empty (exhausted retries, non-retryable
            # error, auth hiccup, etc.) without throwing - treat that the same as a real error so it
            # gets retried/reported instead of silently being counted as "0 rows"
            throw "No response from report API (possible auth/timeout failure)"
        }
        $dataRows = @($preview.component.data | Where-Object { $null -ne $_ })
        return @{
            ClusterName = $Item.ClusterName
            MonthLabel  = $Item.Range.Label
            Category    = $Item.Config.Category
            Error       = $null
            Data        = $dataRows
            Item        = $Item
        }
    } catch {
        return @{
            ClusterName = $Item.ClusterName
            MonthLabel  = $Item.Range.Label
            Category    = $Item.Config.Category
            Error       = $_.Exception.Message
            Data        = @()
            Item        = $Item
        }
    }
}

function runWorkItems($items){
    $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $MaxRunspaces)
    $pool.Open()
    $jobs = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($item in $items){
        $ps = [PowerShell]::Create().AddScript($runspaceScript).AddParameter('Item', $item)
        $ps.RunspacePool = $pool
        $jobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke(); Done = $false })
    }

    # report progress as each call finishes (they run concurrently, so this reflects actual
    # completion order, not submission order) rather than going silent until everything is done
    $results = [System.Collections.Generic.List[hashtable]]::new()
    $total = $jobs.Count
    $completed = 0
    while($completed -lt $total){
        foreach($job in $jobs){
            if(!$job.Done -and $job.Handle.IsCompleted){
                $job.Done = $true
                $completed += 1
                $result = $job.PS.EndInvoke($job.Handle)
                $job.PS.Dispose()
                if($result){
                    $r = $result[0]
                    $results.Add($r)
                    if($progress){
                        if($r.Error){
                            Write-Host "  [$completed/$total] $($r.Category) - $($r.MonthLabel) - $($r.ClusterName) : ERROR - $($r.Error)" -ForegroundColor Red
                        } else {
                            Write-Host "  [$completed/$total] $($r.Category) - $($r.MonthLabel) - $($r.ClusterName) : $(@($r.Data).Count) row(s)"
                        }
                    }
                } elseif($progress) {
                    Write-Host "  [$completed/$total] (no result returned)" -ForegroundColor Yellow
                }
            }
        }
        if($completed -lt $total){ Start-Sleep -Milliseconds 200 }
    }

    $pool.Close()
    $pool.Dispose()
    return $results
}

$date1 = Get-Date
$results = runWorkItems $workItems

# . . . . . . . . . . . . . . . . . . .
# retry any cluster/month/report combos that errored out
# . . . . . . . . . . . . . . . . . . .
$attempt = 0
while($attempt -lt $retryCount){
    $failedResults = @($results | Where-Object { $_.Error })
    if($failedResults.Count -eq 0){ break }
    $attempt += 1
    Write-Host "Retry pass $attempt/$retryCount for $($failedResults.Count) failed call(s)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    $retryItems = @($failedResults | ForEach-Object { $_.Item })
    $retryResults = runWorkItems $retryItems

    $retryLookup = @{}
    foreach($rr in $retryResults){ $retryLookup["$($rr.ClusterName)|$($rr.MonthLabel)|$($rr.Category)"] = $rr }

    for($i = 0; $i -lt $results.Count; $i++){
        $k = "$($results[$i].ClusterName)|$($results[$i].MonthLabel)|$($results[$i].Category)"
        if($retryLookup.ContainsKey($k)){ $results[$i] = $retryLookup[$k] }
    }
}

$stillFailed = @($results | Where-Object { $_.Error })
foreach($f in $stillFailed){
    Write-Host "  FAILED: $($f.ClusterName) / $($f.Category) / $($f.MonthLabel) : $($f.Error)" -ForegroundColor Red
}

# . . . . . . . . . . . . . . . . . . .
# aggregate the successful results
# . . . . . . . . . . . . . . . . . . .
$goodResults = @($results | Where-Object { !$_.Error })
$totalRows = 0
foreach($r in $goodResults){
    $config = $configByCategory[$r.Category]
    foreach($row in $r.Data){
        $id = $row.($config.IdField)
        if([string]::IsNullOrEmpty("$id")){ continue }
        $name = $row.($config.NameField)
        $system = $row.($config.SystemField)
        $category = $config.Category

        $key = "$category|$id"
        if(!$entities.ContainsKey($key)){
            $entities[$key] = newEntityRow $category $system $name $id
        }
        $entityRow = $entities[$key]
        $entityRow.System = $system
        $entityRow.Name = $name

        $ingested = toUnits $row.dataIngestedRetainedBytes
        $retained = toUnits $row.scRetainedBytes

        $entityRow["$($r.MonthLabel) dataIngestedRetained ($units)"] = $ingested
        $entityRow["$($r.MonthLabel) scRetained ($units)"] = $retained

        $totalRows += 1

        if($exportRawData){
            $rawRow = $row | Select-Object *
            $rawRow | Add-Member -NotePropertyName 'Month' -NotePropertyValue $r.MonthLabel -Force
            $rawRow | Add-Member -NotePropertyName 'Cluster' -NotePropertyValue $r.ClusterName -Force
            $rawRows[$category].Add($rawRow)
        }
    }
}

# . . . . . . . . . . . . . . . . . . .
# write the aggregated trend report
# . . . . . . . . . . . . . . . . . . .
$firstLabel = $monthRanges[0].Label
$lastLabel = $monthRanges[-1].Label
$outCsvName = "Storage Consumption Trend_$($firstLabel)_$($lastLabel)_$($units).csv"
$outCsvPath = Join-Path $fullOutputPath $outCsvName

$firstScKey = "$firstLabel scRetained ($units)"
$lastScKey = "$lastLabel scRetained ($units)"
$monthSpan = $monthRanges.Count - 1   # number of month-over-month intervals across the full range

$finalRows = $entities.Values | ForEach-Object {
    $totalGrowth = [math]::Round([double]($_[$lastScKey]) - [double]($_[$firstScKey]), 2)
    $avgMonthlyGrowth = if($monthSpan -gt 0){ [math]::Round($totalGrowth / $monthSpan, 2) } else { 0 }

    $obj = [PSCustomObject]$_
    $obj | Add-Member -NotePropertyName "Average Monthly Growth (scRetained $units)" -NotePropertyValue $avgMonthlyGrowth
    $obj | Add-Member -NotePropertyName "Total Growth (scRetained $units) $firstLabel to $lastLabel" -NotePropertyValue $totalGrowth
    $obj
} | Sort-Object Category, System, Name

if($finalRows.Count -eq 0){
    Write-Host "`nNo data was retrieved - no report written" -ForegroundColor Yellow
} else {
    $finalRows | Export-Csv -Path $outCsvPath -NoTypeInformation
    Write-Host "`n$($finalRows.Count) entities (views + protection groups), $totalRows monthly data points, written to:`n$outCsvPath"
}

if($htmlReport -and $finalRows.Count -gt 0){
    $monthLabels = @($monthRanges | ForEach-Object { $_.Label })

    $chartData = @(foreach($row in $finalRows){
        $values = @(foreach($m in $monthRanges){
            $propName = "$($m.Label) scRetained ($units)"
            $row.($propName)
        })
        [ordered]@{
            category = $row.Category
            system   = $row.System
            name     = $row.Name
            id       = $row.Id
            values   = $values
        }
    })

    $chartPayload = [ordered]@{
        units      = $units
        months     = $monthLabels
        generated  = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        firstLabel = $firstLabel
        lastLabel  = $lastLabel
        entities   = $chartData
    }
    $chartJson = ConvertTo-Json -InputObject $chartPayload -Depth 8 -Compress
    $chartJson = $chartJson.Replace('</script', '<\/script')

    $htmlTemplate = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>__TITLE__</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.0/chart.umd.min.js"></script>
<style>
  :root{
    --bg:#f5f6f8; --card:#ffffff; --text:#1f2430; --muted:#6b7280;
    --border:#e3e5ea; --accent:#2563eb; --accent-fill:rgba(37,99,235,0.10);
    --badge-view-bg:#e0edff; --badge-view-fg:#1d4ed8;
    --badge-group-bg:#e7f5ec; --badge-group-fg:#15803d;
  }
  *{ box-sizing:border-box; }
  body{
    margin:0; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
    background:var(--bg); color:var(--text);
  }
  header{
    padding:20px 24px 16px; background:var(--card); border-bottom:1px solid var(--border);
    position:sticky; top:0; z-index:5;
  }
  h1{ margin:0 0 4px; font-size:20px; }
  .subtitle{ color:var(--muted); font-size:13px; margin-bottom:14px; }
  .controls{ display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
  .controls input, .controls select{
    padding:8px 10px; border:1px solid var(--border); border-radius:6px; font-size:13px;
    background:var(--card); color:var(--text);
  }
  .controls input{ flex:1; min-width:200px; }
  #count{ color:var(--muted); font-size:13px; margin-left:auto; white-space:nowrap; }
  main{ padding:20px 24px 40px; }
  #grid{
    display:grid; grid-template-columns:repeat(auto-fill, minmax(320px, 1fr)); gap:16px;
  }
  .card{
    background:var(--card); border:1px solid var(--border); border-radius:10px;
    padding:14px; display:flex; flex-direction:column;
  }
  .card-header{ display:flex; justify-content:space-between; align-items:flex-start; gap:8px; margin-bottom:2px; }
  .name{ font-weight:600; font-size:13.5px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .badge{ font-size:11px; font-weight:600; padding:2px 8px; border-radius:999px; white-space:nowrap; }
  .badge-view{ background:var(--badge-view-bg); color:var(--badge-view-fg); }
  .badge-group{ background:var(--badge-group-bg); color:var(--badge-group-fg); }
  .system{ color:var(--muted); font-size:12px; margin-bottom:8px; }
  .chart-wrap{ position:relative; height:160px; }
  .empty{ color:var(--muted); text-align:center; padding:60px 0; grid-column:1/-1; }
  @media (prefers-color-scheme: dark){
    :root{
      --bg:#14161a; --card:#1c1f26; --text:#e7e9ee; --muted:#9aa2b1; --border:#2b2f38;
      --accent:#60a5fa; --accent-fill:rgba(96,165,250,0.14);
      --badge-view-bg:#1e2a4a; --badge-view-fg:#93c5fd;
      --badge-group-bg:#173a28; --badge-group-fg:#86efac;
    }
  }
</style>
</head>
<body>
<header>
  <h1>__TITLE__</h1>
  <div class="subtitle">__SUBTITLE__</div>
  <div class="controls">
    <input id="search" type="text" placeholder="Filter by name or system...">
    <select id="categoryFilter">
      <option value="All">All categories</option>
      <option value="View">Views</option>
      <option value="Protection Group">Protection Groups</option>
    </select>
    <span id="count"></span>
  </div>
</header>
<main>
  <div id="grid"></div>
</main>
<script>
  const payload = __CHART_DATA__;
  const charts = [];

  function destroyCharts(){
    charts.forEach(c => c.destroy());
    charts.length = 0;
  }

  function render(){
    const grid = document.getElementById('grid');
    destroyCharts();
    grid.innerHTML = '';

    const q = document.getElementById('search').value.trim().toLowerCase();
    const cat = document.getElementById('categoryFilter').value;
    const filtered = payload.entities.filter(function(d){
      const matchesCat = (cat === 'All' || d.category === cat);
      const matchesText = !q || (d.name || '').toLowerCase().includes(q) || (d.system || '').toLowerCase().includes(q);
      return matchesCat && matchesText;
    });

    document.getElementById('count').textContent = filtered.length + ' of ' + payload.entities.length + ' entities';

    if(filtered.length === 0){
      const empty = document.createElement('div');
      empty.className = 'empty';
      empty.textContent = 'No entities match this filter.';
      grid.appendChild(empty);
      return;
    }

    filtered.forEach(function(d){
      const card = document.createElement('div');
      card.className = 'card';

      const header = document.createElement('div');
      header.className = 'card-header';

      const nameEl = document.createElement('span');
      nameEl.className = 'name';
      nameEl.title = d.name;
      nameEl.textContent = d.name;

      const badgeEl = document.createElement('span');
      badgeEl.className = 'badge ' + (d.category === 'View' ? 'badge-view' : 'badge-group');
      badgeEl.textContent = d.category;

      header.appendChild(nameEl);
      header.appendChild(badgeEl);

      const sysEl = document.createElement('div');
      sysEl.className = 'system';
      sysEl.textContent = d.system;

      const chartWrap = document.createElement('div');
      chartWrap.className = 'chart-wrap';
      const canvas = document.createElement('canvas');
      chartWrap.appendChild(canvas);

      card.appendChild(header);
      card.appendChild(sysEl);
      card.appendChild(chartWrap);
      grid.appendChild(card);

      const chart = new Chart(canvas.getContext('2d'), {
        type: 'line',
        data: {
          labels: payload.months,
          datasets: [{
            label: 'scRetained (' + payload.units + ')',
            data: d.values,
            borderColor: '#2563eb',
            backgroundColor: 'rgba(37,99,235,0.12)',
            fill: true,
            tension: 0.25,
            pointRadius: 2,
            borderWidth: 2
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false,
          plugins: {
            legend: { display: false },
            tooltip: {
              callbacks: {
                label: function(ctx){ return ctx.parsed.y + ' ' + payload.units; }
              }
            }
          },
          scales: {
            x: { ticks: { maxRotation: 60, minRotation: 45, font: { size: 10 } } },
            y: { beginAtZero: false, ticks: { font: { size: 10 } } }
          }
        }
      });
      charts.push(chart);
    });
  }

  document.getElementById('search').addEventListener('input', render);
  document.getElementById('categoryFilter').addEventListener('change', render);
  render();
</script>
</body>
</html>
'@

    $title = "Storage Consumption Trend - scRetained ($units)"
    $subtitle = "$($chartPayload.entities.Count) entities  .  $firstLabel to $lastLabel  .  units: $units  .  generated $($chartPayload.generated)"

    $htmlContent = $htmlTemplate.Replace('__TITLE__', $title).Replace('__SUBTITLE__', $subtitle).Replace('__CHART_DATA__', $chartJson)

    $outHtmlName = "Storage Consumption Trend_$($firstLabel)_$($lastLabel)_$($units).html"
    $outHtmlPath = Join-Path $fullOutputPath $outHtmlName
    $htmlContent | Out-File -FilePath $outHtmlPath -Encoding utf8
    Write-Host "HTML report (one chart per entity) written to:`n$outHtmlPath"
}

if($exportRawData){
    foreach($config in $reportConfigs){
        $rows = $rawRows[$config.Category]
        if($rows.Count -gt 0){
            $safeName = $config.Name -replace '[\\/:*?"<>|]', '_'
            $rawCsvPath = Join-Path $fullOutputPath "$($safeName)_raw_$($firstLabel)_$($lastLabel).csv"
            $rows | Export-Csv -Path $rawCsvPath -NoTypeInformation
            Write-Host "Raw data for '$($config.Name)' written to:`n$rawCsvPath"
        }
    }
}

if($stillFailed.Count -gt 0){
    Write-Host "`nWARNING: $($stillFailed.Count) cluster/month/report call(s) never succeeded (listed above) -" -ForegroundColor Red
    Write-Host "entities that only existed in that month/cluster, or values for that month on entities seen" -ForegroundColor Red
    Write-Host "elsewhere, will be missing or zero as a result. Re-run once the underlying issue is resolved.`n" -ForegroundColor Yellow
}

$totalSeconds = ((Get-Date) - $date1).TotalSeconds
Write-Host "`nTotal time: $([math]::Round($totalSeconds)) seconds`n"
