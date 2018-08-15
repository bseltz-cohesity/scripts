### usage: ./refreshSource.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -source myVcenter

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$source
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find and refresh protection Source
$sources = api get protectionSources | Where-Object {$_.protectionSource.name -ieq $source }
if($sources){
    "refreshing $source..."
    api post protectionSources/refresh/$($sources[0].protectionSource.id)
}else{
    Write-Warning "$source not found!"
}


