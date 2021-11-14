# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
	[Parameter()][string]$domain = 'local',
	[Parameter(Mandatory = $True)][string]$vaultName,
    [Parameter()][int32]$days = 60
)

# constants
$GB = (1024*1024*1024)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# calculate startTimeMsecs
$startTimeMsecs = $(timeAgo $days days)/1000

# get target
$vaults = api get vaults
$vault = $vaults | Where-Object name -eq $vaultName
if(! $vault){
	Write-Host "External target $vaultName not found" -ForegroundColor Yellow
	exit 1
}

# collect $days of write throughput stats
write-host "`nGathering Storage Statistics...`n"

# output file
$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "externalTargetStorageStats-$($cluster.name)-$($vaultName)-$dateString.csv")
"Date,Archived GiB,Used GiB,Garbage Collected GiB" | Out-File -FilePath $outputfile

# morphed usage
$stats = api get "statistics/timeSeriesStats?entityId=$($vault.id)&metricName=kMorphedUsageBytes&metricUnitType=0&range=month&rollupFunction=latest&rollupIntervalSecs=86400&schemaName=kIceboxVaultStats&startTimeMsecs=$startTimeMsecs"
$statConsumed = @{}
foreach ($stat in $stats.dataPointVec){
	$dt = usecsToDate (($stat.timestampMsecs)*1000)
	$key = "$($dt.year)-$($dt.month.ToString().PadLeft(2,'0'))-$($dt.day.ToString().PadLeft(2,"0"))"
    $consumed = $stat.data.int64Value/$GB
    $statConsumed[$key] = [math]::Round($consumed,2)
}

# morphed garbage collected
$stats = api get "statistics/timeSeriesStats?entityId=$($vault.id)&metricName=kUnmorphedBytesGCed&metricUnitType=0&range=month&rollupFunction=latest&rollupIntervalSecs=86400&schemaName=kIceboxVaultStats&startTimeMsecs=$startTimeMsecs"
$statCollected = @{}
foreach ($stat in $stats.dataPointVec){
	$dt = usecsToDate (($stat.timestampMsecs)*1000)
	$key = "$($dt.year)-$($dt.month.ToString().PadLeft(2,'0'))-$($dt.day.ToString().PadLeft(2,"0"))"
    $collected = $stat.data.int64Value/$GB
    $statCollected[$key] = [math]::Round($collected,2)
}

# morphed data archived
$stats = api get "statistics/timeSeriesStats?entityId=$($vault.id)&metricName=kMorphedBytesArchived&metricUnitType=0&range=month&rollupFunction=latest&rollupIntervalSecs=86400&schemaName=kIceboxVaultStats&startTimeMsecs=$startTimeMsecs"
$statArchived = @{}
foreach ($stat in $stats.dataPointVec){
	$dt = usecsToDate (($stat.timestampMsecs)*1000)
	$key = "$($dt.year)-$($dt.month.ToString().PadLeft(2,'0'))-$($dt.day.ToString().PadLeft(2,"0"))"
    $archived = $stat.data.int64Value/$GB
    $statArchived[$key] = [math]::Round($archived,2)
}

foreach($key in $statConsumed.Keys | Sort-Object){
	"$($key),$($statArchived[$key]),$($statConsumed[$key]),$($statCollected[$key])" | Tee-Object -FilePath $outputfile -Append
}

Write-Host "`nOutput saved to $outputfile`n"