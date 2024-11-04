### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # do not prompt for password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter(Mandatory = $True)][string]$sourceName, # name of registered Isilon entity
    [Parameter()][array]$zoneNames, # one or more SVM names to protect
    [Parameter()][array]$volumeName, # names of volumes to protect
    [Parameter()][string]$volumeList = $null, # text file of volumes to protect
    [Parameter()][switch]$includeRootIfs,
    [Parameter()][array]$excludeVolumeName, # volume exclude strings
    [Parameter()][string]$excludeVolumeList = $null, # text file of volume exclude strings
    [Parameter()][array]$inclusions, # optional paths to include (comma separated)
    [Parameter()][string]$inclusionList,  # optional list of inclusions in file
    [Parameter()][array]$exclusions,  # optional paths to exclude (comma separated)
    [Parameter()][string]$exclusionList,  # optional list of exclusions in a file
    [Parameter()][string]$policyName, # policy to use for the new job
    [Parameter(Mandatory = $True)][string]$jobName, # name for the new job
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins = 60,
    [Parameter()][int]$fullProtectionSlaTimeMins = 120,
    [Parameter()][switch]$enableIndexing, # disabled by default
    [Parameter()][switch]$cloudArchiveDirect, # set new job to use cloud archive direct
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain', #storage domain you want the new job to write to
    [Parameter()][switch]$paused,
    [Parameter()][switch]$encrypted,
    [Parameter()][string]$incrementalsnapshotprefix,
    [Parameter()][string]$fullsnapshotprefix,
    [Parameter()][switch]$useChangelist
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

$volumes = @(gatherList -Param $volumeName -FilePath $volumeList -Name 'volumes' -Required $False)
$includePaths = @(gatherList -Param $inclusions -FilePath $inclusionList -Name 'include paths' -Required $False)
$excludePaths = @(gatherList -Param $exclusions -FilePath $exclusionList -Name 'exclude paths' -Required $False)
$volumeExclusions = @(gatherList -Param $excludeVolumeName -FilePath $excludeVolumeList -Name 'volume exclusions' -Required $False)

if(!$includeRootIfs){
    $volumeExclusions = @($volumeExclusions + '/ifs')
}

if($cloudArchiveDirect){
    $isCAD = $True
}else{
    $isCAD = $false
}

if($paused){
    $isPaused = $True
}else{
    $isPaused = $false
}

if($encrypted){
    $isEncrypted = $True
}else{
    $isEncrypted = $false
}

if($useChangelist){
    $changeList = $True
}else{
    $changeList = $false
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
}

# indexing
$indexing = $false
if($enableIndexing){
    $indexing = $True
}

# get Isilon Id
$sources = api get "protectionSources?environments=kIsilon"
$isilon = $sources | Where-Object {$_.protectionSource.name -eq $sourceName}
if(! $isilon){
    Write-Host "Isilon $sourceName not a registered source" -ForegroundColor Yellow
    exit
}
$parentId = $isilon.protectionSource.id

# get object IDs to protect
$objectIds = @()
$foundVolumes = @()
foreach($zone in $isilon.nodes){
    if($zoneNames.Count -eq 0 -or $zone.protectionSource.name -in $zoneNames){
        foreach($volume in $zone.nodes){
            $thisVolumeName = $volume.protectionSource.name
            if(($volumes.Count -eq 0 -or $thisVolumeName -in $volumes) -and ($thisVolumeName -notin $volumeExclusions)){
                $objectIds = @($objectIds + $volume.protectionSource.id)
                $foundVolumes = @($foundVolumes + $volume.protectionSource.name)
            }
        }
    }
}

# warn on missing volumes
foreach($volumeName in $volumes){
    if($volumeName -notin $foundVolumes){
        Write-Host "volume $volumeName not found" -ForegroundColor Yellow
        exit
    }
}

# get job info
$newJob = $false

$jobs = api get -v2 'data-protect/protection-groups?environments=kIsilon&isDeleted=false&isActive=true'
$job = $jobs.protectionGroups | Where-Object {$_.name -eq $jobName}

if(!$job){
    $newJob = $True

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
    if(! $policyName){
        Write-Host "-policyName is required for new protection job" -ForegroundColor Yellow
        exit 1
    }
    $policy = api get protectionPolicies | Where-Object { $_.name -ieq $policyName }
    if(!$policy){
        Write-Warning "Policy $policyName not found!"
        exit 1
    }

    $job = @{
        "storageDomainId" = $viewBox.id
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
        "name" = $jobName;
        "environment" = "kIsilon";
        "isPaused" = $isPaused;
        "description" = "";
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "isilonParams" = @{
            "objects" = @();
            "directCloudArchive" = $isCAD;
            "nativeFormat" = $True;
            "indexingPolicy" = @{
                "enableIndexing" = $indexing;
                "includePaths" = @(
                    "/"
                );
                "excludePaths" = @()
            };
            "protocol" = "kNfs3";
            "continueOnError" = $true;
            "encryptionEnabled" = $isEncrypted;
            "useChangelist" = $changeList
        }
    }

    $job = $job | ConvertTo-Json -Depth 99 | ConvertFrom-Json

    Write-Host "`nCreating job $jobName`n"

}else{
    Write-Host "`nUpdating job $jobName`n"
    $job.isilonParams.useChangelist = $changeList
}

# add objects to job
$existingObjectIds = @($job.isilonParams.objects.id)
foreach($objectId in $objectIds){
    if($objectId -notin $existingObjectIds){
        $job.isilonParams.objects = @($job.isilonParams.objects + @{
            "id" = $objectId
        })
    }
}

if($includePaths.Count -gt 0 -or $excludePaths.Count -gt 0){
    if($includePaths.Count -eq 0){
        $includePaths = @('/')
    }
    if(! $job.isilonParams.PSObject.Properties['fileFilters']){
        setApiProperty -object $job.isilonParams -name 'fileFilters' -value @{}
    }
    if(! $job.isilonParams.fileFilters.PSObject.Properties['includeList']){
        setApiProperty -object $job.isilonParams.fileFilters -name 'includeList' -value @()
    }
    if(! $job.isilonParams.fileFilters.PSObject.Properties['excludeList']){
        setApiProperty -object $job.isilonParams.fileFilters -name 'excludeList' -value @()
    }
    foreach($includePath in $includePaths){
        $job.isilonParams.fileFilters.includeList = @($job.isilonParams.fileFilters.includeList + $includePath)
    }
    foreach($excludePath in $excludePaths){
        $job.isilonParams.fileFilters.excludeList = @($job.isilonParams.fileFilters.excludeList + $excludePath)
    }
}
if($newJob -eq $false -and $job.isilonParams.PSObject.Properties['fileFilters']){
    $job.isilonParams.fileFilters = $job.isilonParams.fileFilters | ConvertTo-Json -Depth 99 | ConvertFrom-Json
}

# update job
if($newJob -eq $True){
    $null = api post -v2 data-protect/protection-groups $job
}else{
    $null = api put -v2 data-protect/protection-groups/$($job.id) $job
}
