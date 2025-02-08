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

if($cloudArchiveDirect -and $mountPaths.Length -gt 1){
    Write-Host "Cloud Archive Direct jobs are limited to a single mountPoint" -ForegroundColor Yellow
    exit 1
}

if($cloudArchiveDirect){
    $isCAD = $True
    $storageDomainName = 'Direct_Archive_Viewbox'
}else{
    $isCAD = $false
}

# indexing
$disableIndexing = $True
if($enableIndexing){
    $disableIndexing = $false
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

# get policy ID
$policy = api get protectionPolicies | Where-Object { $_.name -ieq $policyName }
if(!$policy){
    Write-Warning "Policy $policyName not found!"
    exit 1
}

### get generic NAS mount points
$sources = api get protectionSources?environments=kGenericNas
$parentSourceId = $sources[0].protectionSource.id

$sourceIds = @()
foreach($mountPath in $mountPaths){
    $source = $sources.nodes | Where-Object {$_.protectionSource.name -eq $mountPath}
    if(! $source){
        Write-Host "Mount Path $mountPath is not registered in Cohesity" -ForegroundColor Yellow
        exit 1
    }
    $sourceIds += $source.protectionSource.id
}

# new or existing job
$job = api get protectionJobs | Where-Object {$_.name -eq $jobName -and $_.environment -eq 'kGenericNas'}
if(! $job){
    $jobParams = @{
        "name"                             = $jobName;
        "description"                      = "";
        "environment"                      = "kGenericNas";
        "policyId"                         = $policy.id;
        "viewBoxId"                        = $viewBox.id;
        "parentSourceId"                   = $parentSourceId;
        "sourceIds"                        = $sourceIds;
        "startTime"                        = @{
            "hour"   = [int]$hour;
            "minute" = [int]$minute
        };
        "timezone"                         = $timeZone;
        "incrementalProtectionSlaTimeMins" = $incrementalProtectionSlaTimeMins;
        "fullProtectionSlaTimeMins"        = $fullProtectionSlaTimeMins;
        "priority"                         = "kMedium";
        "alertingPolicy"                   = @(
            "kFailure"
        );
        "indexingPolicy"                   = @{
            "disableIndexing" = $disableIndexing;
            "allowPrefixes"   = @(
                "/"
            )
        };
        "abortInBlackoutPeriod"            = $false;
        "qosType"                          = "kBackupHDD";
        "environmentParameters"            = @{
            "nasParameters" = @{
                "continueOnError" = $true;
                "filePathFilters" = @{
                    "protectFilters" = $includePaths;
                    "excludeFilters" = $excludePaths
                }
            }
        };
        "isDirectArchiveEnabled"           = $isCAD;
    }
    
    "Creating protection job $jobName..."
    $null = api post protectionJobs $jobParams
}else{
    if($cloudArchiveDirect){
        Write-Host "Cloud Archive Direct jobs are limited to a single mountPoint" -ForegroundColor Yellow
        exit 1
    }
    "Updating protection job $jobName..."
    $job.sourceIds += $sourceIds | Sort-Object -Unique
    $null = api put protectionJobs/$($job.id) $job
}
exit 0
