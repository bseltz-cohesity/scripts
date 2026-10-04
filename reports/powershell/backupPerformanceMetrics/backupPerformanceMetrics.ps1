# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][string]$startDate,
    [Parameter()][string]$days = 1,
    [Parameter()][string]$outputPath,
    [Parameter()][switch]$zoom,
    [Parameter()][ValidateSet('light', 'dark')][string]$theme = 'dark'
)

if(! $startDate){
    $startDate = (Get-Date).AddDays(-$days)
}
$startTime = (Get-Date -Date $startDate).Date
$endTime = (Get-Date -Date $startDate).Date.AddDays($days).AddSeconds(-1)
$startTimeMsecs = (dateToUsecs $startTime) / 1000
$endTimeMsecs = (dateToUsecs $endTime) / 1000

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$jobs = api get protectionJobs?isActive=true
$job = $jobs | Where-Object name -eq $jobName
if(!$job){
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
    exit 1
}

$schemas = api get statistics/entitiesSchema?includeInternalSchemas=false
$schema = $schemas | Where-Object name -eq 'kMagnetoBackupJobStats'
$entities = api get statistics/entities?schemaName=kMagnetoBackupJobStats
$entity = $entities | Where-Object {$_.entityId.entityId.data.int64Value -eq $job.id}

$rollupIntervalSecs = 180

$bytesBackedUp = api get "statistics/timeSeriesStats?endTimeMsecs=$endTimeMsecs&entityId=$($job.id)&entityName=$($job.name)&metricName=kNumBytesRead&metricUnitType=0&range=day&rollupFunction=rate&rollupIntervalSecs=$rollupIntervalSecs&schemaName=kMagnetoBackupJobStats&startTimeMsecs=$startTimeMsecs"
$readLatencyFromSource = api get "statistics/timeSeriesStats?endTimeMsecs=$endTimeMsecs&entityId=$($job.id)&entityName=$($job.name)&metricName=kDataReadLatency&metricUnitType=1&range=day&rollupFunction=average&rollupIntervalSecs=$rollupIntervalSecs&schemaName=kMagnetoBackupJobStats&startTimeMsecs=$startTimeMsecs"
$writeLatencyToCluster = api get "statistics/timeSeriesStats?endTimeMsecs=$endTimeMsecs&entityId=$($job.id)&entityName=$($job.name)&metricName=kBridgeDataWriteLatency&metricUnitType=1&range=day&rollupFunction=average&rollupIntervalSecs=$rollupIntervalSecs&schemaName=kMagnetoBackupJobStats&startTimeMsecs=$startTimeMsecs"

# convert a timeSeriesStats response into a simple, sorted array of {Time, Value}
# $divisor scales the raw metric value (e.g. bytes/sec -> MB/sec, usecs -> ms)
function timeSeriesStatsToSeries($metricBlock, $divisor = 1){
    $series = @()
    if($metricBlock -and $metricBlock.PSObject.Properties['dataPointVec'] -and $metricBlock.dataPointVec){
        foreach($point in $metricBlock.dataPointVec){
            $value = $null
            if($point.data){
                if($null -ne $point.data.int64Value){
                    $value = [double]$point.data.int64Value
                }elseif($null -ne $point.data.doubleValue){
                    $value = [double]$point.data.doubleValue
                }
            }
            if($null -ne $value){
                $pointTime = ([datetime]'1970-01-01 00:00:00').AddMilliseconds([double]$point.timestampMsecs).ToLocalTime()
                $series += [PSCustomObject]@{
                    Time  = $pointTime
                    Value = [math]::Round(($value / $divisor), 2)
                }
            }
        }
    }
    return @($series | Sort-Object Time)
}

