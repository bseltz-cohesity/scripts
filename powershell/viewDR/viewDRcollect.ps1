### usage: .\viewDRcollect.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$outPath
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get views
$views = api get views

if(test-path $outPath){
    write-host "Saving view metadata to $outpath"
}else{
    Write-Warning "$outPath not accessible"
    exit
}

foreach($view in $views.views){
    $filePath = Join-Path -Path $outPath -ChildPath $view.name
    $view | ConvertTo-Json -Depth 99 | Out-File $filePath
}
