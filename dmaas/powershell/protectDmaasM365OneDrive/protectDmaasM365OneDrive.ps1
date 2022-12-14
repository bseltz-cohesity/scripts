# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,  # DMaaS region
    [Parameter(Mandatory = $True)][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$users,  # optional names of mailboxes protect
    [Parameter()][string]$userList = '',  # optional textfile of mailboxes to protect
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

if($usersToAdd.Count -eq 0){
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

$policy = (api get -mcmv2 data-protect/policies?types=DMaaSPolicy).policies | Where-Object name -eq $policyName
if(!$policy){
    write-host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}

# find O365 source
$rootSource = api get protectionSources/rootNodes?environments=kO365 | Where-Object {$_.protectionSource.name -eq $sourceName}
if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}
$source = api get "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false"
$usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$usersNode){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
}

$nameIndex = @{}
$smtpIndex = @{}
$unprotectedIndex = @()

$users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidOnedrive=true&allUnderHierarchy=false"
while(1){
    # implement pagination
    foreach($node in $users.nodes){
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
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
    $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidOnedrive=true&allUnderHierarchy=false&afterCursorEntityId=$cursor"
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

# find users
foreach($driveUser in $usersToAdd){
    $userId = $null
    if($smtpIndex.ContainsKey($driveUser)){
        $userId = $smtpIndex[$driveUser]
    }elseif($nameIndex.ContainsKey($driveUser)){
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
        $response = api post -v2 data-protect/protected-objects $protectionParams
    }elseif($userId -and $userId -notin $unprotectedIndex){
        Write-Host "OneDrive $driveUser already protected" -ForegroundColor Magenta
    }else{
        Write-Host "OneDrive for $driveUser not found" -ForegroundColor Yellow
    }
}
