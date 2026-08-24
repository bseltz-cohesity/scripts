# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 1440,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 1440,  # full SLA minutes
    [Parameter()][int]$pageSize = 25000,
    [Parameter()][int]$searchBatchSize = 500,  # number of object ids to search for at a time
    [Parameter()][switch]$useMBS
)

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
apiauth -username $username # -regionid $region

if(! $useMBS){
    if($policyName -eq ''){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit
    }
    Write-Host "Finding Policy"
    $policy = (api get -mcmv2 "data-protect/policies?types=DMaaSPolicy&regionIds=$region").policies | Where-Object name -eq $policyName
    if(!$policy){
        write-host "Policy $policyName not found" -ForegroundColor Yellow
        exit
    }
}

# find O365 source
Write-Host "Finding M365 Protection Source"
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365&excludeProtectionStats=true&regionIds=$region").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false&regionId=$region" # -region $regionId
$objectsNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Sites'}
if(!$objectsNode){
    Write-Host "Source $sourceName is not configured for O365 Sites" -ForegroundColor Yellow
    exit
}

$script:idIndex = @()

function getNodes($node){
    if($node.PSObject.Properties['nodes']){
        foreach($subnode in $node.nodes){
            getNodes($subnode)
        }
    }
    if($node.protectionSource.office365ProtectionSource.siteInfo.isGroupSite -eq $True -or $node.protectionSource.office365ProtectionSource.siteInfo.isTeamSite -eq $True){
        continue
    }
    $script:idIndex = @($script:idIndex + $node.protectionSource.id)
}

Write-Host "Indexing Sites"
$x = 0
$objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false&regionId=$region&includeGroupAndTeamSite=false&pruneNonCriticalInfo=true&pruneAggregationInfo=true" # -region $regionId
while(1){
    foreach($node in $objects.nodes){
        getNodes($node)
    }
    $cursor = $objects.nodes[-1].protectionSource.id
    $objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false&afterCursorEntityId=$cursor&regionId=$region&includeGroupAndTeamSite=false&pruneNonCriticalInfo=true&pruneAggregationInfo=true" # -region $regionId
    if(!$objects.PSObject.Properties['nodes'] -or $objects.nodes.Count -eq 1){
        break
    }
    $x += $pageSize
    Write-Host "$x"
}

$script:idIndex = @($script:idIndex | Sort-Object -Unique)

# search (in batches) for these objects to see if any are already protected in another region
$script:alreadyProtected = @()

if(@($script:idIndex).Count -gt 0){
    Write-Host "Checking for sites already protected in other regions"
    for($i = 0; $i -lt $script:idIndex.Count; $i += $searchBatchSize){
        $lastIndex = [Math]::Min($i + $searchBatchSize - 1, $script:idIndex.Count - 1)
        $idBatch = @($script:idIndex[$i..$lastIndex])
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kSite&regionIds=$region&sourceIds=$rootSourceId&objectIds=$($idBatch -join ',')&count=$($idBatch.Count)"
        foreach($obj in $search.objects){
            $ownProtectionInfo = $obj.objectProtectionInfos | Where-Object {$_.regionId -eq $region -and $_.sourceId -eq $rootSourceId}
            if(!$ownProtectionInfo){
                continue
            }
            $protectedElsewhere = $obj.objectProtectionInfos | Where-Object {$_.regionId -ne $region -and $_.objectBackupConfiguration -ne $null -and @($_.objectBackupConfiguration).Count -gt 0}
            if(@($protectedElsewhere).Count -gt 0){
                $script:alreadyProtected = @($script:alreadyProtected + $ownProtectionInfo.objectId)
            }
        }
    }
}

$script:alreadyProtected = @($script:alreadyProtected | Sort-Object -Unique)

Write-Host "$(@($script:idIndex).Count) site(s) found, $(@($script:alreadyProtected).Count) already protected in another region"

$script:protectionParams = @{
    "policyId"         = "";
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
                            "id" = $objectsNode.protectionSource.id;
                            "shouldAutoProtectObject" = $True;
                            "excludeObjectIds" = @($script:alreadyProtected | Sort-Object)
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

if($useMBS){
    $protectionParams.objects[0].environment = "kO365SharepointCSM"
}else{
    $protectionParams.policyId = $policy.id
}

Write-Host "auto-protecting sites" # ($($objectsNode.protectionSource.id))"
# $protectionParams | toJson
$response = api post -v2 "data-protect/protected-objects?regionIds=$region" $protectionParams
$response | toJson
