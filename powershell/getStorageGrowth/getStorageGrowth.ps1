### usage: ./graphStorageGrowth.ps1 -vip 192.168.1.198 -username admin [ -domain local ] [ -days 60 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int32]$days = 60
)

### constants
$TB = (1024*1024*1024*1024)
$GB = (1024*1024*1024)

### create excel woorksheet
$xl = new-object -ComObject Excel.Application   
$workbook = $xl.Workbooks.Add() 
$worksheet = $workbook.Worksheets.Item(1) 
$worksheet.Name = 'Storage Growth'
$worksheet.activate()

### headings for data rows
$row = 1
$worksheet.Cells.Item($row,1) = 'Date'
$worksheet.Cells.Item($row,2) = 'Usage'
$row++

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### calculate startTimeMsecs
$startTimeMsecs = $(timeAgo $days days)/1000

### get cluster info
$clusterInfo = api get cluster?fetchStats=true
$clusterId = $clusterInfo.id

### collect $days of write throughput stats
$stats = api get statistics/timeSeriesStats?schemaName=kBridgeClusterStats`&entityId=$clusterId`&metricName=kSystemUsageBytes`&startTimeMsecs=$startTimeMsecs`&rollupFunction=average`&rollupIntervalSecs=86400

### populate excel worksheet with the throughput stats 
foreach ($stat in $stats.dataPointVec){
    $day = usecsToDate (($stat.timestampMsecs)*1000)
    $consumed = $stat.data.int64Value/$GB
    $worksheet.Cells.Item($row,1) = "$day".split()[0]
    $worksheet.Cells.Item($row,2) =  "{0:N2}" -f $consumed
    $row++
}

### create excel chart
$chartData = $worksheet.Range("A1").CurrentRegion
$chart = $worksheet.Shapes.AddChart().Chart
$chart.chartType = 4
$chart.SetSourceData($chartData)
$chart.HasTitle = $true
$chart.ChartTitle.Text = "Storage Consumption Last $days Days"
$chart.Parent.Top = 50
$chart.Parent.Left = 150
$chart.Parent.Width = 600
$xl.visible = $true
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl)

