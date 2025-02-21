# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][array]$servers,  # optional names of servers to protect (comma separated)
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][array]$inclusions, # optional paths to exclude (comma separated)
    [Parameter()][string]$inclusionList = '',  # optional list of exclusions in file
    [Parameter()][array]$exclusions, # optional paths to exclude (comma separated)
    [Parameter()][string]$exclusionList = '',  # optional list of exclusions in file
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add server to
    [Parameter()][switch]$skipNestedMountPoints,  # if omitted, nested mountpoints will not be skipped
    [Parameter()][switch]$followNasLinks,
    [Parameter()][switch]$allDrives,
    [Parameter()][switch]$replaceRules,
    [Parameter()][switch]$allServers,
    [Parameter()][string]$metadataFile = '',
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter()][string]$policyName,
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD')][string]$qosPolicy = 'kBackupHDD',
    [Parameter()][switch]$quiesce,
    [Parameter()][switch]$forceQuiesce,
    [Parameter()][switch]$allowParallelRuns
)

$ccb = $false
$cccb = $false
if($quiesce){
    $ccb = $True
    $cccb = $True
}
if($forceQuiesce){
    $ccb = $True
    $cccb = $false
}

# gather list of servers to add to job
$serversToAdd = @()
foreach($server in $servers){
    $serversToAdd += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $servers = Get-Content $serverList
        foreach($server in $servers){
            $serversToAdd += [string]$server
        }
    }else{
        Write-Warning "Server list $serverList not found!"
        exit
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
            $includePaths += [string]$inclusion
        }
    }else{
        Write-Warning "Inclusions file $inclusionList not found!"
        exit
    }
}
if(! $includePaths){
    if((! $allDrives) -and $metadataFile -eq ''){
        Write-Host "No include paths specified" -ForegroundColor Yellow
        exit 1
    }
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
        exit
    }
}

if($skipNestedMountPoints){
    $skip = $True
}else{
    $skip = $false
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# get cluster info
$cluster = api get cluster

if($cluster.clusterSoftwareVersion -lt '6.5.1'){
    Write-Host "This script is compatible with Cohesity 6.5.1 and later" -ForegroundColor Yellow
    exit
}

# get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true"
$job = $jobs.protectionGroups | Where-Object {$_.name -ieq $jobName}

$newJob = $false

if(!$job){
    "Creating new protection group..."
    $newJob = $True

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit
    }
    
    # policy
    if(!$policyName){
        Write-Host "-policyName required when creating new job" -ForegroundColor Yellow
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

    $job = @{
        "id" = $null;
        "name" = $jobName;
        "policyId" = $policy.id;
        "priority" = "kMedium";
        "storageDomainId" = $viewBox.id;
        "description" = "";
        "startTime" = @{
            "hour" = [int]$hour;
            "minute" = [int]$minute;
            "timeZone" = $timeZone
        };
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "sla" = @(
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes" = $incrementalSlaMinutes
            };
            @{
                "backupRunType" = "kFull";
                "slaMinutes" = $fullSlaMinutes
            }
        );
        "qosPolicy" = $qosPolicy;
        "abortInBlackouts" = $false;
        "isActive" = $true;
        "isPaused" = $false;
        "environment" = "kPhysical";
        "permissions" = @();
        "missingEntities" = $null;
        "physicalParams" = @{
            "protectionType" = "kFile";
            "fileProtectionTypeParams" = @{
                "allowParallelRuns" = $false
                "objects" = @();
                "indexingPolicy" = @{
                    "enableIndexing" = $true;
                    "includePaths" = @(
                        "/"
                    );
                    "excludePaths" = @(
                        '/$Recycle.Bin';
                        "/Windows";
                        "/Program Files";
                        "/Program Files (x86)";
                        "/ProgramData";
                        "/System Volume Information";
                        "/Users/*/AppData";
                        "/Recovery";
                        "/var";
                        "/usr";
                        "/sys";
                        "/proc";
                        "/lib";
                        "/grub";
                        "/grub2";
                        "/opt/splunk";
                        "/splunk"
                    )
                };
                "performSourceSideDeduplication" = $false;
                "dedupExclusionSourceIds" = $null;
                "globalExcludePaths" = $null;
                "quiesce" = $ccb;
                "continueOnQuiesceFailure" = $cccb
            }
        }
    }
}else{
    "Updating protection group..."
}

if($allowParallelRuns){
    $job.physicalParams.fileProtectionTypeParams.allowParallelRuns = $True
}

if($job.environment -ne 'kPhysical' -or $job.physicalParams.protectionType -ne 'kFile'){
    Write-Host "Job $jobName is not a file-based physical job!" -ForegroundColor Yellow
    exit
}

# get physical protection sources
$sources = api get protectionSources?environment=kPhysical

# add sourceIds for new servers
$sourceIds = @($job.physicalParams.fileProtectionTypeParams.objects.id)
$newSourceIds = @()
$sourceName = @{}

foreach($server in $serversToAdd | Where-Object {$_ -ne ''}){
    $server = $server.ToString()
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
        if($node.protectionSource.physicalProtectionSource.hostType -eq 'kWindows'){
            $sourceId = $node.protectionSource.id
            $sourceName[$sourceId] = $node.protectionSource.name
            $sourceIds += $sourceId
            $newSourceIds += $sourceId
        }else{
            Write-Warning "$server is not a Windows host"
        }
    }else{
        Write-Warning "$server is not a registered source"
    }
}

