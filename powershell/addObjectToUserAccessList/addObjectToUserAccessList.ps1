### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][array]$principalName,
    [Parameter()][string]$principalList,
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

if($objects.Count -eq 0 -and $viewNames.Count -eq 0){
    Write-Host "At least one object or view must be specified" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

$users = api get users?_includeTenantInfo=true
$groups = api get groups?_includeTenantInfo=true
if($environment){
    $sources = api get "protectionSources?allUnderHierarchy=true&environments=$environment&includeEntityPermissionInfo=false&includeVMFolders=true&pruneNonCriticalInfo=true&includeObjectProtectionInfo=false"
}else{
    $sources = api get "protectionSources?allUnderHierarchy=true&environments=kVMware&environments=kHyperV&environments=kPhysical&environments=kPure&environments=kAzure&environments=kNetapp&environments=kGenericNas&environments=kAcropolis&environments=kPhysicalFiles&environments=kIsilon&environments=kKVM&environments=kAWS&environments=kExchange&environments=kHyperVVSS&environments=kGCP&environments=kFlashBlade&environments=kAWSNative&environments=kO365&environments=kO365Outlook&environments=kGCPNative&environments=kAzureNative&environments=kAD&environments=kAWSSnapshotManager&environments=kGPFS&environments=kRDSSnapshotManager&environments=kKubernetes&environments=kNimble&environments=kAzureSnapshotManager&environments=kElastifile&environments=kCassandra&environments=kMongoDB&environments=kHBase&environments=kHive&environments=kHdfs&environments=kCouchbase&environments=kUDA&environments=kSQL&environments=kExchange&environments=kOracle&environments=kAD&includeEntityPermissionInfo=true&includeVMFolders=true&pruneNonCriticalInfo=true&includeObjectProtectionInfo=false"
}
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
        $objectId = getObjectId $o
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
