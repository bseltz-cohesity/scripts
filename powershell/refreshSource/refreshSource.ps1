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
apiauth -vip $vip -username $username -domain $domain

function getObjectId($sourceName){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $sourceName){
            $global:_object_id = $obj.protectionSource.id
            break
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node
                }
            }
        }
    }
    
    foreach($source in (api get protectionSources)){
        if($null -eq $global:_object_id){
            get_nodes $source
        }
    }
    return $global:_object_id
}

$objectId = getObjectId $sourceName
if($objectId){
    write-host "refreshing $sourceName..."
    api post protectionSources/refresh/$($objectId)
}else{
    write-host "$sourceName not found" -ForegroundColor Yellow
}
