### process commandline arguments
[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$principalName,
    [Parameter()][string]$principalList,
    [Parameter()][string]$sourceName,
    [Parameter()][array]$objectName,
    [Parameter()][string]$objectList,
    [Parameter()][array]$viewName,
    [Parameter()][string]$viewList,
    [Parameter()][string]$environment,
    [Parameter()][switch]$remove
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$principals = @(gatherList -Param $principalName -FilePath $principalList -Name 'principals' -Required $True)
$objects = @(gatherList -Param $objectName -FilePath $objectList -Name 'objects' -Required $False)
$viewNames = @(gatherList -Param $viewName -FilePath $viewList -Name 'views' -Required $False)

# if($objects.Count -gt 0){
#     if(!$sourceName){
#         Write-Host "-sourceName is required" -ForegroundColor Yellow
#         exit 1
#     }
# }

if($objects.Count -eq 0 -and $viewNames.Count -eq 0){
    if($sourceName){
        $objects += $sourceName
    }else{
        Write-Host "At least one object or view must be specified" -ForegroundColor Yellow
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$users = api get users?_includeTenantInfo=true
$groups = api get groups?_includeTenantInfo=true
$registeredSources = api get "protectionSources/registrationInfo"

if($sourceName){
    $registeredSource = $registeredSources.rootNodes | Where-Object {$_.rootNode.name -eq $sourceName}
    if(! $registeredSource){
        Write-Host "Source $sourceName not found" -ForegroundColor Yellow
        exit 1
    }
    $sources = api get "protectionSources?id=$($registeredSource.rootNode.id)&includeVMFolders=true"
}

if($viewNames.Count -gt 0){
    $views = api get views
}

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
        if($obj.PSObject.Properties['applicationNodes']){
            foreach($node in $obj.applicationNodes){
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

foreach($p in $principals){
    if($p.Contains('/')){
        $d, $p = $p.split('/')
    }elseif($p.Contains('\')){
        $d, $p = $p.split('\')
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
        Write-Host "Principal $d\$p not found!" -ForegroundColor Yellow
        continue
    }else{
        Write-Host "$d\$p"
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
    foreach($o in $objects){
        if($sourceName){
            $objectId = getObjectId $o
        }else{
            $thisObject = $null
            $thisObject = $registeredSources.rootNodes | Where-Object {$_.rootNode.name -eq $o}
            if($thisObject){
                $objectId = $thisObject.rootNode.id
            }
        }
        
        if(!$objectId){
            Write-Host "    Object $o not found!" -ForegroundColor Yellow
            continue
        }
        if($remove){
            "    Removing $o"
            $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds | Where-Object {$_ -ne $objectId})
        }else{
            "    Adding $o"
            $newAccess.sourcesForPrincipals[0].protectionSourceIds = @($newAccess.sourcesForPrincipals[0].protectionSourceIds + $objectId)
        }
    }
    foreach($v in $viewNames){
        $view = $views.views | Where-Object {$_.name -eq $v}
        if(!$view){
            Write-Host "    View $v not found" -ForegroundColor Yellow
            continue
        }
        if($remove){
            "    Removing $v"
            $newAccess.sourcesForPrincipals[0].viewNames = @($newAccess.sourcesForPrincipals[0].viewNames | Where-Object {$_ -ne $view.name})
        }else{
            "    Adding $v"
            $newAccess.sourcesForPrincipals[0].viewNames = @($newAccess.sourcesForPrincipals[0].viewNames + $view.name)
        }
        
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
