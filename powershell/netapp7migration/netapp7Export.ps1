### usage:
# .\netapp7Export.ps1 -controllerName mynetappp.mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$controllerName
)

"Connecting to $controllerName..."
$null = Connect-NaController -Name $controllerName

"`nExporting Configuration details from $controllerName..."
"    SMB Shares"
Get-NaCifsShare | ConvertTo-Json -Depth 99 | Out-File "$controllerName-shares.json"
"    SMB Permissions"
Get-NaCifsShareAcl | ConvertTo-Json -Depth 99 | Out-File "$controllername-acls.json"
"    NFS Exports"
Get-NaNfsExport | ConvertTo-Json -Depth 99 | Out-File "$controllername-exports.json"
"    QTrees"
Get-NaQtree | ConvertTo-Json -Depth 99 | Out-File "$controllername-qtrees.json"
"    Volumes"
$volumes = Get-NaVol
$volumes | ConvertTo-Json -Depth 99 | Out-File "$controllername-volumes.json"
"    Snapshot Schedules"
$volumes | ForEach-Object{ Get-NaSnapshotSchedule -TargetName $_.Name } | ConvertTo-Json -Depth 99 | Out-File "$controllername-snapshotschedules.json"
"    Quotas"
Get-NaQuotaReport | ConvertTo-Json -Depth 99 | Out-File "$controllername-quotas.json"
