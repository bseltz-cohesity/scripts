### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local' # local or AD domain
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

$cluster = api get cluster
$clusterName = $cluster.name

$dateString = (get-date).ToString("yyyy-MM-dd")

$csvFileName = "$clusterName-licenseReport-$dateString.csv"

$lic = api get licenseUsage
$currentUsage = $lic.usage.$($cluster.id)
$currentUsage | Format-Table
$currentUsage | Export-Csv -Path $csvFileName

Write-Host "Report saved as $csvFileName"
