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
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][array]$serverName,
    [Parameter()][string]$serverList,
    [Parameter()][array]$instanceName,
    [Parameter()][array]$dbName,
    [Parameter()][string]$dbList,
    [Parameter()][ValidateSet('File','Volume','VDI')][string]$backupType = 'File',
    [Parameter()][switch]$instancesOnly,
    [Parameter()][switch]$systemDBsOnly,
    [Parameter()][string]$policyname,
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins = 60,
    [Parameter()][int]$fullProtectionSlaTimeMins = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain', #storage domain you want the new job to write to
    [Parameter()][switch]$paused,
    [Parameter()][int]$numStreams = 3,
    [Parameter()][string]$withClause = '',
    [Parameter()][int]$logNumStreams = 3,
    [Parameter()][string]$logWithClause = '',
    [Parameter()][switch]$unprotectedDBs,
    [Parameter()][switch]$sourceSideDeduplication,
    [Parameter()][switch]$allDBs,
    [Parameter()][switch]$replace,
    [Parameter()][ValidateSet('kPrimaryReplicaOnly', 'kSecondaryReplicaOnly', 'kPreferSecondaryReplica', 'kAnyReplica', 'kUseServerPreference')][string]$aagBackupPreference = 'kUseServerPreference'
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

$serversToAdd = @(gatherList -Param $serverName -FilePath $serverList -Name 'sources' -Required $False)
$dbsToAdd = @(gatherList -Param $dbName -FilePath $dbList -Name 'sources' -Required $False)

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

$systemDBs = @('master', 'model', 'msdb')

# root SQL source
$sources = api get "protectionSources/registrationInfo?environments=kSQL&includeApplicationsTreeInfo=false"
# $sources = api get protectionSources?environments=kSQL

# get the protectionJob
$job = (api get -v2 data-protect/protection-groups).protectionGroups | Where-Object name -eq $jobName
$newJob = $false

if(! $job){
    # create new job
    if($serversToAdd.Count -eq 0){
        Write-Host "No servers to add" -ForegroundColor Yellow
        exit
    }
    $newJob = $True

    if($paused){
        $isPaused = $True
    }else{
        $isPaused = $false
    }

    $backupTypeEnum = @{'File' = 'kFile'; 'Volume' = 'kVolume'; 'VDI' = 'kNative'}

    # get policy
    if(! $policyname){
        Write-Host "-policyname required when creating a new job" -ForegroundColor Yellow
        exit 1
    }
    $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
    if(! $policy){
        Write-Host "Policy $policyname not found!" -ForegroundColor Yellow
        exit 1
    }

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
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
                "slaMinutes" = $incrementalProtectionSlaTimeMins
            };
            @{
                "backupRunType" = "kFull";
                "slaMinutes" = $fullProtectionSlaTimeMins
            }
        );
        "qosPolicy" = "kBackupHDD";
        "abortInBlackouts" = $false;
        "isActive" = $true;
        "isPaused" = $isPaused;
        "environment" = "kSQL";
        "permissions" = @();
        "missingEntities" = $null;
        "mssqlParams" = @{
            "protectionType" = $backupTypeEnum[$backupType];
        }
    }
    
    if($backupType -eq 'File'){
        $job.mssqlParams['fileProtectionTypeParams'] = @{
            "objects" = @();
            "performSourceSideDeduplication" = $false;
            "additionalHostParams" = @();
            "userDbBackupPreferenceType" = "kBackupAllDatabases";
            "backupSystemDbs" = $true;
            "useAagPreferencesFromServer" = $true;
            "fullBackupsCopyOnly" = $false;
            "excludeFilters" = $null;
            "logBackupNumStreams" = $logNumStreams;
            "logBackupWithClause" = $logWithClause;
        }
        if($sourceSideDeduplication){
            $job.mssqlParams['fileProtectionTypeParams']['performSourceSideDeduplication'] = $True
        }
        $params = $job.mssqlParams.fileProtectionTypeParams
    }

    if($backupType -eq 'VDI'){
        $job.mssqlParams['nativeProtectionTypeParams'] = @{
            "objects" = @();
            "numStreams" = $numStreams;
            "withClause" = $withClause;
            "logBackupNumStreams" = $logNumStreams;
            "logBackupWithClause" = $logWithClause;
            "userDbBackupPreferenceType" = "kBackupAllDatabases";
            "backupSystemDbs" = $true;
            "useAagPreferencesFromServer" = $true;
            "fullBackupsCopyOnly" = $false;
            "excludeFilters" = $null
        }
        $params = $job.mssqlParams.nativeProtectionTypeParams
    }

    if($backupType -eq 'Volume'){
        $job.mssqlParams['volumeProtectionTypeParams'] = @{
            "objects" = @();
            "logBackupNumStreams" = $logNumStreams;
            "logBackupWithClause" = $logWithClause;
            "incrementalBackupAfterRestart" = $true;
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
            "backupDbVolumesOnly" = $false;
            "additionalHostParams" = @();
            "userDbBackupPreferenceType" = "kBackupAllDatabases";
            "backupSystemDbs" = $true;
            "useAagPreferencesFromServer" = $true;
            "fullBackupsCopyOnly" = $false;
            "excludeFilters" = $null
        }
        $params = $job.mssqlParams.volumeProtectionTypeParams
    }
    if($aagBackupPreference -ne 'kUseServerPreference'){
        $params['useAagPreferencesFromServer'] = $false
        $params['aagBackupPreferenceType'] = $aagBackupPreference
    }
}else{
    if($job.mssqlParams.protectionType -eq 'kFile'){
        $params = $job.mssqlParams.fileProtectionTypeParams
        setApiProperty -object $params -name 'logBackupNumStreams' -value $logNumStreams
        if($logWithClause -ne ''){
            setApiProperty -object $params -name 'logBackupWithClause' -value $logWithClause
        }
    }

    if($job.mssqlParams.protectionType -eq 'kNative'){
        $params = $job.mssqlParams.nativeProtectionTypeParams
        setApiProperty -object $params -name 'numStreams' -value $numStreams
        if($withClause -ne ''){
            setApiProperty -object $params -name 'withClause' -value $withClause
        }
        setApiProperty -object $params -name 'logBackupNumStreams' -value $logNumStreams
        if($logWithClause -ne ''){
            setApiProperty -object $params -name 'logBackupWithClause' -value $logWithClause
        }
    }

    if($job.mssqlParams.protectionType -eq 'kVolume'){
        $params = $job.mssqlParams.volumeProtectionTypeParams
        setApiProperty -object $params -name 'logBackupNumStreams' -value $logNumStreams
        if($logWithClause -ne ''){
            setApiProperty -object $params -name 'logBackupWithClause' -value $logWithClause
        }
    }
}

