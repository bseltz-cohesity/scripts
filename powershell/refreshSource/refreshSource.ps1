### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$sourceName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -quiet

$sources = api get 'protectionSources/registrationInfo?allUnderHierarchy=false'

function getObjectId($sourceName){
    foreach($source in $sources.rootNodes){
        if($source.rootNode.name -eq $sourceName){
            return $source.rootNode.id
        }
    }
    return $null
}

$objectId = getObjectId $sourceName
if($objectId){
    write-host "refreshing $sourceName..."
    $result = api post protectionSources/refresh/$($objectId)
    $result
}else{
    write-host "$sourceName not found" -ForegroundColor Yellow
}
