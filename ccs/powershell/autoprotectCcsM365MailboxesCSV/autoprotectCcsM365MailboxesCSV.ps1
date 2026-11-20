# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][string]$csvFile,  # CSV of mailboxes to exclude (columns: smtpAddress and/or name)
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 1440,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 1440,  # full SLA minutes
    [Parameter()][switch]$useMBS,
    [Parameter()][switch]$dbg
)

$objectsToAdd = @()
if($csvFile){
    $objectsToAdd = Import-Csv -Path $csvFile # -Encoding utf8
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

if($dbg){
    enableCohesityAPIDebugger
}

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

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false&regionId=$region" # -region $regionId
$objectsNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$objectsNode){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
}

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
            "environment" = "kO365Exchange";
            "office365Params" = @{
                "objectProtectionType"              = "kMailbox";
                "userMailboxObjectProtectionParams" = @{
                    "objects"        = @(
                        @{
                            "id" = $objectsNode.protectionSource.id;
                            "shouldAutoProtectObject" = $True;
                            "excludeObjectIds" = @()
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

# see if users node already protected
$script:updateExisting = $false
$existing = api get -v2 "data-protect/objects?ids=$($objectsNode.protectionSource.id)&regionIds=$region"

if($existing.PSObject.Properties['objects'] -and $existing.objects -ne $null -and @($existing.objects).Count -gt 0){
    $existingObject = $existing.objects[0]
    if($existingObject.PSObject.Properties['objectBackupConfiguration'] -and $existingObject.objectBackupConfiguration -ne $null){
        $script:updateExisting = $True
        $script:protectionParams = $existingObject.objectBackupConfiguration
        $script:protectionParams.environment = 'kO365Exchange'
        if($script:protectionParams.office365Params.userMailboxObjectProtectionParams.objects -eq $null){
            $script:protectionParams.office365Params.userMailboxObjectProtectionParams.objects = @(
                @{
                    "id" = $objectsNode.protectionSource.id;
                    "shouldAutoProtectObject" = $true;
                    "excludeObjectIds" = @()
                }
            )
        }
        # $script:protectionParams.office365Params.userMailboxObjectProtectionParams.objects[0].excludeObjectIds = @($script:protectionParams.office365Params.userMailboxObjectProtectionParams.objects[0].excludeObjectIds + 299299292)
    }
}

# returns the object protection params block (differs for new vs existing configuration)
function getMailboxParams(){
    if($script:updateExisting -eq $True){
        return $script:protectionParams.office365Params.userMailboxObjectProtectionParams
    }else{
        return $script:protectionParams.objects[0].office365Params.userMailboxObjectProtectionParams
    }
}

function addExclusion($objectId){
    $params = getMailboxParams
    $params.objects[0].excludeObjectIds = @($params.objects[0].excludeObjectIds + $objectId)
}

# remove existing exclusions whose mailboxes no longer exist (e.g. deleted from M365)
function removeInvalidExclusions(){
    $params = getMailboxParams
    $currentIds = @($params.objects[0].excludeObjectIds | Where-Object {$_ -ne $null} | Sort-Object -Unique)
    if($currentIds.Count -eq 0){
        return
    }
    Write-Host "Checking $($currentIds.Count) existing exclusions"

    # sanity check: the Users node must be retrievable, otherwise lookups are not trustworthy
    $control = api get -v2 "data-protect/objects?ids=$($objectsNode.protectionSource.id)&regionIds=$region" -quiet
    if(!($control -and $control.PSObject.Properties['objects'] -and @($control.objects).Count -gt 0)){
        Write-Host "Could not validate exclusions - skipping cleanup" -ForegroundColor Yellow
        return
    }

    $keepIds = @()
    foreach($excludedId in $currentIds){
        # look up each excluded object individually; a request containing a deleted id may fail as a whole
        $result = api get -v2 "data-protect/objects?ids=$excludedId&regionIds=$region" -quiet
        $match = $null
        if($result -and $result.PSObject.Properties['objects'] -and $result.objects){
            $match = @($result.objects) | Where-Object {"$($_.id)" -eq "$excludedId"} | Select-Object -First 1
        }
        $isDeleted = $match -and $match.PSObject.Properties['isDeleted'] -and $match.isDeleted -eq $True
        if($match -and -not $isDeleted){
            $keepIds += $excludedId
        }else{
            $reason = 'not found'
            if($isDeleted){
                $reason = 'marked deleted'
            }elseif($cohesity_api.last_api_error -and $cohesity_api.last_api_error -ne 'OK'){
                $reason = $cohesity_api.last_api_error
            }
            Write-Host "Removing exclusion for deleted mailbox (id $excludedId, $reason)" -ForegroundColor Cyan
        }
    }
    $params.objects[0].excludeObjectIds = @($keepIds)
}

if($script:updateExisting -eq $True){
    removeInvalidExclusions
}

$script:smtpIndex = @{}   # primary SMTP address (lowercase) -> object id
$script:nameIndex = @{}   # display name (lowercase) -> object id

function indexObject($obj){
    foreach($objectProtectionInfo in $obj.objectProtectionInfos | Where-Object {$_.regionId -eq $region -and $_.sourceId -eq $rootSourceId}){
        if($obj.name){
            $script:nameIndex[$obj.name.ToLower()] = $objectProtectionInfo.objectId
        }
        if($obj.PSObject.Properties['o365Params'] -and $obj.o365Params -and $obj.o365Params.primarySMTPAddress){
            $script:smtpIndex[$obj.o365Params.primarySMTPAddress.ToLower()] = $objectProtectionInfo.objectId
        }
    }
}

foreach($row in $objectsToAdd){
    # accept smtpAddress, email, or primarySMTPAddress for the address column; name for the display name
    $objSmtp = ''
    foreach($col in 'smtpAddress', 'email', 'primarySMTPAddress'){
        if($row.PSObject.Properties[$col] -and $row.$col){
            $objSmtp = $row.$col.Trim().ToLower()
            break
        }
    }
    $objName = ''
    if($row.PSObject.Properties['name'] -and $row.name){
        $objName = $row.name # .Trim()
    }
    if($objSmtp -eq '' -and $objName -eq ''){
        continue
    }

    $objId = $null
    if($objSmtp -ne '' -and $script:smtpIndex.ContainsKey($objSmtp)){
        $objId = $script:smtpIndex[$objSmtp]
    }elseif($objSmtp -eq '' -and $script:nameIndex.ContainsKey($objName.ToLower())){
        $objId = $script:nameIndex[$objName.ToLower()]
    }else{
        $searchString = $objName
        if($searchString -eq ''){
            $searchString = [uri]::EscapeDataString($objName)
        }
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kO365Exchange&regionIds=$region&sourceIds=$rootSourceId&count=999&searchString=$searchString"
        $found = @()
        if($search -and $search.PSObject.Properties['objects'] -and $search.objects){
            if($objSmtp -ne ''){
                $found = @($search.objects | Where-Object {$_.o365Params.primarySMTPAddress -and $_.o365Params.primarySMTPAddress.ToLower() -eq $objSmtp})
            }else{
                $found = @($search.objects | Where-Object {$_.name -eq $objName})
            }
        }
        foreach($foundObj in $found){
            indexObject $foundObj
        }
        if($found.Count -lt 1){
            Write-Host "Mailbox $objName ($objSmtp) not found" -ForegroundColor Yellow
            continue
        }
        if($objSmtp -ne ''){
            $objId = $script:smtpIndex[$objSmtp]
        }else{
            $objId = $script:nameIndex[$objName.ToLower()]
        }
    }
    if($objId){
        Write-Host "Excluding mailbox $objName ($objSmtp)"
        addExclusion $objId
    }
}

if($script:updateExisting -eq $false){
    if($useMBS){
        $script:protectionParams.objects[0].environment = "kO365ExchangeCSM"
    }else{
        $script:protectionParams.policyId = $policy.id
    }
}

# de-duplicate exclusions
$params = getMailboxParams
$params.objects[0].excludeObjectIds = @($params.objects[0].excludeObjectIds | Sort-Object -Unique)

if($script:updateExisting -eq $True){
    Write-Host "updating autoprotection"
    # $script:protectionParams | toJson
    $response = api put -v2 "data-protect/protected-objects/$($objectsNode.protectionSource.id)?regionIds=$region" $script:protectionParams
}else{
    Write-Host "auto-protecting mailboxes"
    $response = api post -v2 "data-protect/protected-objects?regionIds=$region" $script:protectionParams
    if($response.protectedObjects[0].PSObject.Properties['error']){
        Write-Host "$($response.protectedObjects[0].error)" -ForegroundColor Yellow
    }
}

$response | toJson