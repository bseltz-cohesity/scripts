# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter(Mandatory = $True)][string]$csvFile,
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 1440,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 1440,  # full SLA minutes
    [Parameter()][switch]$useMBS,
    [Parameter()][switch]$dbg
)

$objectsToAdd = Import-Csv -Path $csvFile # -Encoding utf8

if($objectsToAdd.Count -eq 0){
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
        if(@($obj.objectProtectionInfos.objectBackupConfiguration).Count -gt 0){
            $script:protectedCount += 1
        }else{
            $script:unprotectedIndex = @($script:unprotectedIndex + $obj.objectProtectionInfos[0].objectId)
        }
    }
}

foreach($obj in $objectsToAdd){
    $objName = $obj.name
    $objWebUrl = $obj.webUrl
    $objId = $null
    if($script:webUrlIndex.ContainsKey($objWebUrl)){
        $objId = $script:webUrlIndex[$objWebUrl]
    }else{
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kSite&sourceIds=$rootSourceId&regionIds=$region&count=9999&searchString=$objName"
        foreach($obj in $search.objects){
            indexObject($obj)
        }
        $search.objects = $search.objects | Where-Object {$_.sharepointParams.siteWebUrl -eq $objWebUrl}
        if(@($search.objects).Count -eq 0){
            Write-Host "Site $objName not found" -ForegroundColor Yellow
            continue
        }else{
            $objId = $search.objects[0].objectProtectionInfos[0].objectId
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
        Write-Host "Protecting $objWebUrl"
        $null = api post -v2 "data-protect/protected-objects?regionIds=$region" $protectionParams
    }elseif($objId -and $objId -notin $script:unprotectedIndex){
        Write-Host "Site $objWebUrl already protected" -ForegroundColor Magenta
    }else{
        Write-Host "Site $objWebUrl not found" -ForegroundColor Yellow
    }
}
