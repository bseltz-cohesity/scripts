### usage: ./storageChart.ps1 -vip 192.168.1.198 -username admin [ -domain local ] [ -days 60 ] [ -theme light ]
###        ./storageChart.ps1 -username myuser@mydomain.net -clusterName mycluster   (Helios)

### process commandline arguments
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
    [Parameter()][int32]$days = 60,
    [Parameter()][string]$outputPath,
    [Parameter()][ValidateSet('light', 'dark')][string]$theme = 'dark'
)

### constants
$GB = (1024*1024*1024)

### source the cohesity-api helper code
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

### calculate startTimeMsecs
$startTimeMsecs = $(timeAgo $days days)/1000

### get cluster info
$clusterInfo = api get cluster?fetchStats=true
$clusterId = $clusterInfo.id
$clusterDisplayName = $clusterInfo.name

### collect $days of storage stats
write-host "Gathering Storage Statistics..." -ForegroundColor Green
$stats = api get statistics/timeSeriesStats?schemaName=kBridgeClusterStats`&entityId=$clusterId`&metricName=kMorphedUsageBytes`&startTimeMsecs=$startTimeMsecs`&rollupFunction=average`&rollupIntervalSecs=86400
# capacity uses the max of each day (not the average) so brief dips in reported
# capacity (partial samples, nodes/disks momentarily missing) don't drag the line down
$stats2 = api get statistics/timeSeriesStats?schemaName=kBridgeClusterStats`&entityId=$clusterId`&metricName=kCapacityBytes`&startTimeMsecs=$startTimeMsecs`&rollupFunction=max`&rollupIntervalSecs=86400

# convert a timeSeriesStats response into an ordered list of {Label, Value} (Value in GB)
function statsToSeries($metricBlock){
    $series = @()
    if($metricBlock -and $metricBlock.PSObject.Properties['dataPointVec'] -and $metricBlock.dataPointVec){
        foreach($point in $metricBlock.dataPointVec){
            if($point.data -and $null -ne $point.data.int64Value){
                $dt = usecsToDate (($point.timestampMsecs) * 1000)
                $series += [PSCustomObject]@{
                    Label = $dt.ToString('yyyy-MM-dd')
                    Value = [math]::Round($point.data.int64Value / $GB)
                }
            }
        }
    }
    return @($series)
}

$usedSeries = statsToSeries $stats
$capacitySeries = statsToSeries $stats2

# hold the previous capacity value until it changes by more than $capacityToleranceGB,
# so small variations in the reported value don't show up as noise in the line
$capacityToleranceGB = 10
$heldCapacity = $null
foreach($point in $capacitySeries){
    if($null -eq $heldCapacity -or [math]::Abs($point.Value - $heldCapacity) -gt $capacityToleranceGB){
        $heldCapacity = $point.Value
    }
    $point.Value = $heldCapacity
}

# labels come from the usage series; capacity values are lined up by date (null where missing)
$labels = @($usedSeries | ForEach-Object { $_.Label })
$usedValues = @($usedSeries | ForEach-Object { $_.Value })
$capacityByLabel = @{}
foreach($point in $capacitySeries){
    $capacityByLabel[$point.Label] = $point.Value
}
$capacityValues = @($labels | ForEach-Object {
    if($capacityByLabel.ContainsKey($_)){ $capacityByLabel[$_] } else { $null }
})

function toJson($items){
    if($items.Count -eq 0){ return '[]' }
    return (ConvertTo-Json -InputObject @($items) -Compress)
}

$clusterDisplay = "$clusterDisplayName ($clusterId)".ToUpper()
$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm'
if($labels.Count -gt 0){
    $rangeLabel = "$($labels[0]) to $($labels[-1])"
}else{
    $rangeLabel = "last $days days"
}

$htmlTemplate = @'
<!doctype html>
<html class="__THEME_CLASS__">
<head>
<meta charset="utf-8">
<title>Storage Consumption - __CLUSTERNAME__</title>
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
<h1>Storage Consumption: __CLUSTERNAME__</h1>
<div class="meta">Range: __RANGELABEL__ &nbsp;|&nbsp; Generated: __GENERATEDAT__</div>

<div class="chart-card">
  <h2>Storage Consumption (GB)</h2>
  <canvas id="storageChart"></canvas>
</div>

