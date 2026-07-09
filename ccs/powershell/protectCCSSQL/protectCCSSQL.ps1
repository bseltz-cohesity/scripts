# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter()][array]$serverNames,
    [Parameter()][string]$serverList = '',
    [Parameter()][array]$instanceNames,
    [Parameter()][array]$dbNames,
    [Parameter()][string]$dbList = '',
    [Parameter()][array]$excludeDbNames,
    [Parameter()][string]$excludeDbList = '',
    [Parameter()][switch]$allDBs,
    [Parameter()][switch]$systemDBsOnly,
    [Parameter()][switch]$excludeSystemDbs,
    [Parameter()][int]$numStreams = 3,
    [Parameter()][string]$withClause = '',
    [Parameter()][int]$logBackupNumStreams = 3,
    [Parameter()][string]$logBackupWithClause = '',
    [Parameter()][ValidateSet('kBackupAllDatabases', 'kBackupAllExceptAAGDatabases', 'kBackupOnlyAAGDatabases')][string]$userDbBackupPreference = 'kBackupAllDatabases',
    [Parameter()][ValidateSet('kUseServerPreference', 'kPrimaryReplicaOnly', 'kSecondaryReplicaOnly', 'kPreferSecondaryReplica', 'kAnyReplica')][string]$aagBackupPreference = 'kUseServerPreference',
    [Parameter()][switch]$fullBackupsCopyOnly,
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][switch]$pause,
    [Parameter()][switch]$dbg
)

$isPaused = $false
if($pause){
    $isPaused = $True
}

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

# dbNames may optionally be qualified as 'instanceName/dbName' to target a specific
# instance/AAG directly, or left unqualified to resolve against -instanceNames
# (or the default MSSQLSERVER instance if -instanceNames is omitted)
$serverNamesToAdd = @(gatherList -Param $serverNames -FilePath $serverList -Name 'SQL servers' -Required $True)
$dbNamesToAdd = @(gatherList -Param $dbNames -FilePath $dbList -Name 'Include DBs' -Required $false)
$dbNamesToExclude = @(gatherList -Param $excludeDbNames -FilePath $excludeDbList -Name 'Exclude DBs' -Required $false)
# $instanceNames = @($instanceNames)

if($serverNamesToAdd.Count -eq 0){
    Write-Host "No SQL servers specified" -ForegroundColor Yellow
    exit
}

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
}

$systemDBs = @('master', 'model', 'msdb')

# index the SQL source hierarchy (root server -> instance/AAG -> database)
$script:sqlHierarchy = @{}

function indexSqlSource($serverName, $node, $parents = @()){
    if($serverName -notin $script:sqlHierarchy.keys){
        $script:sqlHierarchy[$serverName] = @()
    }
    $sqlType = 'kHost'
    if($node.protectionSource.PSObject.Properties['sqlProtectionSource'] -and $node.protectionSource.sqlProtectionSource){
        $sqlType = $node.protectionSource.sqlProtectionSource.type
    }
    $thisNode = @{'id' = $node.protectionSource.id;
                    'name' = $node.protectionSource.name;
                    'type' = $sqlType;
                    'parents' = $parents}
    $script:sqlHierarchy[$serverName] = @($script:sqlHierarchy[$serverName] + $thisNode)
    $newParents = @($parents + $node.protectionSource.id | Sort-Object -Unique)
    # SQL instances (and AAGs) are stored as applicationNodes hanging off the host
    if($node.PSObject.Properties['applicationNodes']){
        foreach($child in $node.applicationNodes){
            indexSqlSource $serverName $child $newParents
        }
    }
    # databases (or nested AAG groups) are stored as regular child nodes
    if($node.PSObject.Properties['nodes']){
        foreach($child in $node.nodes){
            indexSqlSource $serverName $child $newParents
        }
    }
}

# an "instance" here means anything that groups databases together (kInstance or kAAG)
function getInstances($serverName){
    $index = $script:sqlHierarchy[$serverName]
    $instances = @($index | Where-Object {$_.type -in @('kInstance', 'kAAG')})
    if($instanceNames.Count -ne 0){
        $instances = @($instances | Where-Object {$_.name -in $instanceNames})
    }
    return $instances
}

