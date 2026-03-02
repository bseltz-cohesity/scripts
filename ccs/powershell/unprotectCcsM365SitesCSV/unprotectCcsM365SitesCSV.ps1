# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter(Mandatory = $True)][string]$csvFile,
    [Parameter()][switch]$unprotectSubSites,
    [Parameter()][switch]$deleteSnapshots,
    [Parameter()][switch]$dbg
)

if($deleteSnapshots){
    $delSnaps = $True
}else{
    $delSnaps = $false
}

$objectsToAdd = Import-Csv -Path $csvFile # -Encoding utf8
if($objectsToAdd.Count -eq 0){
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
            if($node.protectedSourcesSummary[0].leavesCount -gt 0){
                $script:protectedIndex = @($script:protectedIndex + $node.protectionSource.id)
                unprotectObject $node.protectionSource.office365ProtectionSource.webUrl $node.protectionSource.id
            }else{
                Write-Host "Site $($node.protectionSource.office365ProtectionSource.webUrl) not protected" -ForegroundColor Magenta
                $script:unprotectedIndex = @($script:unprotectedIndex + $node.protectionSource.id)
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
        Write-Host "Unprotecting $objWebUrl"
        $null = api post -v2 "data-protect/protected-objects/actions?regionId=$region" $unprotectParams
    }
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