<script>
var chartTextColor = '__CHART_TEXT_COLOR__';
var chartGridColor = '__CHART_GRID_COLOR__';

function makeLineChart(canvasId, labels, datasets, yLabel, showLegend){
  var ctx = document.getElementById(canvasId).getContext('2d');
  new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: datasets.map(function(d){
        return {
          label: d.label,
          data: d.data,
          borderColor: d.color,
          backgroundColor: d.color + '33',
          fill: d.fill,
          tension: d.tension,
          pointRadius: 2,
          pointHoverRadius: 6,
          spanGaps: true
        };
      })
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
      plugins: {
        legend: { display: showLegend, labels: { color: chartTextColor } },
        tooltip: {
          callbacks: {
            label: function(item){
              return item.dataset.label + ': ' + Number(item.parsed.y).toLocaleString() + ' GB';
            },
            footer: function(items){
              var i = items[0].dataIndex;
              var used = usedData[i];
              var cap = capacityData[i];
              if(used === null || used === undefined || !cap){ return ''; }
              return 'Percent full: ' + (used / cap * 100).toFixed(1) + '%';
            }
          }
        }
      }
    }
  });
}

var labels = __LABELS__;
var usedData = __USED_DATA__;
var capacityData = __CAPACITY_DATA__;

if(usedData.length){
  // capacity is drawn with straight segments (tension 0): a curved spline overshoots
  // between points and makes a nearly flat line look like it wiggles
  var datasets = [{ label: 'Used', data: usedData, color: '#2e7de9', fill: true, tension: 0.3 }];
  if(capacityData.length){
    datasets.push({ label: 'Capacity', data: capacityData, color: '#e9822e', fill: false, tension: 0 });
  }
  makeLineChart('storageChart', labels, datasets, 'GB', capacityData.length > 0);
}else{
  document.getElementById('storageChart').outerHTML = '<div class="no-data">No data available for this range</div>';
}
</script>
</body>
</html>
'@

# NOTE: use the literal String.Replace() method, not the -replace operator.
# -replace is regex-based and treats '$' in the replacement text as a backreference
# token, which corrupts output when substituting in the Chart.js source.

# Chart.js v4.4.4 (MIT License, https://www.chartjs.org) is normally loaded from a
# companion file next to this script, so the report still renders charts with no
# internet access. If that file isn't present, fall back to fetching it online.
$chartJsCdnUrl = 'https://unpkg.com/chart.js@4.4.4/dist/chart.umd.js'
$chartJsPath = Join-Path -Path $PSScriptRoot -ChildPath 'chart.umd.js'
if(Test-Path $chartJsPath){
    $chartJsSource = Get-Content -Path $chartJsPath -Raw
}else{
    Write-Host "chart.umd.js not found next to the script - fetching it from $chartJsCdnUrl" -ForegroundColor Yellow
    try{
        $chartJsSource = (Invoke-WebRequest -UseBasicParsing -Uri $chartJsCdnUrl).Content
    }catch{
        Write-Host "Unable to fetch Chart.js from $chartJsCdnUrl - charts will not render. $($_.Exception.Message)" -ForegroundColor Yellow
        $chartJsSource = ''
    }
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
$htmlTemplate = $htmlTemplate.Replace('__CLUSTERNAME__', $clusterDisplay)
$htmlTemplate = $htmlTemplate.Replace('__RANGELABEL__', $rangeLabel)
$htmlTemplate = $htmlTemplate.Replace('__GENERATEDAT__', $generatedAt)
$htmlTemplate = $htmlTemplate.Replace('__LABELS__', (toJson $labels))
$htmlTemplate = $htmlTemplate.Replace('__USED_DATA__', (toJson $usedValues))
$htmlTemplate = $htmlTemplate.Replace('__CAPACITY_DATA__', (toJson $capacityValues))

if(! $outputPath){
    $outputPath = Join-Path -Path $PSScriptRoot -ChildPath 'storageChart.html'
}

write-host "Writing Output to $outputPath" -ForegroundColor Green
$htmlTemplate | Out-File -FilePath $outputPath -Encoding utf8

try{
    Invoke-Item -Path $outputPath
}catch{
    try{
        Start-Process -FilePath $outputPath
    }catch{
        Write-Host "Unable to automatically open $outputPath - please open it manually" -ForegroundColor Yellow
    }
}