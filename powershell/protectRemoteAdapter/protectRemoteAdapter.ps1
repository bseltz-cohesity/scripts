### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][string]$viewName,
    [Parameter()][string]$serverName,
    [Parameter()][string]$serverUser,
    [Parameter()][string]$policyName,
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][string]$timeZone = "America/New_York",
    [Parameter()][string]$startTime = '21:00',
    [Parameter()][string]$scriptPath,
    [Parameter()][string]$scriptParams = $null,
    [Parameter()][string]$logScriptPath = $null,
    [Parameter()][string]$logScriptParams = $null,
    [Parameter()][string]$fullScriptPath = $null,
    [Parameter()][string]$fullScriptParams = $null,
    [Parameter()][switch]$paused
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$policies = api get -v2 data-protect/policies
$views = api get -v2 "file-services/views?useCachedData=false&protocolAccesses=NFS,NFS4,S3"
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if(! $job){
    $newJob = $True

    if(! $policyName){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit 1
    }elseif(! $serverName){
        Write-Host "-serverName required" -ForegroundColor Yellow
        exit 1
    }elseif(! $serverUser){
        Write-Host "-serveruser required" -ForegroundColor Yellow
        exit 1
    }elseif(! $scriptPath){
        Write-Host "-scriptpath required" -ForegroundColor Yellow
        exit 1
    }elseif(! $viewName){
        Write-Host "-viewName required" -ForegroundColor Yellow
        exit 1
    }

    if($paused){
        $isPaused = $True
    }else{
        $isPaused = $false
    }

    # parse start time
    $hours, $minutes = $startTime.split(':')
    if(!($hours -match "^[\d\.]+$" -and $hours -in 0..23) -or !($minutes -match "^[\d\.]+$" -and $minutes -in 0..59)){
        write-host 'Start time is invalid' -ForegroundColor Yellow
        exit 1
    }

    $job = @{
        "name" = $jobName;
        "environment" = "kRemoteAdapter";
        "isPaused" = $isPaused;
        "policyId" = $policy.id;
        "priority" = "kMedium";
        "storageDomainId" = $sd.id;
        "description" = "";
        "startTime" = @{
            "hour" = [int]$hours;
            "minute" = [int]$minutes;
            "timeZone" = $timeZone
        };
        "abortInBlackouts" = $false;
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "sla" = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes" = $fullSlaMinutes
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes" = $incrementalSlaMinutes
            }
        );
        "remoteAdapterParams" = @{
            "hosts" = @(
                @{
                    "hostType" = "kLinux"
                }
            );
            "viewId" = $view.viewId;
            "indexingPolicy" = @{
                "enableIndexing" = $false;
                "includePaths" = @();
                "excludePaths" = @()
            };
            "remoteViewParams" = @{
                "createView" = $false
            }
        }
    }
    $job = $job | ConvertTo-Json -Depth 99 | ConvertFrom-JSON
}else{
    $newJob = $false
}

# get cluster public key
$sshInfo = api post -v2 clusters/ssh-public-key @{'workflowType' = 'DataProtection'}
if(! $sshInfo -or ! $sshInfo.PSObject.Properties['public_key']){
    Write-Host "failed to get cluster public key" -ForegroundColor Yellow
    exit 1
}
$publicKey = $sshInfo.public_key

if($newJob -eq $True){
    $job.remoteAdapterParams.hosts[0] = @{
        "hostname" = $serverName;
        "username" = $serverUser;
        "incrementalBackupScript" = @{
            "path" = $scriptPath;
            "params" = $scriptParams
        };
        "hostType" = "kLinux"
    }
}

if($serverName){
    $job.remoteAdapterParams.hosts[0].hostname = $serverName
}

if($serverUser){
    $job.remoteAdapterParams.hosts[0].username = $serverUser
}

if($scriptPath){
    $job.remoteAdapterParams.hosts[0].incrementalBackupScript.path = $scriptPath
}

if($scriptParams){
    $job.remoteAdapterParams.hosts[0].incrementalBackupScript.params = $scriptParams
}

if($policyName){
    $policy = $policies.policies | Where-Object name -eq $policyName
    if(! $policy){
        Write-Host "Policy $policyName not found" -ForegroundColor Yellow
        exit 1
    }
    $job.policyId = $policy.id
}else{
    $policy = $policies.policies | Where-Object {$_.id -eq $job.policyId}
}

if($policy.backupPolicy.regular.PSObject.Properties['fullBackups'] -and $policy.backupPolicy.regular.fullBackups.Count > 0){
    if(!$fullScriptPath){
        $fullScriptPath = $job.remoteAdapterParams.hosts[0].incrementalBackupScript.path
    }
    if(!$fullScriptParams){
        $fullScriptParams = $job.remoteAdapterParams.hosts[0].incrementalBackupScript.params
    }
    $job.remoteAdapterParams.hosts[0].fullBackupScript = @{
        "path" = $fullScriptPath;
        "params" = $fullScriptParams
    }
}

if($policy.backupPolicy.PSObject.Properties['log']){
    if(!$logScriptPath){
        $logScriptPath = $job.remoteAdapterParams.hosts[0].incrementalBackupScript.path
    }
    if(!$logScriptParams){
        $logScriptParams = $job.remoteAdapterParams.hosts[0].incrementalBackupScript.params
    }
    $job.remoteAdapterParams.hosts[0].logBackupScript = @{
        "path" = $logScriptPath;
        "params" = $logScriptParams
    }
}

if($viewName){
    $view = $views.views | Where-Object name -eq $viewName
    if (!$view){
        Write-Host "View $viewName not found" -ForegroundColor Yellow
        exit 1
    }
    if($newJob -eq $True){
        $job.storageDomainId = $view.storageDomainId
    }else{
        if($view.storageDomainId -ne $job.storageDomainId){
            Write-Host "Job $jobName and View $viewName are in different storage domains" -ForegroundColor Yellow
            exit 1
        }
    }
    $job.remoteAdapterParams.viewId = $view.viewId
}else{
    $view = $views.views | Where-Object viewId -eq $job.remoteAdapterParams.viewId
}

if($newJob -eq $True){
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}

Write-Host "`n PG Name: $jobName"
Write-Host "  Policy: $($policy.name)"
Write-Host "  Server: $($job.remoteAdapterParams.hosts[0].hostname)"
Write-Host "    User: $($job.remoteAdapterParams.hosts[0].username)"
Write-Host "  Script: $($job.remoteAdapterParams.hosts[0].incrementalBackupScript.path)"
Write-Host "    View: $($view.name)"

if($view.PSObject.Properties['nfsMountPath'] -and $view.nfsMountPath -ne $null){
     Write-Host "NFS Path: $($view.nfsMountPath)"
}
if($view.PSObject.Properties['s3AccessPath'] -and $view.s3AccessPath -ne $null){
    Write-Host " S3 Path: $($view.s3AccessPath)"
}

Write-Host "`nCluster Public Key:"
Write-Host "$publicKey`n"
