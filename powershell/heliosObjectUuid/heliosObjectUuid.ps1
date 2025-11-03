[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][array]$clusterNames,
    [Parameter(Mandatory=$True)][string]$objectName,
    [Parameter()][switch]$fuzzySearch
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain 'local' -helios

$deletedSearch = api get -v2 "data-protect/search/objects?searchString=$objectName&isDeleted=true"
$deletedSearch.objects | ForEach-Object {setApiProperty -object $_ -name 'isDeleted' -Value $True}
$search = api get -v2 "data-protect/search/objects?searchString=$objectName"
$search.objects | ForEach-Object {setApiProperty -object $_ -name 'isDeleted' -Value $False}
if($fuzzySearch){
    $allObjects = @($search.objects + $deletedSearch.objects)
}else{
    $allObjects = @(($search.objects + $deletedSearch.objects) | Where-Object {$_.name -eq $objectName})
}
$allObjects | Sort-Object -Property name | Format-Table -Property name, environment, globalId, isDeleted
