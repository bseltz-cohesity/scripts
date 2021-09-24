# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter()][string]$region,  # DMaaS region
    [Parameter(Mandatory = $True)][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][array]$mailboxes = '',  # optional names of mailboxes protect
    [Parameter()][string]$mailboxList = '',  # optional textfile of mailboxes to protect
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120  # full SLA minutes
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
            $mailboxesToAdd += $mailbox
        }
    }else{
        Write-Host "mailbox list $mailboxList not found!" -ForegroundColor Yellow
        exit
    }
}

if($mailboxesToAdd.Count -eq 0){
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
$users = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
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

$mailboxesAdded = 0

# find mailboxes
foreach($mailbox in $mailboxesToAdd){
    $user = $users.nodes | Where-Object {$_.protectionSource.name -eq $mailbox -or $_.protectionSource.office365ProtectionSource.primarySMTPAddress -eq $mailbox}
    if($user){
        $protectionParams.objects += @{
            "environment"     = "kO365";
            "office365Params" = @{
                "objectProtectionType"              = "kMailbox";
                "userMailboxObjectProtectionParams" = @{
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
        }
        Write-Host "Protecting $mailbox"
        $mailboxesAdded += 1
    }else{
        Write-Host "Mailbox $mailbox not found" -ForegroundColor Yellow
    }
}

if($mailboxesAdded -gt 0){
    $response = api post -v2 data-protect/protected-objects $protectionParams
    Write-Host "`nSuccessfully protected:`n"
    $response.protectedObjects | ForEach-Object{ "    {0}" -f $_.name }
    ""
}else{
    Write-Host "No mailboxes protected"
}
