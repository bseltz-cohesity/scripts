### Usage:
# ./protectGenericNas.ps1 -vip mycluster `
#                         -username myuser `
#                         -domain mydomain.net `
#                         -policyName 'My Policy' `
#                         -jobName 'My New Job' `
#                         -timeZone 'America/New_York' `
#                         -enableIndexing `
#                         -mountPath \\myserver\myshare `
#                         -cloudArchiveDirect

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
    [Parameter(Mandatory = $True)][string]$policyName, # policy to use for the new job
    [Parameter(Mandatory = $True)][string]$jobName, # name for the new job
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][array]$inclusions, # optional paths to include (comma separated)
    [Parameter()][string]$inclusionList,  # optional list of inclusions in file
    [Parameter()][array]$exclusions,  # optional paths to exclude (comma separated)
    [Parameter()][string]$exclusionList,  # optional list of exclusions in a file
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins = 60,
    [Parameter()][int]$fullProtectionSlaTimeMins = 120,
    [Parameter()][switch]$enableIndexing, # disabled by default
    [Parameter()][array]$mountPath, # names of volumes to protect
    [Parameter()][string]$mountList = $null, # text file of volumes to protect
    [Parameter()][switch]$cloudArchiveDirect, # set new job to use cloud archive direct
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain' #storage domain you want the new job to write to
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$mountPaths = @(gatherList -Param $mountPath -FilePath $mountList -Name 'mount paths' -Required $True)
$includePaths = @(gatherList -Param $inclusions -FilePath $inclusionList -Name 'mount paths' -Required $False)
$excludePaths = @(gatherList -Param $exclusions -FilePath $exclusionList -Name 'mount paths' -Required $False)

if($includePaths.Length -eq 0){
    $includePaths += '/'
}

if($excludePaths.Length -eq 0){
    $excludePaths += '/.snapshot'
}

if($cloudArchiveDirect){
    $isCAD = $True
    $storageDomainName = 'Direct_Archive_Viewbox'
}else{
    $isCAD = $false
}

# indexing
$indexingEnabled = $False
if($enableIndexing){
    $indexingEnabled = $True
}

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit 1
}

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

# get storageDomain
if($isCAD -eq $False){
    $viewBoxes = api get viewBoxes
    if($viewBoxes -is [array]){
            $viewBox = $viewBoxes | Where-Object { $_.name -ieq $storageDomainName }
            if (!$viewBox) { 
                write-host "Storage domain $storageDomainName not Found" -ForegroundColor Yellow
                exit 1
            }
    }else{
        $viewBox = $viewBoxes[0]
    }
    $viewBoxId = $viewBox.id
}else{
    $viewBoxId = $null
}

# get policy ID
$policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
if(!$policy){
    Write-Warning "Policy $policyName not found!"
    exit 1
}

### get generic NAS mount points
$sources = api get protectionSources?environments=kGenericNas
$parentSourceId = $sources[0].protectionSource.id

$objects = @()
$sourceIds = @()
foreach($mountPath in $mountPaths){
    $source = $sources.nodes | Where-Object {$_.protectionSource.name -eq $mountPath}
    if(! $source){
        Write-Host "Mount Path $mountPath is not registered in Cohesity" -ForegroundColor Yellow
        exit 1
    }
    $objects = @($objects + @{'id' = $source.protectionSource.id})
    $sourceIds += $source.protectionSource.id
}

# new or existing job
$job = (api get -v2 "data-protect/protection-groups?environments=kGenericNas").protectionGroups | Where-Object {$_.name -eq $jobName}
if(! $job){
    $jobParams = @{
        "policyId" = $policy.id;
        "startTime" = @{
            "hour" = [int]$hour;
            "minute" = [int]$minute;
            "timeZone" = $timeZone
        };
        "priority" = "kMedium";
        "sla" = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes" = $fullProtectionSlaTimeMins
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes" = $incrementalProtectionSlaTimeMins
            }
        );
        "qosPolicy" = "kBackupHDD";
        "abortInBlackouts" = $false;
        "pauseInBlackouts" = $false;
        "storageDomainId" = $viewBoxId;
        "name" = $jobName;
        "environment" = "kGenericNas";
        "isPaused" = $false;
        "description" = "";
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "genericNasParams" = @{
            "objects" = @($objects);
            "indexingPolicy" = @{
                "enableIndexing" = $indexingEnabled;
                "includePaths" = @(
                    "/"
                );
                "excludePaths" = @()
            };
            "protocol" = "kNfs3";
            "continueOnError" = $true;
            "fileFilters" = @{
                "includeList" = @($includePaths);
                "excludeList" = @($excludePaths)
            };
            "encryptionEnabled" = $false;
            "backupExistingSnapshot" = $true;
            "excludeObjectIds" = @()
        }
    }    
    "Creating protection job $jobName..."
    $null = api post -v2 "data-protect/protection-groups" $jobParams
}else{
    "Updating protection job $jobName..."
    $job.genericNasParams.objects = @($job.genericNasParams.objects | Where-Object {$_.id -notin $sourceIds})
    $job.genericNasParams.objects = @($job.genericNasParams.objects + $objects)
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
exit 0
