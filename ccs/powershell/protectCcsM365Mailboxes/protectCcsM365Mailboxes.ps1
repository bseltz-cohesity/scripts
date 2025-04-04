# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$mailboxes,  # optional names of mailboxes protect
    [Parameter()][string]$mailboxList = '',  # optional textfile of mailboxes to protect
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][int]$autoselect = 0,
    [Parameter()][int]$pageSize = 50000,
    [Parameter()][array]$excludeFolders,
    [Parameter()][switch]$useSecurityGroups,
    [Parameter()][switch]$useMBS,
    [Parameter()][int]$maxToProtect = 0
)

# gather list of mailboxes to protect
$mailboxesToAdd = @()
foreach($mailbox in $mailboxes){
    $mailboxesToAdd += $mailbox
}
if ('' -ne $mailboxList){
    if(Test-Path -Path $mailboxList -PathType Leaf){
        $mailboxes = Get-Content $mailboxList
        foreach($mailbox in $mailboxes){
            $mailboxesToAdd += [string]$mailbox
        }
    }else{
        Write-Host "mailbox list $mailboxList not found!" -ForegroundColor Yellow
        exit
    }
}

$mailboxesToAdd = @($mailboxesToAdd | Where-Object {$_ -ne ''})

if($mailboxesToAdd.Count -eq 0 -and $autoselect -eq 0){
    Write-Host "No mailboxes specified" -ForegroundColor Yellow
    exit
}

$foldersToExclude = @()
foreach($excludeFolder in $excludeFolders){
    $foldersToExclude = @($foldersToExclude + $excludeFolder)
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

if(! $useMBS){
    if($policyName -eq ''){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit
    }
    $policy = (api get -mcmv2 data-protect/policies?types=DMaaSPolicy).policies | Where-Object name -eq $policyName
    if(!$policy){
        write-host "Policy $policyName not found" -ForegroundColor Yellow
        exit
    }
}


# find O365 source
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

# if(!$regionId){
#     $regionId = $rootSource[0].sourceInfoList[0].regionId
# }
$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false"  # -region $regionId

if($useSecurityGroups){
    $usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Groups'}
    if(!$usersNode){
        Write-Host "Source $sourceName is not configured for O365 Groups" -ForegroundColor Yellow
        exit
    }
}else{
    $usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
    if(!$usersNode){
        Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
        exit
    }
}

$nameIndex = @{}
$smtpIndex = @{}
$idIndex = @{}
$unprotectedIndex = @()

if($useSecurityGroups){
    $users = api get "protectionSources?useCachedData=false&pruneNonCriticalInfo=false&pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&isSecurityGroup=true&id=$($usersNode.protectionSource.id)"
}else{
    $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false"  # -region $regionId
}

while(1){
    foreach($node in $users.nodes){
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $idIndex["$($node.protectionSource.id)"] = $node.protectionSource.name
        $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
        if(($node.unprotectedSourcesSummary | Where-Object environment -eq 'kO365Exchange').leavesCount -eq 1){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        }
    }
    $cursor = $users.nodes[-1].protectionSource.id
    if($useSecurityGroups){
        $users = api get "protectionSources?useCachedData=false&pruneNonCriticalInfo=false&pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&isSecurityGroup=true&id=$($usersNode.protectionSource.id)&afterCursorEntityId=$cursor"
    }else{
        $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false&afterCursorEntityId=$cursor"  # -region $regionId
    }
    if(!$users.PSObject.Properties['nodes'] -or $users.nodes.Count -eq 1){
        break
    }
}  

if($mailboxesToAdd.Count -eq 0){
    if($autoselect -gt $unprotectedIndex.Count){
        $autoselect = $unprotectedIndex.Count
    }
    0..($autoselect - 1) | ForEach-Object {
        $mailboxesToAdd = @($mailboxesToAdd + $idIndex["$($unprotectedIndex[$_])"])
    }
}

$protectedCount = 0
foreach($mailbox in $mailboxesToAdd){
    $userId = $null
    if($mailbox -ne $null -and $smtpIndex.ContainsKey($mailbox)){
        $userId = $smtpIndex[$mailbox]
    }elseif($mailbox -ne $null -and $nameIndex.ContainsKey($mailbox)){
        $userId = $nameIndex[$mailbox]
    }
    if($userId -and $userId -in $unprotectedIndex){
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
                    "environment" = "kO365Exchange";
                    "office365Params" = @{
                        "objectProtectionType"              = "kMailbox";
                        "userMailboxObjectProtectionParams" = @{
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
                            };
                            "excludeFolders" = $foldersToExclude;
                        }
                    }
                }
            )
        }
        if($useMBS){
            $protectionParams.objects[0].environment = "kO365ExchangeCSM"
        }else{
            $protectionParams.policyId = $policy.id
        }
        Write-Host "Protecting $mailbox"
        $null = api post -v2 data-protect/protected-objects $protectionParams  # -region $regionId
        $protectedCount += 1
        if($maxToProtect -gt 0 -and $protectedCount -ge $maxToProtect){
            Write-Host "-maxToProtect reached. Exiting..."
            exit
        }
    }elseif($userId -and $userId -notin $unprotectedIndex){
        if($foldersToExclude.Count -gt 0){
            $protectionParams = @{
                "environment" = "kO365Exchange";
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
                "office365Params" = @{
                    "objectProtectionType"              = "kMailbox";
                    "userMailboxObjectProtectionParams" = @{
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
                        };
                        "excludeFolders" = $foldersToExclude
                    }
                }
            }
            Write-Host "Updating $mailbox"
            $null = api put -v2 data-protect/protected-objects/$userId $protectionParams
        }else{
            Write-Host "Mailbox $mailbox already protected" -ForegroundColor Magenta
        }
    }else{
        Write-Host "Mailbox $mailbox not found" -ForegroundColor Yellow
    }
}
