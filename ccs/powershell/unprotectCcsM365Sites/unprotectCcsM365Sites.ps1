# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$objectNames,  # optional names of sites protect
    [Parameter()][string]$objectList = '',  # optional textfile of sites to protect
    [Parameter()][string]$objectMatch,
    [Parameter()][int]$pageSize = 50000,
    [Parameter()][switch]$deleteSnapshots
)

# gather list of mailboxes to unprotect
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
            exit 1
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit 1
    }
    return ($items | Sort-Object -Unique)
}

$objectsToUnprotect = @(gatherList -Param $objectNames -FilePath $objectList -Name 'sites' -Required $False)

if($objectsToUnprotect.Count -eq 0 -and ! $objectMatch){
    Write-Host "No sites specified" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

# find O365 source
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false"  # -region $regionId
$objectsNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Sites'}
if(!$objectsNode){
    Write-Host "Source $sourceName is not configured for O365 Sites" -ForegroundColor Yellow
    exit
}

$nameIndex = @{}
$webUrlIndex = @{}
$idIndex = @{}
$unprotectedIndex = @()
$objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false" # -region $regionId
while(1){
    foreach($node in $objects.nodes){
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
        $webUrlIndex[$node.protectionSource.office365ProtectionSource.webUrl] = $node.protectionSource.id
        if($node.unprotectedSourcesSummary.leavesCount -eq 1){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        }
    }
    $cursor = $objects.nodes[-1].protectionSource.id
    $objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false&afterCursorEntityId=$cursor" # -region $regionId
    if(!$objects.PSObject.Properties['nodes'] -or $objects.nodes.Count -eq 1){
        break
    }
}
 
if($objectsToUnprotect.Count -eq 0){
    $useIds = $True
    if($objectMatch){
        $webUrlIndex.Keys | Where-Object {$_ -match $objectMatch -and $webUrlIndex[$_]} | ForEach-Object{
            if($webUrlIndex[$_] -notin $unprotectedIndex){
                $objectsToUnprotect = @($objectsToUnprotect + $webUrlIndex[$_])
            }
        }
        $nameIndex.Keys | Where-Object {$_ -match $objectMatch -and $webUrlIndex[$_]} | ForEach-Object{
            if($nameIndex[$_] -notin $unprotectedIndex){
                $objectsToUnprotect = @($objectsToUnprotect + $nameIndex[$_])
            }
        }
        $objectsToUnprotect = @($objectsToUnprotect | Sort-Object -Unique)
    }
}

if($objectsToUnprotect.Count -eq 0){
    Write-Host "No sites specified" -ForegroundColor Yellow
    exit
}

if($deleteSnapshots){
    $delSnaps = $True
}else{
    $delSnaps = $false
}

foreach($objName in $objectsToUnprotect){
    $objId = $null
    if($useIds -eq $True){
        $objId = $objName
        $objName = $idIndex["$objId"]
    }else{
        if($webUrlIndex.ContainsKey($objName)){
            $objId = $webUrlIndex[$objName]
        }elseif($nameIndex.ContainsKey($objName)){
            $objId = $nameIndex[$objName]
        }
    }
    if($objId){
        if($objId -notin $unprotectedIndex){
            $unprotectParams = @{
                "action" = "UnProtect";
                "objectActionKey" = "kO365Sharepoint";
                "unProtectParams" = @{
                    "objects" = @(
                        @{
                            "id" = $objId;
                            "deleteAllSnapshots" = $delSnaps;
                            "forceUnprotect" = $true
                        }
                    )
                }
            }
            Write-Host "Unprotecting $objName"
            $null = api post -v2 data-protect/protected-objects/actions $unprotectParams
        }
    }else{
        Write-Host "Site $object not found" -ForegroundColor Yellow
    }
}