# the API only returns a data point when the job was active in that interval,
# so fill in the gaps with explicit 0s across the full rangeStart..rangeEnd window
# at intervalSecs spacing. Leaves a truly empty series (no data at all) as empty,
# so the "no data available" case upstream still works.
function fillMissingIntervals($series, $rangeStart, $rangeEnd, $intervalSecs){
    if($series.Count -eq 0){
        return @()
    }
    $valueByOffset = @{}
    foreach($point in $series){
        $offsetSecs = [int64]([math]::Round(($point.Time - $rangeStart).TotalSeconds / $intervalSecs)) * $intervalSecs
        $valueByOffset[$offsetSecs] = $point.Value
    }
    $totalSecs = [int64]([math]::Floor(($rangeEnd - $rangeStart).TotalSeconds))
    $filled = @()
    for([int64]$offsetSecs = 0; $offsetSecs -le $totalSecs; $offsetSecs += $intervalSecs){
        $value = 0
        if($valueByOffset.ContainsKey($offsetSecs)){
            $value = $valueByOffset[$offsetSecs]
        }
        $filled += [PSCustomObject]@{
            Time  = $rangeStart.AddSeconds($offsetSecs)
            Value = $value
        }
    }
    return @($filled)
}

# drop the leading and trailing runs of all-zero points so the chart zooms in on
# the span that actually has activity, keeping one zero point on each side (when
# one exists). If that leaves a window shorter than $minSpanSeconds (e.g. the job
# only produced a couple of datapoints), keep pulling in more zero points from
# whichever side still has them until the displayed window is at least that long.
# Interior zeros (gaps between activity) are left alone. A series that is entirely
# zero is returned unchanged - there's nothing to zoom into.
function trimLeadingTrailingZeros($series, $minSpanSeconds, $intervalSecs){
    if($series.Count -eq 0){
        return $series
    }
    $firstNonZero = -1
    $lastNonZero = -1
    for($i = 0; $i -lt $series.Count; $i++){
        if($series[$i].Value -ne 0){
            if($firstNonZero -eq -1){
                $firstNonZero = $i
            }
            $lastNonZero = $i
        }
    }
    if($firstNonZero -eq -1){
        return $series
    }
    $startIndex = [math]::Max(0, $firstNonZero - 1)
    $endIndex = [math]::Min($series.Count - 1, $lastNonZero + 1)

    $minPoints = [int]([math]::Ceiling($minSpanSeconds / $intervalSecs)) + 1
    while((($endIndex - $startIndex + 1) -lt $minPoints) -and ($startIndex -gt 0 -or $endIndex -lt ($series.Count - 1))){
        if($startIndex -gt 0){
            $startIndex--
        }
        if((($endIndex - $startIndex + 1) -lt $minPoints) -and ($endIndex -lt ($series.Count - 1))){
            $endIndex++
        }
    }
    return @($series[$startIndex..$endIndex])
}

# bytes/sec -> MB/sec, usecs -> ms
$readThroughputSeries = timeSeriesStatsToSeries $bytesBackedUp 1048576
$readLatencySeries     = timeSeriesStatsToSeries $readLatencyFromSource 1000
$writeLatencySeries    = timeSeriesStatsToSeries $writeLatencyToCluster 1000

# fill gaps between actual data points with 0s so the charts don't interpolate across them
$readThroughputSeries = fillMissingIntervals $readThroughputSeries $startTime $endTime $rollupIntervalSecs
$readLatencySeries     = fillMissingIntervals $readLatencySeries $startTime $endTime $rollupIntervalSecs
$writeLatencySeries    = fillMissingIntervals $writeLatencySeries $startTime $endTime $rollupIntervalSecs

if($zoom){
    $minZoomSpanSeconds = 300 # show at least 5 minutes of graph, even for a handful of datapoints
    $readThroughputSeries = trimLeadingTrailingZeros $readThroughputSeries $minZoomSpanSeconds $rollupIntervalSecs
    $readLatencySeries     = trimLeadingTrailingZeros $readLatencySeries $minZoomSpanSeconds $rollupIntervalSecs
    $writeLatencySeries    = trimLeadingTrailingZeros $writeLatencySeries $minZoomSpanSeconds $rollupIntervalSecs
}

function toLabelsJson($series){
    if($series.Count -eq 0){ return '[]' }
    return (ConvertTo-Json -InputObject @($series | ForEach-Object { $_.Time.ToString('MM/dd HH:mm') }) -Compress)
}
function toDataJson($series){
    if($series.Count -eq 0){ return '[]' }
    return (ConvertTo-Json -InputObject @($series | ForEach-Object { $_.Value }) -Compress)
}

