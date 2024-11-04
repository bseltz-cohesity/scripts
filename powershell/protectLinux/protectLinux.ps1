# usage: ./protectPhysicalLinux.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt

# process commandline arguments
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
    [Parameter()][array]$servers,  # optional name of one server protect
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][array]$inclusions, # optional paths to exclude (comma separated)
    [Parameter()][string]$inclusionList = '',  # optional list of exclusions in file
    [Parameter()][array]$exclusions,  # optional name of one server protect
    [Parameter()][string]$exclusionList = '',  # required list of exclusions
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add server to
    [Parameter()][array]$skipNestedMountPointTypes = @(),  # 6.4 and above - skip listed mount point types
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
    [Parameter()][string]$preScript,
    [Parameter()][string]$preScriptArgs = '',
    [Parameter()][int]$preScriptTimeout = 900,
    [Parameter()][switch]$preScriptFail,
    [Parameter()][string]$postScript,
    [Parameter()][string]$postScriptArgs = '',
    [Parameter()][int]$postScriptTimeout = 900,
    [Parameter()][switch]$paused,
    [Parameter()][switch]$allLocalDrives
)

$continueOnError = $True
if($preScriptFail){
    $continueOnError = $false
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
            $serversToAdd += $server
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
            $includePaths += $inclusion
        }
    }else{
        Write-Warning "Inclusions file $inclusionList not found!"
        exit
    }
}
if(! $includePaths -and ! $allLocalDrives){
    $includePaths += '/'
}
if($allLocalDrives){
    $includePaths += '$ALL_LOCAL_DRIVES'
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

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# get the protectionJob
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kPhysical&names=$jobName"
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
                "globalExcludePaths" = $null
            }
        }
    }
    if($paused){
        $job.isPaused = $True
    }
    if($preScript -or $postScript){
        $job.physicalParams.fileProtectionTypeParams['prePostScript'] = @{}
        if($preScript){
            $job.physicalParams.fileProtectionTypeParams.prePostScript['preScript'] = @{
                "path" = $preScript;
                "params" = $preScriptArgs;
                "timeoutSecs" = $preScriptTimeout;
                "continueOnError" = $continueOnError
            }
        }
        if($postScript){
            $job.physicalParams.fileProtectionTypeParams.prePostScript['postScript'] = @{
                "path" = $postScript;
                "params" = $postScriptArgs;
                "timeoutSecs" = $postScriptTimeout
            }
        }
    }
}else{
    "Updating protection group..."
}

if($job.physicalParams.protectionType -ne 'kFile'){
    Write-Host "Job $jobName is not a file-based physical job!" -ForegroundColor Yellow
    exit
}

# get physical protection sources
$sources = api get protectionSources?environments=kPhysical

$sourceIds = [array]($job.physicalParams.fileProtectionTypeParams.objects.id)
$newSourceIds = @()

foreach($server in $serversToAdd | Where-Object {$_ -ne ''}){
    $server = $server.ToString()
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
        if($node.registrationInfo.refreshErrorMessage -or $node.registrationInfo.authenticationStatus -ne 'kFinished'){
            Write-Warning "$server has source registration errors"
        }else{
            if($node.protectionSource.physicalProtectionSource.hostType -ne 'kWindows'){
                $sourceId = $node.protectionSource.id
                $newSourceIds += $sourceId
            }else{
                Write-Warning "$server is a Windows host"
            }
        }
    }else{
        Write-Warning "$server is not a registered source"
    }
}

foreach($sourceId in @([array]$sourceIds + [array]$newSourceIds) | Sort-Object -Unique){
    if($allServers -or $sourceId -in $newSourceIds){
        $params = $job.physicalParams.fileProtectionTypeParams.objects | Where-Object id -eq $sourceId
        $node = $sources.nodes | Where-Object { $_.protectionSource.id -eq $sourceId }
        Write-Host "processing $($node.protectionSource.name)"
        if(($null -eq $params) -or $replaceRules){
            $params = @{
                "id" = $sourceId;
                "name" = $node.protectionSource.name;
                "filePaths" = @();
                "nestedVolumeTypesToSkip" = $null;
                "followNasSymlinkTarget" = $false
            } # "usesPathLevelSkipNestedVolumeSetting" = $true;
        }

        # skip nested mountpoint types
        if($sourceId -in $newSourceIds -or $replaceRules){
            if($skipNestedMountPointTypes.Count -gt 0){
                $params.nestedVolumeTypesToSkip = @($skipNestedMountPointTypes)
            } # $params.usesPathLevelSkipNestedVolumeSetting = $false
        }

        # set directive file path if new or replace
        if($metadataFile -ne '' -and $params.PSObject.Properties['Keys']){
            $params['metadataFilePath'] = $metadataFile
        }elseif($metadataFile -eq '' -and (! $params.PSObject.Properties['metadataFilePath'])){
            delApiProperty -object $params -name 'metadataFilePath'
            # process include rules
            foreach($includePath in $includePaths | Where-Object {$_ -ne ''} | Sort-Object -Unique){
                $includePath = $includePath.ToString()
                $filePath = $params.filePaths | Where-Object includedPath -eq $includePath
                if(($null -eq $filePath) -or $replaceRules){
                    $filePath = @{
                        "includedPath" = $includePath;
                        "excludedPaths" = @()
                    }
                }
                $params.filePaths = @($params.filePaths | Where-Object includedPath -ne $includePath) + $filePath
            }

            # process exclude rules
            foreach($excludePath in $excludePaths | Where-Object {$_ -and $_ -ne ''} | Sort-Object -Unique){
                $excludePath = $excludePath.ToString()
                $parentPath = $params.filePaths | Where-Object {$excludePath.contains($_.includedPath)} | Sort-Object -Property {$_.includedPath.Length} -Descending | Select-Object -First 1
                if($parentPath){
                    $parentPath.excludedPaths = @($parentPath.excludedPaths | Where-Object {$_ -ne $excludePath -and $_ -ne $null}) + $excludePath
                }else{
                    foreach($parentPath in $params.filePaths){
                        $parentPath.excludedPaths = @($parentPath.excludedPaths | Where-Object {$_ -ne $excludePath -and $_ -ne $null}) + $excludePath
                    }
                }
            }
        }

        # update params
        $job.physicalParams.fileProtectionTypeParams.objects = @($job.physicalParams.fileProtectionTypeParams.objects | Where-Object id -ne $sourceId) + $params
    }
}

if($True -eq $newJob){
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
