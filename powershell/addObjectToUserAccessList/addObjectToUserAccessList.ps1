### process commandline arguments
[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][array]$clusterName,
    [Parameter()][array]$principalName,
    [Parameter()][string]$principalList,
    [Parameter()][string]$sourceName,
    [Parameter()][array]$objectName,
    [Parameter()][string]$objectList,
    [Parameter()][array]$viewName,
    [Parameter()][string]$viewList,
    [Parameter()][string]$environment,
    [Parameter()][switch]$remove,
    [Parameter()][string]$allOfType
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

if($objects.Count -eq 0 -and $viewNames.Count -eq 0 -and !$allOfType){
    if($sourceName){
        $objects += $sourceName
    }else{
        Write-Host "At least one object or view must be specified" -ForegroundColor Yellow
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

function processCluster(){
    $users = api get users?_includeTenantInfo=true
    $groups = api get groups?_includeTenantInfo=true
    $registeredSources = api get "protectionSources/registrationInfo"

    if($allOfType){
        $theseSources = $registeredSources.rootNodes | Where-Object {$_.rootNode.environment -eq $allOfType -or $allOfType -in $_.applications.environment}
        if(@($theseSources).Count -eq 0){
            Write-Host "  No sources of type $allOfType found" -ForegroundColor Yellow
            return
        }
        $objects = @($objects + $theseSources.rootNode.name)
    }

    if($sourceName){
        $registeredSource = $registeredSources.rootNodes | Where-Object {$_.rootNode.name -eq $sourceName}
        if(! $registeredSource){
            Write-Host "  Source $sourceName not found" -ForegroundColor Yellow
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
            Write-Host "  Principal $d\$p not found!" -ForegroundColor Yellow
            continue
        }else{
            Write-Host "  $d\$p"
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
}

# authentication / multi-cluster loop (see baseAuth-multi.ps1) =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if(! $USING_HELIOS -and $useApiKey -and $password){
        # a cluster API key specified on the command line won't work for multiple clusters
        $password = $null
    }
    if($USING_HELIOS){
        if(! $clusterName){
            # inventory every Helios/MCM-managed cluster if none were specified on the command line
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            Write-Host "`n$c"
            processCluster
        }
    }else{
        Write-Host "`n$v"
        processCluster
    }
}
Write-Host ""

