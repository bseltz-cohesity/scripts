### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][array]$objectName,
    [Parameter()][int]$concurrency = 1,
    [Parameter()][int]$mounts = 1,
    [Parameter()][string]$fullBackupArgs = "",
    [Parameter()][string]$incrBackupArgs = "",
    [Parameter()][string]$logBackupArgs = "",
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter()][string]$policyName,
    [Parameter()][switch]$paused,
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD')][string]$qosPolicy = 'kBackupHDD'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($mcm){
    apiauth -vip $vip -username $username -domain $domain -helios -password $password
}else{
    if($useApiKey){
        apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password
    }
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

# get registered UDA source
$source = (api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kUDA").rootNodes | Where-Object {$_.rootNode.name -eq $sourceName}
if(!$source){
    Write-Host "UDA protection source '$sourceName' not found" -ForegroundColor Yellow
    exit
}

$sourceId = $source.rootNode.id
$sourceName = $source.rootNode.name

# get the protectionJob
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}
$newJob = $True
if($job){

    $newJob = $false
    $jobParams = $job[0]

}else{

    if($paused){
        $isPaused = $True
    }else{
        $isPaused = $false
    }

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit
    }
    if(! $policyName){
        Write-Host "-policyName is required when creating a new protection group" -ForegroundColor Yellow
        exit
    }
    $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
    if(!$policy){
        Write-Host "Policy $policyName not found" -ForegroundColor Yellow
        exit
    }
    
    # get storageDomain
    $viewBoxes = api get viewBoxes
    if($viewBoxes -is [array]){
            $viewBox = $viewBoxes | Where-Object { $_.name -ieq $storageDomainName }
            if (!$viewBox) { 
                write-host "Storage domain $storageDomainName not Found" -ForegroundColor Yellow
                exit
            }
    }else{
        $viewBox = $viewBoxes[0]
    }

    $jobParams = @{
        "policyId" = $policy.id;
        "startTime" = @{
            "hour"     = [int]$hour;
            "minute"   = [int]$minute;
            "timeZone" = $timeZone
        };
        "priority" = "kMedium";
        "sla" = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes"    = $fullSlaMinutes
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes"    = $incrementalSlaMinutes
            }
        );
        "qosPolicy" = $qosPolicy;
        "storageDomainId" = $viewBox.id;
        "name" = $jobName;
        "environment" = "kUDA";
        "isPaused" = $isPaused;
        "description" = "";
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "udaParams" = @{
            "sourceId" = $sourceId;
            "objects" = @();
            "concurrency" = $concurrency;
            "mounts" = $mounts;
            "fullBackupArgs" = $fullBackupArgs;
            "incrBackupArgs" = $incrBackupArgs;
            "logBackupArgs" = $logBackupArgs
        }
    }

    if($objectName.Count -eq 0){
        $objectName = @($sourceName)
    }
}

foreach($o in $objectName){
    $jobParams.udaParams.objects = @($jobParams.udaParams.objects + @{"name" = $o})
}

if($newJob -eq $True){
    "Creating protection job '$jobName'..."
    $null = api post -v2 "data-protect/protection-groups" $jobParams
}else{
    "Updating protection job '$jobName'..."
    $null = api put -v2 "data-protect/protection-groups/$($job[0].id)" $jobParams
}