$clusterDisplay = $clusterName
if(! $clusterDisplay){
    $clusterDisplay = $vip
}
$clusterDisplay = $clusterDisplay.ToUpper()
$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm'
$rangeLabel = "$(dateToString $startTime 'yyyy-MM-dd') to $(dateToString $endTime 'yyyy-MM-dd')"

$htmlTemplate = @'
<!doctype html>
<html class="__THEME_CLASS__">
<head>
<meta charset="utf-8">
<title>Backup Performance Metrics - __JOBNAME__</title>
<script>
__CHARTJS_SOURCE__
</script>
<style>
  :root.theme-dark {
    --bg: #0f1115;
    --card-bg: #1a1d24;
    --border: #2a2e37;
    --text: #e6e8eb;
    --text-muted: #9aa1a9;
    --heading: #f0f1f3;
    --grid: rgba(255,255,255,0.08);
    --shadow: rgba(0,0,0,0.35);
  }
  :root.theme-light {
    --bg: #f7f8fa;
    --card-bg: #ffffff;
    --border: #e3e6ea;
    --text: #1b1f24;
    --text-muted: #5b6470;
    --heading: #30363d;
    --grid: rgba(0,0,0,0.08);
    --shadow: rgba(0,0,0,0.04);
  }
  body { font-family: -apple-system, Segoe UI, Arial, sans-serif; margin: 24px; background: var(--bg); color: var(--text); }
  h1 { font-size: 20px; margin-bottom: 4px; color: var(--heading); }
  .meta { color: var(--text-muted); font-size: 13px; margin-bottom: 24px; }
  .chart-card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin-bottom: 24px; box-shadow: 0 1px 2px var(--shadow); }
  .chart-card h2 { font-size: 15px; margin: 0 0 12px 0; color: var(--heading); }
  canvas { max-height: 320px; }
  .no-data { color: var(--text-muted); font-size: 13px; padding: 40px 0; text-align: center; }
</style>
</head>
<body>
<h1>Backup Performance Metrics: __JOBNAME__</h1>
<div class="meta">Cluster: __CLUSTERNAME__ &nbsp;|&nbsp; Range: __RANGELABEL__ &nbsp;|&nbsp; Generated: __GENERATEDAT__</div>

<div class="chart-card">
  <h2>Data Read Throughput (MB/s)</h2>
  <canvas id="readThroughputChart"></canvas>
</div>

<div class="chart-card">
  <h2>Read Latency from Source (ms)</h2>
  <canvas id="readLatencyChart"></canvas>
</div>

<div class="chart-card">
  <h2>Write Latency to Cluster (ms)</h2>
  <canvas id="writeLatencyChart"></canvas>
</div>

<script>
var chartTextColor = '__CHART_TEXT_COLOR__';
var chartGridColor = '__CHART_GRID_COLOR__';

function makeLineChart(canvasId, labels, data, color, yLabel){
  var ctx = document.getElementById(canvasId).getContext('2d');
  new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: yLabel,
        data: data,
        borderColor: color,
        backgroundColor: color + '33',
        fill: true,
        tension: 0.3,
        pointRadius: 2
      }]
    },
    options: {
      responsive: true,
      interaction: { mode: 'index', intersect: false },
      scales: {
        y: {
          beginAtZero: true,
          title: { display: true, text: yLabel, color: chartTextColor },
          ticks: { color: chartTextColor },
          grid: { color: chartGridColor }
        },
        x: {
          ticks: { maxRotation: 45, minRotation: 45, color: chartTextColor },
          grid: { color: chartGridColor }
        }
      },
      plugins: { legend: { display: false } }
    }
  });
}

var readLabels = __READ_LABELS__;
var readData = __READ_DATA__;
var readLatLabels = __READLAT_LABELS__;
var readLatData = __READLAT_DATA__;
var writeLatLabels = __WRITELAT_LABELS__;
var writeLatData = __WRITELAT_DATA__;

if(readData.length){ makeLineChart('readThroughputChart', readLabels, readData, '#2e7de9', 'MB/s'); }
else { document.getElementById('readThroughputChart').outerHTML = '<div class="no-data">No data available for this range</div>'; }

