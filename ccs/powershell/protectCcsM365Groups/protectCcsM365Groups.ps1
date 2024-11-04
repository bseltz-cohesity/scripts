# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$objectNames,  # optional names of sites protect
    [Parameter()][string]$objectList = '',  # optional textfile of sites to protect
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 1440,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 1440,  # full SLA minutes
    [Parameter()][int]$autoselect = 0,
    [Parameter()][int]$pageSize = 50000,
    [Parameter()][string]$logPath = '.'
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

$objectsToAdd = @(gatherList -Param $objectNames -FilePath $objectList -Name 'groups' -Required $False)

if($objectsToAdd.Count -eq 0 -and $autoselect -eq 0){
    Write-Host "No groups specified" -ForegroundColor Yellow
    exit 1
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

$logFile = $(Join-Path -Path $logPath -ChildPath "m365GroupsProtected.txt")

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

$objectsNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Groups'}
if(!$objectsNode){
    Write-Host "Source $sourceName is not configured for O365 Groups" -ForegroundColor Yellow
    exit
}

$nameIndex = @{}
$idIndex = @{}
$unprotectedIndex = @()
$objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false" # -region $regionId
while(1){
    foreach($node in $objects.nodes){
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
        if(($node.unprotectedSourcesSummary | Where-Object environment -eq 'kO365Group').leavesCount -eq 1){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        }
    }
    $cursor = $objects.nodes[-1].protectionSource.id
    $objects = api get "protectionSources?pageSize=$pageSize&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false&afterCursorEntityId=$cursor" # -region $regionId
    if(!$objects.PSObject.Properties['nodes'] -or $objects.nodes.Count -eq 1){
        break
    }
}

$useIds = $false
if($objectsToAdd.Count -eq 0){
    $useIds = $True
    if($autoselect -gt $unprotectedIndex.Count){
        $autoselect = $unprotectedIndex.Count
    }
    0..($autoselect - 1) | ForEach-Object {
        # $objectsToAdd = @($objectsToAdd + $idIndex["$($unprotectedIndex[$_])"])
        $objectsToAdd = @($objectsToAdd + $unprotectedIndex[$_])
    }
}

$scriptRunDate = get-date -UFormat '%Y-%m-%d %H-%M'

foreach($objName in $objectsToAdd){
    $objId = $null
    if($useIds -eq $True){
        $objId = $objName
        $objName = $idIndex["$objId"]
    }else{
        if($objName -ne $null -and $nameIndex.ContainsKey($objName)){
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
                    "environment" = "kO365Group";
                    "office365Params" = @{
                        "objectProtectionType"              = "kGroups";
                        "groupsObjectProtectionParams" = @{
                            "objects"        = @(
                                @{
                                    "id" = $objId;
                                }
                            )
                        }
                    }
                }
            )
        }
        Write-Host "Protecting $objName"
        "$($scriptRunDate): $objName protected" | Out-File -FilePath $logFile -Append
        $null = api post -v2 data-protect/protected-objects $protectionParams # -region $regionId
    }elseif($objId -and $objId -notin $unprotectedIndex){
        Write-Host "Group $objName already protected" -ForegroundColor Magenta
        "$($scriptRunDate): $objName already protected +++++" | Out-File -FilePath $logFile -Append
    }else{
        Write-Host "Group $objName not found" -ForegroundColor Yellow
        "$($scriptRunDate): $objName not found -----" | Out-File -FilePath $logFile -Append
    }
}
Write-Host "`nLog saved to $logFile`n"