# default instance(s) to search when a dbName is not qualified with 'instanceName/'
function getDefaultInstances($serverName){
    $index = $script:sqlHierarchy[$serverName]
    # if($instanceNames.Count -gt 0){
    #     return @(getInstances $serverName)
    # }
    $default = @($index | Where-Object {$_.name -eq 'MSSQLSERVER' -and $_.type -in @('kInstance', 'kAAG')})
    if(@($default).Count -eq 0){
        $default = @(getInstances $serverName)
    }
    return $default
}

function getDatabases($serverName, $instance){
    $index = $script:sqlHierarchy[$serverName]
    $databases = @($index | Where-Object {$_.type -eq 'kDatabase' -and $instance.id -in $_.parents})
    $aagDatabases = @($index | Where-Object {$_.type -eq 'kAAGDatabase'})
    $databases = @($databases + $aagDatabases)
    return @($databases)
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to CCS ===========================================
Write-Host "Connecting to Cohesity Cloud..."
apiauth -username $username -passwd $password
# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# ===============================================================

# find registered SQL sources (SQL is registered as an application on a kPhysical source)
Write-Host "Finding registered SQL sources"
$registeredSources = api get -mcmv2 "data-protect/sources?environments=kPhysical,kSQL&regionIds=$region"

$serversFound = @()
foreach($serverName in $serverNamesToAdd){
    $source = $registeredSources.sources | Where-Object {$_.name -eq $serverName}
    if(! $source){
        Write-Host "SQL source $serverName not found" -ForegroundColor Yellow
        continue
    }
    $sourceInfo = $source.sourceInfoList | Where-Object {$_.regionId -eq $region}
    if(! $sourceInfo){
        Write-Host "SQL source $serverName not registered in region $region" -ForegroundColor Yellow
        continue
    }
    $sourceId = $sourceInfo.sourceId
    $rootNode = api get "protectionSources?id=$sourceId&pruneNonCriticalInfo=true&pruneAggregationInfo=true&regionId=$region"
    if(! $rootNode){
        Write-Host "SQL source $serverName not found" -ForegroundColor Yellow
        continue
    }
    indexSqlSource $serverName $rootNode
    $serversFound = @($serversFound + $serverName)
}

if(@($serversFound).Count -eq 0){
    Write-Host "No SQL servers found" -ForegroundColor Yellow
    exit
}

Write-Host "Finding protection policy"

$policy = (api get -mcmv2 data-protect/policies?types=DMaaSPolicy).policies | Where-Object name -eq $policyName
if(!$policy){
    write-host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}

# configure the MSSQL object protection type params (shared by all selected objects)
$excludeFilters = @()
foreach($dbName in $dbNamesToExclude){
    $excludeFilters = @($excludeFilters + @{'filterString' = $dbName; 'isRegularExpression' = $false})
}

$typeParams = @{
    "objects"                    = @();
    "numStreams"                 = $numStreams;
    "withClause"                 = $withClause;
    "backupSystemDbs"            = [bool](! $excludeSystemDbs);
    "userDbBackupPreferenceType" = $userDbBackupPreference;
    "fullBackupsCopyOnly"        = [bool]$fullBackupsCopyOnly;
    "logBackupNumStreams"        = $logBackupNumStreams;
    "logBackupWithClause"        = $logBackupWithClause
}
if($excludeFilters.Count -gt 0){
    $typeParams['excludeFilters'] = $excludeFilters
}
if($aagBackupPreference -eq 'kUseServerPreference'){
    $typeParams['useAagPreferencesFromServer'] = $true
}else{
    $typeParams['useAagPreferencesFromServer'] = $false
    $typeParams['aagBackupPreferenceType'] = $aagBackupPreference
}

# CCS object protection for MSSQL currently supports Native (VDI) backups
$mssqlParams = @{
    "objectProtectionType"            = 'kNative';
    "nativeObjectProtectionTypeParams" = $typeParams
}

# configure protection parameters
$protectionParams = @{
    "policyId" = $policy.id;
    "startTime"        = @{
        "hour"     = [int64]$hour;
        "minute"   = [int64]$minute;
        "timeZone" = $timeZone
    };
    "priority" = "kMedium";
    "sla"              = @(
        @{
            "backupRunType" = "kFull";
            "slaMinutes"    = $fullSlaMinutes
        };
        @{
            "backupRunType" = "kIncremental";
            "slaMinutes"    = $incrementalSlaMinutes
        }
    );
    "qosPolicy" = "kBackupSSD";
    "abortInBlackouts" = $false;
    "objects" = @(
        @{
            "environment" = "kSQL";
            "mssqlParams" = $mssqlParams
        }
    );
    "isPaused" = $isPaused;
    "pausedNote" = ""
}

# process server/instance/database selections
$objectsToAdd = @()

foreach($serverName in $serversFound){
    $index = $script:sqlHierarchy[$serverName]
    $server = $index[0]
    if($dbNamesToAdd.Count -gt 0){
        foreach($dbName in $dbNamesToAdd){
            if($dbName -match '/'){
                # qualified as 'instanceName/dbName' - resolve the instance directly,
                # regardless of -instanceNames
                $qualInstanceName, $qualDbName = $dbName -split '/', 2
                $qualInstances = @($index | Where-Object {$_.name -eq $qualInstanceName -and $_.type -in @('kInstance', 'kAAG')})
                if(@($qualInstances).Count -eq 0){
                    Write-Host "$serverName/$dbName not found (instance $qualInstanceName not found)" -ForegroundColor Yellow
                    continue
                }
                foreach($instance in $qualInstances){
                    $db = @(getDatabases $serverName $instance | Where-Object {($_.name -split '/')[-1] -eq $qualDbName})
                    if(@($db).Count -eq 0){
                        Write-Host "$serverName/$dbName not found" -ForegroundColor Yellow
                        continue
                    }
                    Write-Host "Protecting $serverName/$($db[0].name)"
                    $objectsToAdd = @($objectsToAdd + @{'id' = $db[0].id})
                }
            }else{
                $instances = @(getDefaultInstances $serverName)
                if(@($instances).Count -eq 0){
                    Write-Host "$serverName/$dbName not found (no matching instances on $serverName)" -ForegroundColor Yellow
                    continue
                }
                foreach($instance in $instances){
                    $db = @(getDatabases $serverName $instance | Where-Object {($_.name -split '/')[-1] -eq $dbName})
                    if(@($db).Count -eq 0){
                        Write-Host "$serverName/$($instance.name)/$dbName not found" -ForegroundColor Yellow
                        continue
                    }
                    Write-Host "Protecting $serverName/$($db[0].name)"
                    $objectsToAdd = @($objectsToAdd + @{'id' = $db[0].id})
                }
            }
        }
    }elseif($systemDBsOnly){
        foreach($instance in (getInstances $serverName)){
            foreach($db in (getDatabases $serverName $instance)){
                $shortName = ($db.name -split '/')[-1]
                if($shortName -in $systemDBs){
                    Write-Host "Protecting $serverName/$($db.name)"
                    $objectsToAdd = @($objectsToAdd + @{'id' = $db.id})
                }
            }
        }
    }elseif($allDBs){
        foreach($instance in (getInstances $serverName)){
            foreach($db in (getDatabases $serverName $instance)){
                Write-Host "Protecting $serverName/$($db.name)"
                $objectsToAdd = @($objectsToAdd + @{'id' = $db.id})
            }
        }
    }elseif(@($instanceNames).Count -gt 0){
        $instances = getInstances $serverName
        if(@($instances).Count -eq 0){
            Write-Host "No matching instances found on $serverName" -ForegroundColor Yellow
            continue
        }
        foreach($instance in $instances){
            Write-Host "Protecting $serverName/$($instance.name)"
            $objectsToAdd = @($objectsToAdd + @{'id' = $instance.id})
        }
    }else{
        Write-Host "Protecting $serverName"
        $objectsToAdd = @($objectsToAdd + @{'id' = $server.id})
    }
}

if(@($objectsToAdd).Count -eq 0){
    Write-Host "Nothing to protect" -ForegroundColor Yellow
    exit
}

$typeParams.objects = @($objectsToAdd)

if($dbg){
    $protectionParams | toJson
    exit
}

$response = api post -v2 "data-protect/protected-objects?regionIds=$region" $protectionParams
if(! $response -or @($response.protectedObjects).Count -lt 1 -or $response.protectedObjects.error){
    Write-Host $response.protectedObjects.error -ForegroundColor Yellow
}
