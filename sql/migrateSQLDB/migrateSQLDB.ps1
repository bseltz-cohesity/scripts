# version 2022-09-07

# process commandline arguments
[CmdletBinding()]
param(
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][string]$sourceServer = '',            # protection source where the DB was backed up
    [Parameter()][string]$sourceDB = '',                # name of the source DB we want to restore
    [Parameter()][string]$targetServer = '',            # where to restore the DB to
    [Parameter()][string]$targetDB = $sourceDB,         # desired restore DB name
    [Parameter()][switch]$overWrite,                    # overwrite existing DB
    [Parameter()][string]$mdfFolder,                    # path to restore the mdf
    [Parameter()][string]$ldfFolder = $mdfFolder,       # path to restore the ldf
    [Parameter()][hashtable]$ndfFolders,                # paths to restore the ndfs (requires Cohesity 6.0x)
    [Parameter()][string]$targetInstance,               # SQL instance name on the targetServer
    [Parameter()][switch]$noRecovery,                   # restore with NORECOVERY option
    [Parameter()][switch]$keepCdc,                      # keepCDC
    [Parameter()][switch]$showPaths,                    # show data file paths and exit
    [Parameter()][switch]$useSourcePaths,               # use same paths from source server for target server
    [Parameter()][switch]$manualSync,                   # do not autosync
    [Parameter()][switch]$init,                         # initiate new migration
    [Parameter()][switch]$sync,                         # perform manual sync now
    [Parameter()][switch]$finalize,                     # finalize migration
    [Parameter()][switch]$showAll,                      # also show completed tasks
    [Parameter()][int]$daysBack = 7,                    # days back for showAll
    [Parameter()][string]$name = '',                    # task name
    [Parameter()][string]$filter = '',                  # task name search filter
    [Parameter()][string]$id = ''                       # task id
)

# demand parameters for init mode
if($init -or $showPaths){
    if('' -eq $sourceServer){
        Write-Host "-sourceServer is required" -ForegroundColor Yellow
        exit 1
    }
    if('' -eq $sourceDB){
        Write-Host "-sourceDB is required" -ForegroundColor Yellow
        exit 1
    }
}
if($init){
    if('' -eq $targetServer){
        Write-Host "-targetServer is required" -ForegroundColor Yellow
        exit 1
    }
}

$isAutoSyncEnabled = $True
if($manualsync){
    $isAutoSyncEnabled = $False
}

