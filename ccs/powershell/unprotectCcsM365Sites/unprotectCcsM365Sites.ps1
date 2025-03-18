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

$script:nameIndex = @{}
$script:webUrlIndex = @{}
$script:idIndex = @{}
$script:unprotectedIndex = @()
$script:protectedIndex = @()

function enumNodes($node){
    $script:nameIndex[$node.protectionSource.name] = $node.protectionSource.id
    $script:idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
    $script:webUrlIndex[$node.protectionSource.office365ProtectionSource.webUrl] = $node.protectionSource.id
    if($node.protectedSourcesSummary[0].leavesCount -gt 0){
        $script:protectedIndex = @($script:protectedIndex + $node.protectionSource.id)
    }
    if($node.unprotectedSourcesSummary[0].leavesCount -gt 0){
        $script:unprotectedIndex = @($script:unprotectedIndex + $node.protectionSource.id)
    }
    if($node.PSObject.Properties['nodes']){
        foreach($subnode in $node.nodes){
            enumNodes $subnode
        }
    }
}

$objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false" # -region $regionId
while(1){
    foreach($node in $objects.nodes){
        enumNodes $node
        # $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        # $idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
        # $webUrlIndex[$node.protectionSource.office365ProtectionSource.webUrl] = $node.protectionSource.id
        # if($node.unprotectedSourcesSummary.leavesCount -eq 1){
        #     $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        # }
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
        $script:webUrlIndex.Keys | Where-Object {$_ -match $objectMatch -and $script:webUrlIndex[$_]} | ForEach-Object{
            if($script:webUrlIndex[$_] -notin $script:unprotectedIndex){
                $objectsToUnprotect = @($objectsToUnprotect + $script:webUrlIndex[$_])
            }
        }
        $script:nameIndex.Keys | Where-Object {$_ -match $objectMatch -and $script:webUrlIndex[$_]} | ForEach-Object{
            if($script:nameIndex[$_] -notin $script:unprotectedIndex){
                $objectsToUnprotect = @($objectsToUnprotect + $script:nameIndex[$_])
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
        $objName = $script:idIndex["$objId"]
    }else{
        if($script:webUrlIndex.ContainsKey($objName)){
            $objId = $script:webUrlIndex[$objName]
        }elseif($script:nameIndex.ContainsKey($objName)){
            $objId = $script:nameIndex[$objName]
        }
    }
    if($objId){
        if($objId -in $script:protectedIndex){
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