$sourceIds = @($sourceIds | Select-Object -Unique)

$existingParams = $job.physicalParams.fileProtectionTypeParams.objects
$newParams = @()
foreach($sourceId in $sourceIds){
    $node = $sources.nodes | Where-Object { $_.protectionSource.id -eq $sourceId }

    $newServer = $sourceId -in $newSourceIds

    $newParam = @{
        "id"                                   = $sourceId;
        "name"                                 = $node.protectionSource.name;
        "filePaths"                            = @();
        "usesPathLevelSkipNestedVolumeSetting" = $true;
        "nestedVolumeTypesToSkip"              = $null;
        "followNasSymlinkTarget"               = $false
    }

    if($followNasLinks){
        $newParam.followNasSymlinkTarget = $True
    }

    # get source mount points
    $source = $sources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}
    if($newServer -or $allServers){
        "  processing $($source.protectionSource.name)"
    }
    $mountPoints = $source.protectionSource.physicalProtectionSource.volumes.mountPoints | Where-Object {$_ -ne $null -and $_ -ne ''}

    $includePathsToProcess = @()
    $excludePathsToProcess = @()

    # get new include / exclude paths to process
    if($newServer -or $allServers){
        $includePathsToProcess = @($includePaths | Where-Object {$_ -ne $null -and $_ -ne ''})
        $excludePathsToProcess = @($excludePaths | Where-Object {$_ -ne $null -and $_ -ne ''})
    }

    # set directive file
    $theseParams = $existingParams | Where-Object {$_.id -eq $sourceId}
    if($metadataFile -ne '' -and ((! $theseParams) -or $replaceRules)){
        $newParam.metadataFilePath = $metadataFile
    }else{
        # get existing include / exclude paths
        if($theseParams){
            if(($newServer -and (! $replaceRules)) -or
            ((! $newServer) -and (! ($replaceRules -and $allServers)))){
                $excludePathsToProcess += $theseParams.filePaths.excludedPaths
                $includePathsToProcess += ($theseParams.filePaths.includedPath | Where-Object {$_ -ne '' -and $_ -ne $null})
                $newParam.followNasSymlinkTarget = $theseParams.followNasSymlinkTarget
                $newParam.usesPathLevelSkipNestedVolumeSetting = $theseParams.usesPathLevelSkipNestedVolumeSetting
                $newParam.nestedVolumeTypesToSkip = $theseParams.nestedVolumeTypesToSkip
            }
        }

        # process exclude paths
        $excludePathsProcessed = @()
        $wildCardExcludePaths = $excludePathsToProcess | Where-Object {$_ -ne $null -and $_.subString(0,2) -eq '*:'}
        $excludePathsToProcess = $excludePathsToProcess | Where-Object {$_ -notin $wildCardExcludePaths}
        foreach($wildCardExcludePath in $wildCardExcludePaths){
            foreach($mountPoint in $mountPoints){
                $excludePathsToProcess += "$($mountPoint):" + $wildCardExcludePath.subString(2)
            }
        }
        foreach($excludePath in $excludePathsToProcess){
        if($null -ne $excludePath -and $excludePath.subString(1,1) -eq ':'){
                $excludePath = "/$($excludePath.replace(':','').replace('\','/'))".replace('//','/')
        }
        if($null -ne $excludePath -and $excludePath -notin $excludePathsProcessed){
            $excludePathsProcessed += $excludePath
        }
        }
        # process include paths
        $includePathsProcessed = @()
        
        if($allDrives -or '$ALL_LOCAL_DRIVES' -in $includePathsToProcess){
            if($cluster.clusterSoftwareVersion -gt '6.5.1b'){
                $includePathsProcessed += '$ALL_LOCAL_DRIVES'
            }else{
                foreach($mountPoint in $mountPoints){
                    $includePathsProcessed += "/$($mountPoint.replace(':','').replace('\','/'))/".replace('//','/')
                }
            }
        }else{
            foreach($includePath in $includePathsToProcess){
                foreach($mountPoint in $mountPoints){
                    if(($includePath.split('\')[0] -eq $mountPoint.split('\')[0]) -or ($includePath.split('/')[1] -eq $mountPoint.split(':')[0])){
                        $includePathsProcessed = @($includePathsProcessed) + ,"/$($includePath.replace(':','').replace('\','/'))".replace('//','/')
                    }
                }
            }
        }
        foreach($includePath in $includePathsProcessed | Sort-Object -Unique){
            $newFilePath= @{
                "includedPath" = $includePath;
                "skipNestedVolumes" = $skip;
                "excludedPaths" = @()
            }
            foreach($excludePath in $excludePathsProcessed){
                if($excludePath -match $includePath -or $includePath -eq '$ALL_LOCAL_DRIVES' -or $excludePath[0] -ne '/'){
                    $newFilePath.excludedPaths += ,$excludePath
                }
            }
            $newParam.filePaths += ,$newFilePath
        }
    }

    if($newServer -or $allServers){
        $newParams += $newParam
    }else{
        $newParams += $theseParams
    }
}

# update job
$job.physicalParams.fileProtectionTypeParams.objects = $newParams

if($True -eq $newJob){
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
