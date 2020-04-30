### Usage:
# ./protectNetApp.ps1 -vip mycluster `
#                     -username myuser `
#                     -domain mydomain.net `
#                     -policyName 'My Policy' `
#                     -jobName 'My New Job' `
#                     -timeZone 'America/New_York' `
#                     -enableIndexing `
#                     -netappSource mynetapp `
#                     -volumeName vol2 `
#                     -cloudArchiveDirect

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
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
    [Parameter(Mandatory = $True)][string]$netappSource, # name of registered netapp entity
    [Parameter()][array]$volumeName, # names of volumes to protect
    [Parameter()][string]$volumeList = $null, # text file of volumes to protect
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
apiauth -vip $vip -username $username -domain $domain

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
}

# indexing
$disableIndexing = $True
if($enableIndexing){
    $disableIndexing = $false
}

# gather volume list from command-line and/or text file
$volumes = @()
foreach($v in $volumeName){
    $volumes += $v
}
if ($volumeList){
    if(Test-Path -Path $volumeList -PathType Leaf){
        $vlist = Get-Content $volumeList
        foreach($v in $vlist){
            $volumes += $v
        }
    }else{
        Write-Warning "Volume list $volumeList not found!"
        exit 1
    }
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
        exit
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
            $excludePaths += $exclusion
        }
    }else{
        Write-Warning "Exclusions file $exclusionList not found!"
        exit
    }
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

# get policy ID
$policy = api get protectionPolicies | Where-Object { $_.name -ieq $policyName }
if(!$policy){
    Write-Warning "Policy $policyName not found!"
    exit
}

# get Netapp Id
$sources = api get "protectionSources?environments=kNetapp"
$netapp = $sources | Where-Object {$_.protectionSource.name -eq $netappSource}
if(! $netapp){
    Write-Host "Netapp $netappSource not a registered source" -ForegroundColor Yellow
    exit
}
$parentId = $netapp.protectionSource.id

# get volume IDs
$sourceIds = @()
if($volumes.Length -gt 0){
    if($cloudArchiveDirect -and $volumes.Length -gt 1){
        Write-Host "Cloud Archive Direct jobs are limited to a single volume" -ForegroundColor Yellow
        exit
    }
    $sourceVolumes = $netapp.nodes | Where-Object {$_.protectionSource.name -in $volumes}
    $sourceIds += $sourceVolumes.protectionSource.id
    $missingVolumes = $volumes | Where-Object {$sourceVolumes.protectionSource.name -notcontains $_}
    if($missingVolumes){
        Write-Host "Volumes ($($missingVolumes -join ', ')) not found" -ForegroundColor Yellow
        exit
    }
}elseif($cloudArchiveDirect){
    Write-Host "Cloud Archive Direct jobs are limited to a single volume" -ForegroundColor Yellow
    exit
}else{
    $sourceIds += $parentId
}

$jobParams = @{
    "name"                             = $jobName;
    "description"                      = "";
    "environment"                      = "kNetapp";
    "policyId"                         = $policy.id;
    "viewBoxId"                        = $viewBox.id;
    "parentSourceId"                   = $parentId;
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
            "nasProtocol"     = "kNfs3";
            "continueOnError" = $true;
            "filePathFilters" = @{
                "protectFilters" = $includePaths
            }
        }
    };
    "isDirectArchiveEnabled"           = $isCAD;
}
if($excludePaths.Length -gt 0){
    $jobParams.environmentParameters.nasParameters.filePathFilters.excludeFilters = $excludePaths
}
"Creating protection job $jobName..."
$null = api post protectionJobs $jobParams