# handle alternate secondary data file locations
$secondaryFileLocation = @()
if($ndfFolders){
    if($ndfFolders -is [hashtable]){
        foreach ($key in $ndfFolders.Keys){
            $secondaryFileLocation += @{'filePattern' = $key; 'targetDirectory' = $ndfFolders[$key]}
        }
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# handle source instance name e.g. instance/dbname
if($sourceDB.Contains('/')){
    if($targetDB -eq $sourceDB){
        $targetDB = $sourceDB.Split('/')[1]
    }
    $sourceInstance, $sourceDB = $sourceDB.Split('/')
}else{
    $sourceInstance = 'MSSQLSERVER'
}

if($init -or $showPaths){
    # search for database to clone
    $searchresults = api get "/searchvms?environment=SQL&entityTypes=kSQL&entityTypes=kVMware&vmName=$sourceInstance/$sourceDB"

    if($targetInstance -ne '' -and $targetInstance -ne $sourceInstance){
        $differentInstance = $True
    }else{
        $differentInstance = $False
    }

    # narrow the search results to the correct source server
    $dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer } | `
                                    Where-Object {$_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $sourceDB } | `
                                    Where-Object {$_.vmDocument.objectName -eq "$sourceInstance/$sourceDB"}

    if($null -eq $dbresults){
        write-host "Database $sourceInstance/$sourceDB on Server $sourceServer Not Found" -foregroundcolor yellow
        exit
    }

    # if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
    $latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

    if($null -eq $latestdb){
        write-host "Database $sourceInstance/$sourceDB on Server $sourceServer Not Found" -foregroundcolor yellow
        exit 1
    }

    if($showPaths){

        $latestdb.vmDocument.objectId.entity.sqlEntity.dbFileInfoVec | Format-Table -Property logicalName, @{l='Size (MiB)'; e={$_.sizeBytes / (1024 * 1024)}}, fullPath
    
        Write-Host "Example Restore Path Parameters:`n"
    
        $ndfFolderExample = '@{'
        $mdfFolderExample = ''
        $ldfFolderExample = ''
        foreach($file in $latestdb.vmDocument.objectId.entity.sqlEntity.dbFileInfoVec){
            $fileName = Split-Path -Path $file.fullPath -Leaf
            $filePath = (Split-Path -Path $file.fullPath).replace('/', '\')
            $extension = ".$((Split-Path -Path $file.fullPath -Leaf).Split('.')[-1])"
            if($file.type -eq 0){
                if($mdfFolderExample -eq '' -and $extension -eq '.mdf'){
                    $mdfFolderExample = $filePath
                }else{
                    $ndfFolderExample += "`n              '.*$fileName' = '$filePath'; "
                }
            }else{
                if($ldfFolderExample -eq ''){
                    $ldfFolderExample = $filePath
                }
            }
        }
        $ndfFolderExample += "`n            }"
        Write-Host "-mdfFolder $mdfFolderExample ```n-ldfFolder $ldfFolderExample ```n-ndfFolders $ndfFolderExample`n"
        exit 0
    }

    # identify physical or vm
    $entityType = $latestdb.registeredSource.type

    # search for source server
    $entities = api get /appEntities?appEnvType=3`&envType=$entityType
    $ownerId = $latestdb.vmDocument.objectId.entity.sqlEntity.ownerId
    $dbId = $latestdb.vmDocument.objectId.entity.id

    $versionNum = 0
    $dbVersions = $latestdb.vmDocument.versions

    $restoreTaskName = "Migrate-{0}_{1}_{2}_{3}" -f $sourceServer, $sourceInstance, $sourceDB, $(get-date -UFormat '%b_%d_%Y_%H-%M%p')

    # create new clone task (RestoreAppArg Object)
    $restoreTask = @{
        "name" = $restoreTaskName;
        'action' = 'kRecoverApp';
        'restoreAppParams' = @{
            'type' = 3;
            'ownerRestoreInfo' = @{
                "ownerObject" = @{
                    "jobUid" = $latestdb.vmDocument.objectId.jobUid;
                    "jobId" = $latestdb.vmDocument.objectId.jobId;
                    "jobInstanceId" = $dbVersions[$versionNum].instanceId.jobInstanceId;
                    "startTimeUsecs" = $dbVersions[$versionNum].instanceId.jobStartTimeUsecs;
                    "entity" = @{
                        "id" = $ownerId
                    }
                }
                'ownerRestoreParams' = @{
                    'action' = 'kRecoverVMs';
                    'powerStateConfig' = @{}
                };
                'performRestore' = $false
            };
            'restoreAppObjectVec' = @(
                @{
                    "appEntity" = $latestdb.vmDocument.objectId.entity;
                    'restoreParams' = @{
                        'sqlRestoreParams' = @{
                            'captureTailLogs' = $false;
                            'secondaryDataFileDestinationVec' = @();
                            'alternateLocationParams' = @{};
                            "isAutoSyncEnabled" = $isAutoSyncEnabled;
                            "isMultiStageRestore" = $True
                        };
                    }
                }
            )
        }
    }

    # noRecovery
    if($noRecovery){
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.withNoRecovery = $True
    }

    # keepCDC
    if($keepCdc){
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['keepCdc'] = $True
    }

    # alt location params
    if($useSourcePaths){
        $mdfFolderFound = $False
        $ldfFolderFound = $False
        foreach($datafile in $latestdb.vmDocument.objectId.entity.sqlEntity.dbFileInfoVec){
            $path = $datafile.fullPath.subString(0, $datafile.fullPath.LastIndexOf('\'))
            $fileName = $datafile.fullPath.subString($datafile.fullPath.LastIndexOf('\') + 1)
            if($datafile.type -eq 0){
                if($mdfFolderFound -eq $False){
                    $mdfFolder = $path
                    $mdfFolderFound = $True
                }else{
                    $secondaryFileLocation += @{'filePattern' = $datafile.fullPath; 'targetDirectory' = $path}
                }
            }
            if($datafile.type -eq 1){
                if($ldfFolderFound -eq $False){
                    $ldfFolder = $path
                    $ldfFolderFound = $True
                }
            }
        }
    }

    if('' -eq $mdfFolder){
        write-host "-mdfFolder must be specified when restoring to a new database name or different target server" -ForegroundColor Yellow
        exit
    }
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['dataFileDestination'] = $mdfFolder;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['logFileDestination'] = $ldfFolder;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['secondaryDataFileDestinationVec'] = $secondaryFileLocation;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['newDatabaseName'] = $targetDB;    

    if($targetInstance -eq '' -and $targetServer -ne $sourceServer){
        $targetInstance = 'MSSQLSERVER'
    }

    # search for target server

    $targetEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $targetServer }
    if($null -eq $targetEntity){
        Write-Host "Target Server Not Found" -ForegroundColor Yellow
        exit 1
    }
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHost'] = $targetEntity.appEntity.entity;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHostParentSource'] = @{ 'id' = $targetEntity.appEntity.entity.parentId }
    if($targetInstance){
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = $targetInstance
    }else{
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = 'MSSQLSERVER'
    }

    # execute the recovery task (post /recoverApplication api call)
    $response = api post /recoverApplication $restoreTask

    if($response){
        "Initiating migration of $sourceInstance/$sourceDB to $targetServer/$targetInstance/$targetDB"
        exit 0
    }else{
        exit 1
    }
}else{
    if($showAll){
        $daysBackUsecs = timeAgo $daysBack days
        $migrations = (api get -v2 "data-protect/recoveries?snapshotEnvironments=kSQL&recoveryActions=RecoverApps&startTimeUsecs=$daysBackUsecs").recoveries
    }else{
        $migrations = (api get -v2 "data-protect/recoveries?status=OnHold,Running&snapshotEnvironments=kSQL&recoveryActions=RecoverApps").recoveries
    }
    if($name -ne ''){
        $migrations = $migrations | Where-Object name -eq $name
    }
    if($id -ne ''){
        $migrations = $migrations | Where-Object id -eq $id
    }
    if($filter -ne ''){
        $migrations = $migrations | Where-Object name -match $filter
    }
    if($migrations){
        $migrations = $migrations | Where-Object {$_.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.PSObject.Properties['multiStageRestoreOptions']}
    }
    $migrationCount = 0
    foreach($migration in $migrations | sort-object -Property id -Descending){
        $migrationCount += 1
        $mTaskId = [int]($migration.id -split ':')[2]
        $mTask = api get /restoretasks/$mTaskId
        $mSnapshotUsecs = $mTask.restoreTask.restoreSubTaskWrapperProtoVec[-1].performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.startTimeUsecs
        $mTargetHost = $migration.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.host.name
        $mTargetInstance = $migration.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.instanceName
        $mTargetDB = $migration.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.databaseName

        Write-Host "`nTask Name: $($migration.name)"
        Write-Host "  Task ID: $($migration.id)"
        Write-Host "Target DB: $mTargetHost/$mTargetInstance/$mTargetDB"
        Write-Host "   Status: $($migration.status)"
        Write-Host "Synced To: $(usecsToDate $mSnapshotUsecs)"

        if($sync){
            if($migration.status -eq 'OnHold'){
                Write-host "Performing Sync..."
                $null = api put restore/recover -quiet @{"restoreTaskId" = $mTaskId; "sqlOptions" = "kUpdate"}
            }else{
                Write-Host "Can't sync now ($($migration.status))" -ForegroundColor Yellow
            }
        }
        if($finalize){
            if($migration.status -eq 'OnHold'){
                Write-Host "Finalizing..."
                $null = api put restore/recover -quiet @{"restoreTaskId" = $mTaskId; "sqlOptions" = "kFinalize"}
            }else{
                Write-Host "Can't finalize now ($($migration.status))" -ForegroundColor Yellow
            }
        }
    }
    ''
    if($migrationCount -eq 0){
        Write-Host "No migrations found`n"
    }
}
