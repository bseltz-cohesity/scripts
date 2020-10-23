### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$principal,
    [Parameter()][array]$addObject,
    [Parameter()][array]$addView,
    [Parameter()][array]$removeObject,
    [Parameter()][array]$removeView
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$users = api get users?_includeTenantInfo=true
$groups = api get groups?_includeTenantInfo=true
$sources = api get "protectionSources"
$views = api get views

function getObjectId($objectName){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $global:_object_id = $obj.protectionSource.id
            break
        }
        if($obj.name -eq $objectName){
            $global:_object_id = $obj.id
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
    
    foreach($source in $sources){
        if($null -eq $global:_object_id){
            get_nodes $source
        }
    }
    return $global:_object_id
}


foreach($p in $principal){
    if($p -match '/'){
        $d, $p = $p.split('/')
    }else{
        $d = 'local'
    }
    $ptype = 'user'
    $thisPrincipal = $users | Where-Object {$_.username -eq $p -and $_.domain -eq $d}
    if(!$thisPrincipal){
        $ptype = 'group'
        $thisPrincipal = $groups | Where-Object {$_.name -eq $p -and $_.domain -eq $d}
    }
    if(!$thisPrincipal){
        Write-Host "Principal $d/$p not found!" -ForegroundColor Yellow
        continue
    }
    $access = api get principals/protectionSources?sids=$($thisPrincipal.sid)
    $newAccess = @{
        "sourcesForPrincipals" = @(
            @{
                "sid"                 = $thisPrincipal.sid;
                "protectionSourceIds" = [array]$access.protectionSources.id;
                "viewNames"           = [array]$access.views.name
            }
        )
    }
    foreach($objectName in $addObject){
        $objectId = getObjectId $objectName
        if(!$objectId){
            Write-Host "Object $objectName not found!" -ForegroundColor Yellow
            continue
        }
        "Adding $objectName"
        $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $objectId)
    }
    foreach($objectName in $removeObject){
        $objectId = getObjectId $objectName
        if($objectId){
            "Removing $objectName"
            $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds | Where-Object {$_ -ne $objectId})
        }
    }
    foreach($viewName in $addView){
        $view = $views.views | Where-Object {$_.name -eq $viewName}
        if(!$view){
            Write-Host "View $viewName not found" -ForegroundColor Yellow
            continue
        }
        "Adding $viewName"
        $newAccess.sourcesForPrincipals[0].viewNames = @($newAccess.sourcesForPrincipals[0].viewNames + $view.name)
    }
    foreach($viewName in $removeView){
        "Removing $viewName"
        $newAccess.sourcesForPrincipals[0].viewNames = @($newAccess.sourcesForPrincipals[0].viewNames | Where-Object {$_ -ne $viewName})
    }
    $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds | Sort-Object -Unique)
    $newAccess.sourcesForPrincipals[0].viewNames = @($newAccess.sourcesForPrincipals[0].viewNames | Sort-Object -Unique)
    $thisPrincipal.restricted = $True
    if($ptype -eq 'user'){
        $null = api put users $thisPrincipal
    }else{
        $null = api put groups $thisPrincipal
    }
    $null = api put principals/protectionSources $newAccess
}
