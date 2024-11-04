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
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$tenant,
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

if($cloudArchiveDirect){
    $isCAD = $True
    $storageDomainName = 'Direct_Archive_Viewbox'
}else{
    $isCAD = $false
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -tenant $tenant

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit 1
}

# indexing
$disableIndexing = $True
if($enableIndexing){
    $disableIndexing = $false
}

# gather volume list from command-line and/or text file
$mountPaths = @()
foreach($v in $mountPath){
    $mountPaths += $v
}
if ($mountList){
    if(Test-Path -Path $mountList -PathType Leaf){
        $vlist = Get-Content $mountList
        foreach($v in $vlist){
            $mountPaths += $v
        }
    }else{
        Write-Warning "Volume list $mountList not found!"
        exit 1
    }
}

if($cloudArchiveDirect -and $mountPaths.Length -gt 1){
    Write-Host "Cloud Archive Direct jobs are limited to a single mountPoint" -ForegroundColor Yellow
    exit 1
}

# gather inclusion list
$includePaths = @()
foreach($inclusion in $inclusions){
    $includePaths += $inclusion
}
if('' -ne $inclusionList){
    if(Test-Path -Path $inclusionList -PathType Leaf){
        $inclusions = Get-Content $inclusionList
        foreach($inclusion in $inclusions){
            $includePaths += $inclusion
        }
    }else{
        Write-Warning "Inclusions file $inclusionList not found!"
        exit 1
    }
}
if($includePaths.Length -eq 0){
    $includePaths += '/'
}

# gather exclusion list
$excludePaths = @()
foreach($exclusion in $exclusions){
    $excludePaths += $exclusion
}
if('' -ne $exclusionList){
    if(Test-Path -Path $exclusionList -PathType Leaf){
        $exclusions = Get-Content $exclusionList
        foreach($exclusion in $exclusions){
            $excludePaths += [string]$exclusion
        }
    }else{
        Write-Warning "Exclusions file $exclusionList not found!"
        exit 1
    }
}
if($excludePaths.Length -eq 0){
    $excludePaths += '/.snapshot'
}

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
