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
    [Parameter()][int]$fullSlaMinutes = 120  # full SLA minutes
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
$source = (api get protectionSources?environments=kO365) | Where-Object {$_.protectionSource.name -eq $sourceName}
if(!$source){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}
$usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$users){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
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
$environmentMap = @{'Mailbox' = 'kO365Exchange'; 'OneDrive' = 'kO365OneDrive'}
# find mailboxes
foreach($driveUser in $usersToAdd){
    $user = $usersNode.nodes | Where-Object {$_.protectionSource.name -eq $driveUser -or $_.protectionSource.office365ProtectionSource.primarySMTPAddress -eq $driveUser}
    if($user){
        $protectionParams.objects = @(@{
            "environment"     = "kO365OneDrive";
            "office365Params" = @{
                "objectProtectionType"              = "kOneDrive";
                "userOneDriveObjectProtectionParams" = @{
                    "objects"        = @(
                        @{
                            "id" = $user.protectionSource.id
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
    }else{
        Write-Host "OneDrive for $driveUser not found" -ForegroundColor Yellow
    }
}
