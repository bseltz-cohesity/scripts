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
    [Parameter(Mandatory = $True)][string]$netappSource, # name of registered netapp entity
    [Parameter()][array]$svmNames, # one or more SVM names to protect
    [Parameter()][array]$volumeName, # names of volumes to protect
    [Parameter()][string]$volumeList = $null, # text file of volumes to protect
    [Parameter()][array]$vexString, # volume exclude strings
    [Parameter()][string]$vexList = $null, # text file of volume exclude strings
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
    [Parameter()][string]$fullsnapshotprefix
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
$vexStrings = @(gatherList -Param $vexString -FilePath $vexList -Name 'volume exclude strings' -Required $False)

if($includePaths.Length -eq 0){
    $includePaths += '/'
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

# get Netapp Id
$sources = api get "protectionSources?environments=kNetapp"
$netapp = $sources | Where-Object {$_.protectionSource.name -eq $netappSource}
if(! $netapp){
    Write-Host "Netapp $netappSource not a registered source" -ForegroundColor Yellow
    exit
}
$parentId = $netapp.protectionSource.id

# gather SVMs
$svms = @()
if($netapp.protectionSource.netappProtectionSource.type -eq 'kVserver'){
    $svms = @($svms + $netapp)
}else{
    $svms = @($netapp.nodes)
}

$objectIds = @()
$foundVolumes = @()
$excludeObjectIDs = @()

function excludeVolumes($thissvm){
    $theseVolumeIds = @()
    foreach($volume in $thissvm.nodes){
        foreach($excluderule in $vexstrings){
            if($volume.protectionSource.name -match $excluderule){
                Write-Host "  excluding volume: $($volume.protectionSource.name)"
                $volumeId = $volume.protectionSource.id
                $theseVolumeIds = @($theseVolumeIds + $volumeId)
            }
        }
    }
    return $theseVolumeIds
}

if($volumes.Count -eq 0 -and $svmNames.Count -eq 0){
    # select entire source
    Write-Host "Protecting cluster: $($netapp.protectionSource.name)"
    $objectIds = @($objectIds + $netapp.protectionSource.id)
    # exclude volumes
    if($netapp.protectionSource.netappProtectionSource.type -eq 'kVserver'){
        $excludeObjectIDs = @($excludeObjectIDs + @(excludeVolumes $netapp))
    }else{
        foreach($svm in $svms){
            $excludeObjectIDs = @($excludeObjectIDs + @(excludeVolumes $svm))
        }
    }
}elseif($volumes.Count -eq 0){
    foreach($svmName in $svmNames){
        $svm = $svms | Where-Object {$_.protectionSource.name -eq $svmName}
        if(! $svm){
            Write-Host "SVM $svmName not found" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "    Protecting svm: $($svm.protectionSource.name)"
        $objectIds = @($objectIds + $svm.protectionSource.id)
        $excludeObjectIDs = @($excludeObjectIDs + @(excludeVolumes $svm))
    }
}else{
    foreach($svm in $svms){
        if($svmNames.Count -eq 0 -or $svm.protectionSource.name -in $svmNames){
            foreach($volume in $svm.nodes){
                if($volume.protectionSource.name -in $volumes){
                    Write-Host " Protecting volume: $($volume.protectionSource.name)"
                    $objectIds = @($objectIds + $volume.protectionSource.id)
                    $foundVolumes = @($foundVolumes + $volume.protectionSource.name)
                }
            }
        }
    }
}

# warn on missing volumes
foreach($volume in $volumes){
    if($volume -notin $foundVolumes){
        Write-Host "Volume $volume not found" -ForegroundColor Yellow
        exit 1
    }
}

# get job info
$newJob = $false

$jobs = api get -v2 'data-protect/protection-groups?environments=kNetapp&isDeleted=false&isActive=true'
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
        "environment" = "kNetapp";
        "isPaused" = $isPaused;
        "description" = "";
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "netappParams" = @{
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
            "backupExistingSnapshot" = $True;
            "excludeObjectIds" = @()
            "fileFilters" = @{
                "includeList" = @()
                "excludeList" = @()
            }
        }
    }

    if($incrementalsnapshotprefix -or $fullsnapshotprefix){
        if($incrementalsnapshotprefix -and ! $fullsnapshotprefix){
            $fullsnapshotprefix = $incrementalsnapshotprefix
        }
        if($fullsnapshotprefix -and ! $incrementalsnapshotprefix){
            $incrementalsnapshotprefix = $fullsnapshotprefix
        }
        $job.netappParams['snapshotLabel'] = @{
            "incrementalLabel" = $incrementalsnapshotprefix;
            "fullLabel" = $fullsnapshotprefix
        }
    }

    $job = $job | ConvertTo-Json -Depth 99 | ConvertFrom-Json

    Write-Host "`nCreating job $jobName`n"

}else{
    Write-Host "`nUpdating job $jobName`n"
}

# add objects to job
$existingObjectIds = @($job.netappParams.objects.id)
foreach($objectId in $objectIds){
    if($objectId -notin $existingObjectIds){
        $job.netappParams.objects = @($job.netappParams.objects + @{
            "id" = $objectId
        })
    }
}

if($includePaths.Count -gt 0 -or $excludePaths.Count -gt 0){
    if(! $job.netappParams.PSObject.Properties['fileFilters']){
        setApiProperty -object $job.netappParams -name 'fileFilters' -value @{}
    }
    if(! $job.netappParams.fileFilters.PSObject.Properties['includeList']){
        setApiProperty -object $job.netappParams.fileFilters -name 'includeList' -value @()
    }
    if(! $job.netappParams.fileFilters.PSObject.Properties['excludeList']){
        setApiProperty -object $job.netappParams.fileFilters -name 'excludeList' -value @()
    }
    foreach($includePath in $includePaths){
        $job.netappParams.fileFilters.includeList = @($job.netappParams.fileFilters.includeList + $includePath)
    }
    foreach($excludePath in $excludePaths){
        $job.netappParams.fileFilters.excludeList = @($job.netappParams.fileFilters.excludeList + $excludePath)
    }
}
if($newJob -eq $false){
    $job.netappParams.fileFilters = $job.netappParams.fileFilters | ConvertTo-Json -Depth 99 | ConvertFrom-Json
}

$job.netappParams.excludeObjectIds = @($job.netappParams.excludeObjectIds + $excludeObjectIDs | Sort-Object -Unique)

# update job
if($newJob -eq $True){
    $null = api post -v2 data-protect/protection-groups $job
}else{
    $null = api put -v2 data-protect/protection-groups/$($job.id) $job
}
