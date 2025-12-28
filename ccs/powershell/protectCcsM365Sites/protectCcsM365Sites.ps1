# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$objectNames,  # optional names of sites protect
    [Parameter()][string]$objectList = '',  # optional textfile of sites to protect
    [Parameter()][string]$objectMatch,
    [Parameter()][int]$autoselect = 0,
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 1440,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 1440,  # full SLA minutes
    [Parameter()][int]$pageSize = 10000,
    [Parameter()][switch]$useMBS
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

$script:nameIndex = @{}
$script:webUrlIndex = @{}
$script:idIndex = @{}
$script:unprotectedIndex = @()
$script:protectedCount = 0
function getNodes($node){
    if($node.PSObject.Properties['nodes']){
        foreach($subnode in $node.nodes){
            getNodes($subnode)
        }
    }
    $script:nameIndex[$node.protectionSource.name] = $node.protectionSource.id
    $script:idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
    $script:webUrlIndex[$node.protectionSource.office365ProtectionSource.webUrl] = $node.protectionSource.id
    if(($node.unprotectedSourcesSummary | Where-Object environment -eq 'kO365Sharepoint').leavesCount -eq 1){
        $script:unprotectedIndex = @($script:unprotectedIndex + $node.protectionSource.id)
    }else{
        $script:protectedCount += 1
    }
}
Write-Host "Indexing Sites"
$objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false&regionId=$region" # -region $regionId
while(1){
    foreach($node in $objects.nodes){
        getNodes($node)
    }
    $cursor = $objects.nodes[-1].protectionSource.id
    $objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false&afterCursorEntityId=$cursor&regionId=$region" # -region $regionId
    if(!$objects.PSObject.Properties['nodes'] -or $objects.nodes.Count -eq 1){
        break
    }
}
# Write-Host $script:unprotectedIndex.Count

if($objectsToAdd.Count -eq 0){
    $useIds = $True
    if($objectMatch){
        $script:webUrlIndex.Keys | Where-Object {$_ -match $objectMatch -and $script:webUrlIndex[$_] -in $script:unprotectedIndex} | ForEach-Object{
            $objectsToAdd = @($objectsToAdd + $script:webUrlIndex[$_])
        }
        $script:nameIndex.Keys | Where-Object {$_ -match $objectMatch -and $script:webUrlIndex[$_] -in $script:unprotectedIndex} | ForEach-Object{
            $objectsToAdd = @($objectsToAdd + $script:nameIndex[$_])
        }
        $objectsToAdd = @($objectsToAdd | Sort-Object -Unique)
    }else{
        if($autoselect -gt $script:unprotectedIndex.Count){
            $autoselect = $script:unprotectedIndex.Count
        }
        0..($autoselect - 1) | ForEach-Object {
            $objectsToAdd = @($objectsToAdd + $script:unprotectedIndex[$_])
        }
    }
}

foreach($objName in $objectsToAdd){
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
    if($objId -and $objId -in $script:unprotectedIndex){
        $protectionParams = @{
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
        if($useMBS){
            $protectionParams.objects[0].environment = "kO365SharepointCSM"
        }else{
            $protectionParams.policyId = $policy.id
        }
        Write-Host "Protecting $objName"
        $null = api post -v2 "data-protect/protected-objects?regionIds=$region" $protectionParams
    }elseif($objId -and $objId -notin $script:unprotectedIndex){
        Write-Host "Site $objName already protected" -ForegroundColor Magenta
    }else{
        Write-Host "Site $objName not found" -ForegroundColor Yellow
    }
}
