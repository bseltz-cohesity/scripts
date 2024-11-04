### usage: ./storageChart.ps1 -vip 192.168.1.198 -username admin [ -domain local ] [ -days 60 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
	[Parameter()][string]$domain = 'local',
	[Parameter()][switch]$showCapacity,
    [Parameter()][int32]$days = 60
)

### constants
$GB = (1024*1024*1024)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### calculate startTimeMsecs
$startTimeMsecs = $(timeAgo $days days)/1000

### get cluster info
$clusterInfo = api get cluster?fetchStats=true
$clusterId = $clusterInfo.id
$clusterName = $clusterInfo.name

### collect $days of write throughput stats
write-host "Gathering Storage Statistics..." -ForegroundColor Green
$stats = api get statistics/timeSeriesStats?schemaName=kBridgeClusterStats`&entityId=$clusterId`&metricName=kMorphedUsageBytes`&startTimeMsecs=$startTimeMsecs`&rollupFunction=average`&rollupIntervalSecs=86400
if($showCapacity){
	$stats2 = api get statistics/timeSeriesStats?schemaName=kBridgeClusterStats`&entityId=$clusterId`&metricName=kCapacityBytes`&startTimeMsecs=$startTimeMsecs`&rollupFunction=average`&rollupIntervalSecs=86400
}

# usage stats
$statDays = @()
$statConsumed = @()
foreach ($stat in $stats.dataPointVec){
	$dt = usecsToDate (($stat.timestampMsecs)*1000)
    $consumed = $stat.data.int64Value/$GB
    $statDays += $dt
    $statConsumed +=  [math]::Round($consumed)
}

if($showCapacity){
	# capacity stats
	$stat2Days = @()
	$stat2Consumed = @()
	foreach ($stat in $stats2.dataPointVec){
		$dt = usecsToDate (($stat.timestampMsecs)*1000)
		$consumed = $stat.data.int64Value/$GB
		$stat2Days += $dt
		$stat2Consumed +=  [math]::Round($consumed)
	}
}

$html = '<!DOCTYPE HTML>
<html>
<head>
<link href="https://canvasjs.com/assets/css/jquery-ui.1.11.2.min.css" rel="stylesheet" />
<style>
  .ui-tabs-anchor {
    outline: none;
  }
</style>
<script>
window.onload = function() {
var options1 = {
	animationEnabled: true,
	title: {
		text: "Storage Consumption (in GB)"
	},
	axisX: {
		labelFontSize: 14
	},
	axisY: {
		labelFontSize: 14
	},
	data: [{
		yValueFormatString: "#,### GB",
		xValueFormatString: "YYYY-MM-DD",
		type: "spline", //change it to line, area, bar, pie, etc
		dataPoints: ['

0..($statConsumed.Length -1) | ForEach-Object{
	$idx = $_
	$html += "{x: new Date($($statDays[$idx].year), $($statDays[$idx].month - 1), $($statDays[$idx].day)), y: $($statConsumed[$idx])},"
}

$html += '
		]
	}'

if($showCapacity){
	$html += '
		,{
		yValueFormatString: "#,### GB",
		xValueFormatString: "YYYY-MM-DD",
		type: "spline", //change it to line, area, bar, pie, etc
		dataPoints: ['
		0..($stat2Consumed.Length -1) | ForEach-Object{
			$idx = $_
			$html += "{x: new Date($($stat2Days[$idx].year), $($stat2Days[$idx].month - 1), $($stat2Days[$idx].day)), y: $($stat2Consumed[$idx])},"
		}
		$html += '
		]
	}'
}

$html += ']};
$("#tabs").tabs({
	create: function (event, ui) {
		//Render Charts after tabs have been created.
		$("#chartContainer1").CanvasJSChart(options1);
		//$("#chartContainer2").CanvasJSChart(options2);
	},
	activate: function (event, ui) {
		//Updates the chart to its container size if it has changed.
		ui.newPanel.children().first().CanvasJSChart().render();
	}
});

}
</script>
</head>
<body>
<div id="tabs" style="height: 360px">
<ul>
<li ><a href="#tabs-1" style="font-size: 12px">' + "$clusterName ($clusterId)" + '</a></li>
</ul>
<div id="tabs-1" style="height: 300px">
<div id="chartContainer1" style="height: 300px; width: 100%;"></div>
</div>
</div>
</div>
<script src="https://canvasjs.com/assets/script/jquery-1.11.1.min.js"></script>
<script src="https://canvasjs.com/assets/script/jquery-ui.1.11.2.min.js"></script>
<script src="https://canvasjs.com/assets/script/jquery.canvasjs.min.js"></script>
</body>
</html>'

$outFilePath = join-path -Path $PSScriptRoot -ChildPath 'storageGrowth.html'

write-host "Writing Output to $outFilePath" -ForegroundColor Green
$html | Out-File -FilePath $outFilePath -Encoding ascii
.$outFilePath