function clearSelection($thisSource){
    $params.objects = @(@($params.objects | Where-Object {$_.id -ne $thisSource.protectionSource.id}))
    if($thisSource.PSObject.Properties['applicationNodes']){
        foreach($instance in $thisSource.applicationNodes){
            $params.objects = @(@($params.objects | Where-Object {$_.id -ne $instance.protectionSource.id}))
            if($instance.PSObject.Properties['nodes']){
                foreach($node in $instance.nodes){
                    $params.objects = @(@($params.objects | Where-Object {$_.id -ne $node.protectionSource.id}))
                }
            }
        }
    }
    if($thisSource.PSObject.Properties['nodes']){
        foreach($node in $thisSource.nodes){
            $params.objects = @(@($params.objects | Where-Object {$_.id -ne $node.protectionSource.id}))
        }
    }
}

function addSelection($thisSource){
    $params.objects = @(@($params.objects | Where-Object {$_.id -ne $thisSource.protectionSource.id}) + @{'id' = $thisSource.protectionSource.id})
    if($thisSource.PSObject.Properties['applicationNodes']){
        foreach($instance in $thisSource.applicationNodes){
            $params.objects = @(@($params.objects | Where-Object {$_.id -ne $instance.protectionSource.id}))
            if($instance.PSObject.Properties['nodes']){
                foreach($node in $instance.nodes){
                    $params.objects = @(@($params.objects | Where-Object {$_.id -ne $node.protectionSource.id}))
                }
            }
        }
    }
    if($thisSource.PSObject.Properties['nodes']){
        foreach($node in $thisSource.nodes){
            $params.objects = @(@($params.objects | Where-Object {$_.id -ne $node.protectionSource.id}))
        }
    }
}

function isSelected($thisSource){
    $existingSelection = @(@($params.objects | Where-Object {$_.id -eq $thisSource.protectionSource.id}))
    if($existingSelection.Count -gt 0){
        return $True
    }else{
        return $false
    }
}

