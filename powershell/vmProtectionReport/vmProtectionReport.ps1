# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$parentSourceName,
    [Parameter()][Int64]$parentSourceId,
    [Parameter()][switch]$protected,
    [Parameter()][switch]$unProtected
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$report = api get /reports/objects/vmsProtectionStatus

$outFile = "vmReport"

if($parentSourceName){
    $report = $report | Where-Object registeredSourceName -eq $parentSourceName
    $outFile += "-$parentSourceName"
}elseif($parentSourceId){
    $report = $report | Where-Object registeredSourceId -eq $parentSourceId
    $outFile += "-$parentSourceId"
}

if($protected){
    $report = $report | Where-Object protected -eq $True
    $outFile += "-protected"
}elseif ($unprotected) {
    $report = $report | Where-Object protected -eq $false
    $outFile += "-unProtected"
}

$outFile = $(Join-Path -Path $PSScriptRoot -ChildPath "$outFile.csv")

$report | Format-Table
$report | Export-Csv -LiteralPath $outFile
write-host "Report saved as $outFile"
