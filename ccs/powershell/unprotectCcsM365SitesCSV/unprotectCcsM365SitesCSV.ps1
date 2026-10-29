# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][string]$csvFile,  # csv with name,webUrl columns (required unless -objectMatch is used)
    [Parameter()][string]$objectMatch,  # unprotect all sites whose name starts with this string
    [Parameter()][switch]$unprotectSubSites,
    [Parameter()][switch]$deleteSnapshots,
    [Parameter()][switch]$dbg
)

if($deleteSnapshots){
    $delSnaps = $True
}else{
    $delSnaps = $false
}

if(!$csvFile -and !$objectMatch){
    Write-Host "Please use -csvFile or -objectMatch to specify sites to unprotect" -ForegroundColor Yellow
    exit
}

$objectsToAdd = @()
if($csvFile){
    $objectsToAdd = @(Import-Csv -Path $csvFile) # -Encoding utf8
}
if($objectsToAdd.Count -eq 0 -and !$objectMatch){
    Write-Host "No sites specified" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($dbg){
    enableCohesityAPIDebugger
}

# authenticate
apiauth -username $username

# find O365 source
Write-Host "Finding M365 Protection Source"
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365&excludeProtectionStats=true&regionIds=$region").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$script:nameIndex = @{}
$script:webUrlIndex = @{}
$script:idIndex = @{}
$script:unprotectedIndex = @()
$script:protectedIndex = @()
$script:notClassic = @()
$script:protectedCount = 0
$script:unprotectedIds = @{}
$script:statusCache = @{}

# determine whether a node itself is protected: returns 'protected', 'unprotected' or 'unknown'
# leavesCount describes the subtree, so it is only trusted for leaf nodes with a valid summary;
# otherwise fall back to objectBackupConfiguration from the search API (same signal as indexObject)
function getNodeProtectionStatus($node){
    $id = "$($node.protectionSource.id)"
    if($script:statusCache.ContainsKey($id)){
        return $script:statusCache[$id]
    }
    $status = 'unknown'
    $isLeaf = -not ($node.PSObject.Properties['nodes'] -and @($node.nodes).Count -gt 0)
    $summaryProp = $node.PSObject.Properties['protectedSourcesSummary']
    if($isLeaf -and $summaryProp){
        $summaries = @($summaryProp.Value)
        $summary = $summaries | Where-Object {$_.environment -eq 'kO365Sharepoint'} | Select-Object -First 1
        if(!$summary){
            $summary = $summaries | Select-Object -First 1
        }
        if($summary -and $null -ne $summary.leavesCount){
            if([int64]$summary.leavesCount -gt 0){
                $status = 'protected'
            }else{
                $status = 'unprotected'
            }
        }
    }
    if($status -eq 'unknown'){
        $name = $node.protectionSource.office365ProtectionSource.name
        $webUrl = $node.protectionSource.office365ProtectionSource.webUrl
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kSite&regionIds=$region&sourceIds=$rootSourceId&count=999&searchString=$([uri]::EscapeDataString($name))"
        foreach($found in @($search.objects | Where-Object {$_.sharepointParams.siteWebUrl -eq $webUrl})){
            foreach($info in @($found.objectProtectionInfos | Where-Object {$_.regionId -eq $region -and $_.sourceId -eq $rootSourceId -and "$($_.objectId)" -eq $id})){
                if($info.objectBackupConfiguration -and @($info.objectBackupConfiguration).Count -gt 0){
                    $status = 'protected'
                }else{
                    $status = 'unprotected'
                }
            }
        }
    }
    $script:statusCache[$id] = $status
    return $status
}

function unprotectNodes($source){
    if($source -ne $null -and $source.PSObject.Properties['nodes']){
        foreach($node in $source.nodes){
            $script:nameIndex[$node.protectionSource.office365ProtectionSource.name] = $node.protectionSource.id
            $script:idIndex["$($node.protectionSource.id)"] = $node.protectionSource.office365ProtectionSource.name
            $script:webUrlIndex[$node.protectionSource.office365ProtectionSource.webUrl] = $node.protectionSource.id
            if($node.protectionSource.office365ProtectionSource.PSObject.Properties['siteInfo']){
                if($node.protectionSource.office365ProtectionSource.siteInfo.isGroupSite -eq $True -or $node.protectionSource.office365ProtectionSource.siteInfo.isTeamSite -eq $True){
                    $script:notClassic = @($script:notClassic + $node.protectionSource.id)
                }
            }
            $nodeStatus = getNodeProtectionStatus $node
            if($nodeStatus -eq 'protected'){
                $script:protectedIndex = @($script:protectedIndex + $node.protectionSource.id)
                unprotectObject $node.protectionSource.office365ProtectionSource.webUrl $node.protectionSource.id
            }elseif($nodeStatus -eq 'unprotected'){
                Write-Host "Site $($node.protectionSource.office365ProtectionSource.webUrl) not protected" -ForegroundColor Magenta
                $script:unprotectedIndex = @($script:unprotectedIndex + $node.protectionSource.id)
            }else{
                Write-Host "Site $($node.protectionSource.office365ProtectionSource.webUrl) protection status could not be determined, skipping" -ForegroundColor Yellow
            }
            unprotectNodes $node
        }
    }
}

function indexObject($obj){
    foreach($objectProtectionInfo in $obj.objectProtectionInfos | Where-Object {$_.regionId -eq $region -and $_.sourceId -eq $rootSourceId}){
        $script:nameIndex[$obj.name] = $objectProtectionInfo.objectId
        $script:idIndex["$($objectProtectionInfo.objectId)"] = $obj.name
        $script:webUrlIndex[$obj.sharepointParams.siteWebUrl] = $objectProtectionInfo.objectId
        if($objectProtectionInfo.objectBackupConfiguration -and $objectProtectionInfo.objectBackupConfiguration -ne $null){
            $script:protectedIndex = @($script:protectedIndex + $objectProtectionInfo.objectId)
        }else{
            $script:unprotectedIndex = @($script:unprotectedIndex + $objectProtectionInfo.objectId)
        }
        if($obj.sharepointParams.PSObject.Properties['isGroupSite'] -and $obj.sharepointParams.isGroupSite -eq $True){
            $script:notClassic = @($script:notClassic + $objectProtectionInfo.objectId)
        }elseif($obj.sharepointParams.PSObject.Properties['isTeamSite'] -and $obj.sharepointParams.isTeamSite -eq $True){
            $script:notClassic = @($script:notClassic + $objectProtectionInfo.objectId)
        }
        if($unprotectSubSites){
            $source = api get "protectionSources?id=$($objectProtectionInfo.objectId)&regionId=$region"
            unprotectNodes $source
        }
    }
}

function unprotectObject($objWebUrl, $objId){
    if($script:unprotectedIds.ContainsKey("$objId")){
        Write-Host "Skipping $objWebUrl (already unprotected)" -ForegroundColor Magenta
        return
    }
    if($objId -in $script:protectedIndex){
        $script:unprotectedIds["$objId"] = $true
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
        Write-Host "Unprotecting $objWebUrl"
        $null = api post -v2 "data-protect/protected-objects/actions?regionId=$region" $unprotectParams
    }
}

if($objectMatch){
    Write-Host "Finding sites with names starting with '$objectMatch'"
    $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kSite&regionIds=$region&sourceIds=$rootSourceId&count=999&isProtected=true&searchString=$([uri]::EscapeDataString($objectMatch))"
    $matchedCount = 0
    foreach($obj in @($search.objects | Where-Object {$_.name -and $_.name.StartsWith($objectMatch, [System.StringComparison]::OrdinalIgnoreCase)})){
        if($obj.sharepointParams.PSObject.Properties['isGroupSite'] -and $obj.sharepointParams.isGroupSite -eq $True){
            continue
        }elseif($obj.sharepointParams.PSObject.Properties['isTeamSite'] -and $obj.sharepointParams.isTeamSite -eq $True){
            continue
        }
        $matchedCount += 1
        $objectsToAdd = @($objectsToAdd + @{'name' = $obj.name; 'webUrl' = $obj.sharepointParams.siteWebUrl})
        indexObject($obj)
    }
    Write-Host "Found $matchedCount protected site(s) matching '$objectMatch'"
}

foreach($obj in $objectsToAdd){
    $objName = $obj.name
    $objWebUrl = $obj.webUrl
    $objId = $null
    if($objWebUrl -eq $null -or $objWebUrl -eq ''){
        continue
    }
    if($script:webUrlIndex.ContainsKey($objWebUrl)){
        $objId = $script:webUrlIndex[$objWebUrl]
    }else{
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kSite&regionIds=$region&sourceIds=$rootSourceId&count=999&searchString=$objName"
        $search.objects = $search.objects | Where-Object {$_.sharepointParams.siteWebUrl -eq $objWebUrl}
        foreach($obj in $search.objects){
            indexObject($obj)
        }

        if(@($search.objects).Count -lt 1 -or $search.objects -eq $null){
            Write-Host "Site $objName not found" -ForegroundColor Yellow
            continue
        }else{
            $objId = $script:webUrlIndex[$objWebUrl]
        }
    }
    if($objId -and $objId -in $script:protectedIndex){
        unprotectObject $objWebUrl $objId
    }elseif($objId -and $objId -notin $script:protectedIndex){
        Write-Host "Site $objWebUrl not protected" -ForegroundColor Magenta
    }else{
        Write-Host "Site $objWebUrl not found" -ForegroundColor Yellow
    }
}