# server source
foreach($servername in $serversToAdd){
    $serverSourceRootNode = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $servername}
    # $serverSource = $sources[0].nodes | Where-Object {$_.protectionSource.name -eq $servername}
    if(! $serverSourceRootNode){
        Write-Host "Server $servername not found!" -ForegroundColor Yellow
        continue
    }
    $serverSource = api get "protectionSources?id=$($serverSourceRootNode.rootNode.id)"
    if($replace){
        clearSelection $serverSource
    }
    if($instanceName.Count -eq 0 -and $instancesOnly){
        Write-Host "Protecting $servername"
        foreach($instanceSource in $serverSource.applicationNodes){
            if(! $(isSelected $serverSource)){
                addSelection $instanceSource
            }
        }
    }elseif($instanceName.Count -gt 0 -and $dbsToAdd.Count -eq 0){
        foreach($instance in $instanceName){
            Write-Host "Protecting $servername/$instance"
            if(isSelected $serverSource){
                break
            }
            if($serverSource.PSObject.Properties['nodes']){
                # 7.3 AAG
                $instanceSource = $serverSource.nodes | Where-Object {$_.protectionSource.name -eq $instance}
            }else{
                $instanceSource = $serverSource.applicationNodes | Where-Object {$_.protectionSource.name -eq $instance}
            }
            if(! $instanceSource){
                Write-Host "Instance $instance not found on server $servername"
                exit
            }else{
                if($systemDBsOnly -and ! $(isSelected $instanceSource)){
                    foreach($node in $instanceSource.nodes){
                        if(($node.protectionSource.name -split '/')[1] -in $systemDBs){
                            addSelection $node
                        }
                    }
                }elseif($allDBs -and ! $(isSelected $instanceSource)){
                    foreach($node in $instanceSource.nodes){
                        addSelection $node
                    }
                }else{
                    if(! $(isSelected $serverSource)){
                        addSelection $instanceSource
                    }
                }
            }
        }
    }else{
        if($systemDBsOnly){
            foreach($instanceSource in $serverSource.applicationNodes){
                foreach($node in $instanceSource.nodes){
                    if(($node.protectionSource.name -split '/')[1] -in $systemDBs){
                        if(! $(isSelected $serverSource) -and ! $(isSelected $instanceSource)){
                            addSelection $node
                        }
                        Write-Host "Protecting $servername System DBs"
                    }
                }
            }
        }elseif($unprotectedDBs){
            foreach($instanceSource in $serverSource.applicationNodes){
                foreach($node in $instanceSource.nodes){
                    if($node.unprotectedSourcesSummary[0].leavesCount -eq 1){
                        addSelection $node
                        Write-Host "Protecting $servername"
                    }
                }
            }
        }elseif($allDBs -and $instanceName.Count -gt 0){
            foreach($instanceSource in $serverSource.applicationNodes | Where-Object {$_.protectionSource.name -in $instanceName}){
                foreach($dbSource in $instanceSource.nodes){
                    if(! $(isSelected $serverSource) -and ! $(isSelected $instanceSource)){
                        Write-Host "hi"
                        addSelection $dbSource
                    }
                }
            }
        }elseif($allDBs){
            foreach($instanceSource in $serverSource.applicationNodes){
                foreach($dbSource in $instanceSource.nodes){
                    if(! $(isSelected $serverSource) -and ! $(isSelected $instanceSource)){
                        addSelection $dbSource
                    }
                }
            }
        }elseif($dbsToAdd.Count -gt 0){
            if($instanceName.Count -eq 0){
                $instanceName = @('MSSQLSERVER')
            }
            foreach($instanceSource in $serverSource.applicationNodes | Where-Object {$_.protectionSource.name -in $instanceName}){
                foreach($thisDBName in $dbsToAdd){
                    $dbSource = $instanceSource.nodes | Where-Object {$_.protectionSource.name -eq "$($instanceSource.protectionSource.name)/$thisDBName"}
                    if(! $dbSource){
                        Write-Host "$thisDBName not found in $serverName/$($instanceSource.protectionSource.name)" -ForegroundColor Yellow
                        continue
                    }
                    if(! $(isSelected $serverSource) -and ! $(isSelected $instanceSource)){
                        addSelection $dbSource
                    }
                    Write-Host "Protecting $serverName/$($instanceSource.protectionSource.name)/$thisDBName"
                }
            }
        }else{
            addSelection $serverSource
            Write-Host "Protecting $servername"
        }
    }
}

if($params.objects.Count -eq 0){
    Write-Host "Nothing protected. Exiting without committing changes." -ForegroundColor Yellow
    exit 1
}
if($newJob -eq $True){
    Write-Host "Creating job $jobName..."
    $createdJob = api post -v2 data-protect/protection-groups $job
}else{
    Write-Host "Updating job $jobname..."
    $null = api put -v2 data-protect/protection-groups/$($job.id) $job 
}
