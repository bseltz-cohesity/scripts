# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$objectNames,  # optional names of sites protect
    [Parameter()][string]$objectList = '',  # optional textfile of sites to protect
    [Parameter()][string]$objectMatch,
    [Parameter()][int]$autoselect = 0,
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 1440,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 1440,  # full SLA minutes
    [Parameter()][int]$pageSize = 50000
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
            exit 1
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit 1
    }
    return ($items | Sort-Object -Unique)
}

$objectsToAdd = @(gatherList -Param $objectNames -FilePath $objectList -Name 'sites' -Required $False)

if($objectsToAdd.Count -eq 0 -and $autoselect -eq 0 -and ! $objectMatch){
    Write-Host "No sites specified" -ForegroundColor Yellow
    exit
}

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

# $sessionUser = api get sessionUser
# $tenantId = $sessionUser.profiles[0].tenantId
# $regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
# $regionList = $regions.tenantRegionInfoList.regionId -join ','

$policy = (api get -mcmv2 data-protect/policies?types=DMaaSPolicy).policies | Where-Object name -eq $policyName
if(!$policy){
    write-host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}

# find O365 source
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

# $regionId = $rootSource[0].sourceInfoList[0].regionId
$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false" # -region $regionId

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
        if(($node.unprotectedSourcesSummary | Where-Object environment -eq 'kO365Sharepoint').leavesCount -eq 1){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        }
    }
    $cursor = $objects.nodes[-1].protectionSource.id
    $objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false&afterCursorEntityId=$cursor" # -region $regionId
    if(!$objects.PSObject.Properties['nodes'] -or $objects.nodes.Count -eq 1){
        break
    }
}

if($objectsToAdd.Count -eq 0){
    $useIds = $True
    if($objectMatch){
        $webUrlIndex.Keys | Where-Object {$_ -match $objectMatch -and $webUrlIndex[$_] -in $unprotectedIndex} | ForEach-Object{
            $objectsToAdd = @($objectsToAdd + $webUrlIndex[$_])
        }
        $nameIndex.Keys | Where-Object {$_ -match $objectMatch -and $webUrlIndex[$_] -in $unprotectedIndex} | ForEach-Object{
            $objectsToAdd = @($objectsToAdd + $nameIndex[$_])
        }
        $objectsToAdd = @($objectsToAdd | Sort-Object -Unique)
    }else{
        if($autoselect -gt $unprotectedIndex.Count){
            $autoselect = $unprotectedIndex.Count
        }
        0..($autoselect - 1) | ForEach-Object {
            $objectsToAdd = @($objectsToAdd + $unprotectedIndex[$_])
        }
    }
}

foreach($objName in $objectsToAdd){
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
    if($objId -and $objId -in $unprotectedIndex){
        $protectionParams = @{
            "policyId"         = $policy.id;
            "startTime"        = @{
                "hour"     = [int64]$hour;
                "minute"   = [int64]$minute;
                "timeZone" = $timeZone
            };
            "priority"         = "kMedium";
            "sla"              = @(
                @{
                    "backupRunType" = "kFull";
                    "slaMinutes"    = $fullSlaMinutes
                };
                @{
                    "backupRunType" = "kIncremental";
                    "slaMinutes"    = $incrementalSlaMinutes
                }
            );
            "qosPolicy"        = "kBackupSSD";
            "abortInBlackouts" = $false;
            "objects"          = @(
                @{
                    "environment" = "kO365Sharepoint";
                    "office365Params" = @{
                        "objectProtectionType"              = "kSharePoint";
                        "sharepointSiteObjectProtectionParams" = @{
                            "objects"        = @(
                                @{
                                    "id" = $objId;
                                    "shouldAutoProtectObject" = $false
                                }
                            );
                            "indexingPolicy" = @{
                                "enableIndexing" = $true;
                                "includePaths"   = @(
                                    "/"
                                );
                                "excludePaths"   = @()
                            }
                        }
                    }
                }
            )
        }
        Write-Host "Protecting $objName"
        $null = api post -v2 data-protect/protected-objects $protectionParams # -region $regionId
    }elseif($objId -and $objId -notin $unprotectedIndex){
        Write-Host "Site $objName already protected" -ForegroundColor Magenta
    }else{
        Write-Host "Site $objName not found" -ForegroundColor Yellow
    }
}
