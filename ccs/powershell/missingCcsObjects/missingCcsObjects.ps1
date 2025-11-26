# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][string]$region,
    [Parameter()][string]$objectType,
    [Parameter()][int]$pageSize = 100,
    [Parameter()][switch]$unprotect,
    [Parameter()][switch]$deleteSnapshots
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

if($region){
    $sources = api get -mcmv2 "data-protect/sources?regionIds=$region&excludeProtectionStats=true"
}else{
    $sources = api get -mcmv2 "data-protect/sources?regionIds=$regionList&excludeProtectionStats=true"
}
$source = $sources.sources | Where-Object name -eq $sourceName
if(!$source){
    Write-Host "$sourceName not found" -ForegroundColor Yellow
    exit 1
}
if(!$region){
    $region = $source.sourceInfoList[0].regionId
}
$sourceId = $source.id

if($objectType){
    $missingObjects = api get -v2 "data-protect/search/objects?sourceUuids=$sourceId&searchString=*&regionIds=$region&onlyDeleted=true&isProtected=true&includeTenants=true&count=$pageSize&o365ObjectTypes=$objectType"
}else{
    $missingObjects = api get -v2 "data-protect/search/objects?sourceUuids=$sourceId&searchString=*&regionIds=$region&onlyDeleted=true&isProtected=true&includeTenants=true&count=$pageSize"
}

foreach($obj in $missingObjects.objects | Sort-Object -Property name){
    if($unprotect){
        $unprotectParams = @{
            "action" = "UnProtect";
            "objectActionKey" = $obj.environment;
            "unProtectParams" = @{
                "objects" = @(
                    @{
                        "id" = $obj.objectProtectionInfos[0].objectId;
                        "deleteAllSnapshots" = $false;
                        "forceUnprotect" = $true;
                        "disableExternalPITRForDDB" = $false
                    }
                )
            }
        }
        if($deleteSnapshots){
            $unprotectParams.unProtectParams.objects[0].deleteAllSnapshots = $True
        }
        if($obj.PSObject.Properties['objectType']){
            $unprotectParams.objectActionKey = "$($unprotectParams.objectActionKey)$($obj.objectType.Substring(1))"
        }
        if($unprotectParams.objectActionKey -eq "kO365Team"){
            $unprotectParams.objectActionKey = "kO365Teams"
        }
        if($obj.PSObject.Properties['objectType']){
            Write-Host "Unprotecting $($obj.name) ($($obj.objectType))"
        }else{
            Write-Host "Unprotecting $($obj.name) ($($obj.environment))"
        }
        $null = api post -v2 "data-protect/protected-objects/actions?regionId=$region" $unprotectParams
    }else{
        if($obj.PSObject.Properties['objectType']){
            Write-Host "$($obj.name) ($($obj.objectType))"
        }else{
            Write-Host "$($obj.name) ($($obj.environment))"
        }
    }
}
