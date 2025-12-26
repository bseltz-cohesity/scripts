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
    [Parameter()][int]$pageSize = 1000,
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
apiauth -username $username

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

$script:nameIndex = @{}
$script:webUrlIndex = @{}
$script:idIndex = @{}
$script:unprotectedIndex = @()
$script:protectedCount = 0

function indexObject($obj){
    $script:nameIndex[$obj.name] = $obj.objectProtectionInfos[0].objectId
    $script:idIndex["$($obj.objectProtectionInfos[0].objectId)"] = $obj.name
    $script:webUrlIndex[$obj.sharepointParams.siteWebUrl] = $obj.objectProtectionInfos[0].objectId
    if(!$obj.objectProtectionInfos.objectBackupConfiguration){
        $script:unprotectedIndex = @($script:unprotectedIndex + $obj.objectProtectionInfos[0].objectId)
    }else{
        $script:protectedCount += 1
    }
}

function search($tail, $objName){
    $foundObject = $False
    $searchCount = 0
    while(1){
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kSite&sourceIds=$rootSourceId&regionIds=$region&count=$pageSize&paginationCookie=$($paginationCookie)$($tail)"
        foreach($obj in $search.objects){
            indexObject($obj)
            $searchCount += 1
            if($autoselect -and $searchCount -ge $autoselect){
                return $True
            }
        }
        if($objName){
            $search.objects = $search.objects | Where-Object {$_.name -eq $objName -or $_.sharepointParams.siteWebUrl -eq $objName}
            if($search.count -gt 0){
                $foundObject = $True
                return $True
            }
        }
        $paginationCookie = $search.paginationCookie
        if($search.paginationCookie -ge $search.count){
            break
        }
        if($autoselect -gt 0 -and $script:unprotectedIndex.Count -gt $autoselect){
            break
        }
    }
    if($objName -and $foundObject -eq $False){
        return $False
    }
    return $True
}

if($autoselect -gt 0 -and $pageSize -gt $autoselect){
    $pageSize = $autoselect
}
$paginationCookie = 0
Write-Host "Indexing Sites"
$tail = ''
if($autoselect -gt 0){
    $tail = '&isProtected=false'
}
if($objectMatch){
    $tail = "$tail&searchString=$objectMatch"
}
$search = search $tail
if($objectMatch){
    $useIds = $True
    $script:webUrlIndex.Keys | Where-Object {$_ -match $objectMatch -and $script:webUrlIndex[$_] -in $script:unprotectedIndex} | ForEach-Object{
        $objectsToAdd = @($objectsToAdd + $script:webUrlIndex[$_])
    }
    $script:nameIndex.Keys | Where-Object {$_ -match $objectMatch -and $script:webUrlIndex[$_] -in $script:unprotectedIndex} | ForEach-Object{
        $objectsToAdd = @($objectsToAdd + $script:nameIndex[$_])
    }
    $objectsToAdd = @($objectsToAdd | Sort-Object -Unique)
}elseif($autoselect -gt 0){
    $useIds = $True
    if($autoselect -gt $script:unprotectedIndex.Count){
        $autoselect = $script:unprotectedIndex.Count
    }
    0..($autoselect - 1) | ForEach-Object {
        $objectsToAdd = @($objectsToAdd + $script:unprotectedIndex[$_])
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