if(readLatData.length){ makeLineChart('readLatencyChart', readLatLabels, readLatData, '#e9822e', 'ms'); }
else { document.getElementById('readLatencyChart').outerHTML = '<div class="no-data">No data available for this range</div>'; }

if(writeLatData.length){ makeLineChart('writeLatencyChart', writeLatLabels, writeLatData, '#2ea043', 'ms'); }
else { document.getElementById('writeLatencyChart').outerHTML = '<div class="no-data">No data available for this range</div>'; }
</script>
</body>
</html>
'@

# NOTE: use the literal String.Replace() method, not the -replace operator.
# -replace is regex-based and treats '$' in the replacement text as a backreference
# token, which corrupts output when substituting in the Chart.js source (which
# contains '${...}' template-literal syntax) or any JSON payload that happens to
# contain a '$'. String.Replace() does a plain literal substitution.

# Chart.js v4.4.4 (MIT License, https://www.chartjs.org) is loaded from a companion
# file next to this script, rather than from a CDN, so the report still renders
# charts with no internet access.
$chartJsPath = Join-Path -Path $PSScriptRoot -ChildPath 'chart.umd.js'
if(! (Test-Path $chartJsPath)){
    Write-Host "chart.umd.js not found next to the script at $chartJsPath - charts will not render" -ForegroundColor Yellow
    $chartJsSource = ''
}else{
    $chartJsSource = Get-Content -Path $chartJsPath -Raw
}

if($theme -eq 'dark'){
    $themeClass = 'theme-dark'
    $chartTextColor = '#9aa1a9'
    $chartGridColor = 'rgba(255,255,255,0.08)'
}else{
    $themeClass = 'theme-light'
    $chartTextColor = '#5b6470'
    $chartGridColor = 'rgba(0,0,0,0.08)'
}

$htmlTemplate = $htmlTemplate.Replace('__CHARTJS_SOURCE__', $chartJsSource)
$htmlTemplate = $htmlTemplate.Replace('__THEME_CLASS__', $themeClass)
$htmlTemplate = $htmlTemplate.Replace('__CHART_TEXT_COLOR__', $chartTextColor)
$htmlTemplate = $htmlTemplate.Replace('__CHART_GRID_COLOR__', $chartGridColor)
$htmlTemplate = $htmlTemplate.Replace('__JOBNAME__', $job.name)
$htmlTemplate = $htmlTemplate.Replace('__CLUSTERNAME__', $clusterDisplay)
$htmlTemplate = $htmlTemplate.Replace('__RANGELABEL__', $rangeLabel)
$htmlTemplate = $htmlTemplate.Replace('__GENERATEDAT__', $generatedAt)
$htmlTemplate = $htmlTemplate.Replace('__READ_LABELS__', (toLabelsJson $readThroughputSeries))
$htmlTemplate = $htmlTemplate.Replace('__READ_DATA__', (toDataJson $readThroughputSeries))
$htmlTemplate = $htmlTemplate.Replace('__READLAT_LABELS__', (toLabelsJson $readLatencySeries))
$htmlTemplate = $htmlTemplate.Replace('__READLAT_DATA__', (toDataJson $readLatencySeries))
$htmlTemplate = $htmlTemplate.Replace('__WRITELAT_LABELS__', (toLabelsJson $writeLatencySeries))
$htmlTemplate = $htmlTemplate.Replace('__WRITELAT_DATA__', (toDataJson $writeLatencySeries))

if(! $outputPath){
    $safeJobName = ($jobName -replace '[^a-zA-Z0-9_-]', '_')
    $outputPath = Join-Path -Path $PSScriptRoot -ChildPath "$safeJobName-performance-$(dateToString $startTime 'yyyy-MM-dd').html"
}
$htmlTemplate | Out-File -FilePath $outputPath -Encoding utf8

Write-Host "Report saved to $outputPath" -ForegroundColor Green

try{
    Invoke-Item -Path $outputPath
}catch{
    try{
        Start-Process -FilePath $outputPath
    }catch{
        Write-Host "Unable to automatically open $outputPath - please open it manually" -ForegroundColor Yellow
    }
}