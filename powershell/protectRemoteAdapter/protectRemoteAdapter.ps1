### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobname,
    [Parameter(Mandatory = $True)][string]$viewname,
    [Parameter(Mandatory = $True)][string]$servername,
    [Parameter(Mandatory = $True)][string]$user,
    [Parameter(Mandatory = $True)][string]$policyname,
    [Parameter()][string]$storagedomain = 'DefaultStorageDomain',
    [Parameter()][string]$timezone = "America/New_York",
    [Parameter(Mandatory = $True)][string]$starttime,
    [Parameter(Mandatory = $True)][string]$scriptPath,
    [Parameter()][string]$scriptParams = $null,
    [Parameter()][string]$logScriptPath = $null,
    [Parameter()][string]$logScriptParams = $null,
    [Parameter()][string]$fullScriptPath = $null,
    [Parameter()][string]$fullScriptParams = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get policy
$policy = api get protectionPolicies | Where-Object {$_.name -ieq $policyname}
if(!$policy){
    Write-Host "Policy $policyname not found!" -ForegroundColor Yellow
    exit
}
if($policy.PSObject.Properties['logSchedulingPolicy']){
    if(!$logScriptPath){
        Write-Host "logScriptPath is required when using a log-enabled policy" -ForegroundColor Yellow
        exit
    }
}

# get storage domain
$sd = api get viewBoxes | Where-Object {$_.name -eq $storagedomain}
if(!$sd){
    Write-Host "Storage domain $storagedomain not found!" -ForegroundColor Yellow
    exit
}

# parse start time
$hours, $minutes = $starttime.split(':')
if(!($hours -match "^[\d\.]+$" -and $hours -in 0..23) -or !($minutes -match "^[\d\.]+$" -and $minutes -in 0..59)){
    write-host 'Start time is invalid' -ForegroundColor Yellow
    exit
}

# get view
$view = (api get views).views | Where-Object name -eq $viewname
if (!$view) {
    # create view
    $newView = @{
        "name"                          = $viewname;
        "category"                      = "FileServices";
        "protocolAccess"                = @(
            @{
                "type" = "NFS";
                "mode" = "ReadWrite"
            }
        );
        "storageDomainId"               = $sd.id;
        "storageDomainName"             = $sd.name;
        "qos"                           = @{
            "principalId"   = 6;
            "principalName" = "TestAndDev High"
        };
        "caseInsensitiveNamesEnabled"   = $false;
        "enableNfsViewDiscovery"        = $true;
        "securityMode"                  = "NativeMode";
        "overrideGlobalSubnetWhitelist" = $true
    }
    $view = api post -v2 "file-services/views" $newView
}

$myObject = @{
    "name"                = $jobname;
    "environment"         = "kRemoteAdapter";
    "isPaused"            = $false;
    "policyId"            = $policy.id;
    "priority"            = "kMedium";
    "storageDomainId"     = $sd.id;
    "description"         = "";
    "startTime"           = @{
        "hour"     = [int]$hours;
        "minute"   = [int]$minutes;
        "timeZone" = $timezone
    };
    "abortInBlackouts"    = $false;
    "alertPolicy"         = @{
        "backupRunStatus" = @(
            "kFailure"
        );
        "alertTargets"    = @()
    };
    "sla"                 = @(
        @{
            "backupRunType" = "kFull";
            "slaMinutes"    = 120
        };
        @{
            "backupRunType" = "kIncremental";
            "slaMinutes"    = 60
        }
    );
    "remoteAdapterParams" = @{
        "hosts"            = @(
            @{
                "hostname"                = $servername;
                "username"                = $user;
                "incrementalBackupScript" = @{
                    "path"   = $scriptPath;
                    "params" = $scriptParams
                };
                "hostType"                = "kLinux"
            }
        );
        "viewId"           = $view.viewId;
        "indexingPolicy"   = @{
            "enableIndexing" = $false;
            "includePaths"   = @();
            "excludePaths"   = @()
        };
        "remoteViewParams" = @{
            "createView" = $false
        }
    }
}

if($logScriptPath){
    $myObject.remoteAdapterParams.hosts[0]['logBackupScript'] = @{
        "path"   = $logScriptPath;
        "params" = $logScriptParams
    };
}

if($fullScriptPath){
    $myObject.remoteAdapterParams.hosts[0]['fullBackupScript'] = @{
        "path"   = $fullScriptPath;
        "params" = $fullScriptParams
    };
}

write-host "Creating remote adapter job..."
$null = api post -v2 "data-protect/protection-groups" $myObject