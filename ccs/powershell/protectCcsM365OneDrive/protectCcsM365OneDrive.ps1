# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$users,  # optional names of mailboxes protect
    [Parameter()][string]$userList = '',  # optional textfile of mailboxes to protect
    [Parameter()][int]$autoselect = 0,
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][int]$pageSize = 1000
)

# gather list of mailboxes to protect
$usersToAdd = @()
foreach($driveUser in $users){
    $usersToAdd += $driveUser
}
if ('' -ne $userList){
    if(Test-Path -Path $userList -PathType Leaf){
        $users = Get-Content $userList
        foreach($driveUser in $users){
            $usersToAdd += [string]$driveUser
        }
    }else{
        Write-Host "mailbox list $userList not found!" -ForegroundColor Yellow
        exit
    }
}

$usersToAdd = @($usersToAdd | Where-Object {$_ -ne ''})

if($usersToAdd.Count -eq 0 -and $autoselect -eq 0){
    Write-Host "No mailboxes specified" -ForegroundColor Yellow
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

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false"  # -region $regionId
$usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$usersNode){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
}

$nameIndex = @{}
$smtpIndex = @{}
$idIndex = @{}
$unprotectedIndex = @()

$users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidOnedrive=true&allUnderHierarchy=false" # -region $regionId
while(1){
    # implement pagination
    foreach($node in $users.nodes){
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
        if($node.protectionSource.office365ProtectionSource.PSObject.Properties['primarySMTPAddress']){
            $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
        }
        if(($node.unprotectedSourcesSummary | Where-Object environment -eq 'kO365OneDrive').leavesCount -eq 1){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        }
    }
    $cursor = $users.entityPaginationParameters.beforeCursorEntityId
    if(! $cursor){
        break
    }
    $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidOnedrive=true&allUnderHierarchy=false&afterCursorEntityId=$cursor" # -region $regionId
    $newcursor = $users.entityPaginationParameters.beforeCursorEntityId
    if($newcursor -eq $cursor){
        break
    }
    Write-Host "$($nameIndex.Keys.Count) discovered"
}

# configure protection parameters
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
    "objects"          = @()
}

$usersAdded = 0

if($usersToAdd.Count -eq 0){
    if($autoselect -gt $unprotectedIndex.Count){
        $autoselect = $unprotectedIndex.Count
    }
    0..($autoselect - 1) | ForEach-Object {
        $usersToAdd = @($usersToAdd + $idIndex["$($unprotectedIndex[$_])"])
    }
}

# find users
foreach($driveUser in $usersToAdd){
    $userId = $null
    if($driveUser -ne $null -and $smtpIndex.ContainsKey($driveUser)){
        $userId = $smtpIndex[$driveUser]
    }elseif($driveUser -ne $null -and $nameIndex.ContainsKey($driveUser)){
        $userId = $nameIndex[$driveUser]
    }
    if($userId -and $userId -in $unprotectedIndex){
        $protectionParams.objects = @(@{
            "environment"     = "kO365OneDrive";
            "office365Params" = @{
                "objectProtectionType"              = "kOneDrive";
                "userOneDriveObjectProtectionParams" = @{
                    "objects"        = @(
                        @{
                            "id" = $userId
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
        })
        Write-Host "Protecting OneDrive for $driveUser"
        $response = api post -v2 data-protect/protected-objects $protectionParams  # -region $regionId
    }elseif($userId -and $userId -notin $unprotectedIndex){
        Write-Host "OneDrive $driveUser already protected" -ForegroundColor Magenta
    }else{
        Write-Host "OneDrive for $driveUser not found" -ForegroundColor Yellow
    }
}
