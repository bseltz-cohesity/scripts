# version 2022-09-07

# process commandline arguments
[CmdletBinding()]
param(
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
    [Parameter()][string]$sourceServer = '',            # protection source where the DB was backed up
    [Parameter()][array]$sourceDB,                      # names of the source DBs we want to migrate
    [Parameter()][string]$sourceInstance,               # SQL instance name on the source server
    [Parameter()][string]$sourceDBList,                 # text file of sourceDBs to migrate
    [Parameter()][string]$targetServer = '',            # where to restore the DB to
    [Parameter()][string]$targetDB = '',                # desired restore DB name
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
    [Parameter()][int]$daysBack = 30,                   # days back to look
    [Parameter()][string]$name = '',                    # task name
    [Parameter()][string]$filter = '',                  # task name search filter
    [Parameter()][string]$id = '',                      # task id
    [Parameter()][switch]$returnTaskIds,                # only return task IDs
    [Parameter()][switch]$cancel                        # cancel tasks
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

$sourceDBs = @(gatherList -Param $sourceDB -FilePath $sourceDBList -Name 'sourceDBs' -Required $False)

if(!$sourceDBs -or $sourceDBs.Count -eq 0){
    $sourceDBs = @('')
}

$migrationCount = 0

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

# handle alternate secondary data file locations
$secondaryFileLocation = @()
if($ndfFolders){
    if($ndfFolders -is [hashtable]){
        foreach ($key in $ndfFolders.Keys){
            $secondaryFileLocation += @{'filePattern' = $key; 'targetDirectory' = $ndfFolders[$key]}
        }
    }
}

$isAutoSyncEnabled = $True
if($manualsync){
    $isAutoSyncEnabled = $False
}

$noTargetDBSpecified = $True
if($targetDB -ne ''){
    $noTargetDBSpecified = $False
    if($sourceDBs.Count -gt 1){
        Write-Host "-targetDB not supported with multiple DBs" -ForegroundColor Yellow
        exit
    }
}

$taskIds = @()
$sourceNames = @{}
$entities = $null
$daysBackUsecs = timeAgo $daysBack days

if(!$init){
    $allmigrations = (api get -v2 "data-protect/recoveries?snapshotEnvironments=kSQL&recoveryActions=RecoverApps&startTimeUsecs=$daysBackUsecs").recoveries
    if(! $showAll){
        $allmigrations = $allmigrations | Where-Object {$_.status -eq 'OnHold' -or $_.status -eq 'Running'}
    }
    $tasks = api get "/restoretasks?restoreTypes=kRestoreApp&startTimeUsecs=$(timeAgo $daysBack days)"
}

$sqlSources = api get protectionSources/registrationInfo?environments=kSQL
if($sourceServer -ne ''){
    $sqlSource = $sqlSources.rootNodes | Where-Object {$_.rootNode.name -eq $sourceServer}
    if(! $sqlSource){
        Write-Host "sourceServer $sourceServer not found" -ForegroundColor Yellow
        exit
    }
}

foreach($s in $sourceDBs){
    $sourceDB = [string]$s
    if($sourceDBs.Count -gt 1){
        $targetDB = $sourceDB
    }
    if($targetDB -eq ''){
        $targetDB = $sourceDB
    }

    # handle source instance name e.g. instance/dbname
    if($sourceDB -match '/'){
        if($targetDB -eq $sourceDB){
            $targetDB = $sourceDB.Split('/')[1]
        }
        $sourceInstance, $sourceDB = $sourceDB.Split('/')
    }elseif(! $sourceInstance){
        $sourceInstance = 'MSSQLSERVER'
    }

    if($init -or $showPaths){
        # search for database to clone
        $searchresults = api get "/searchvms?environment=SQL&entityTypes=kSQL&entityTypes=kVMware&vmName=$sourceInstance/$sourceDB"

        # narrow the search results to the correct source server
        $dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer } | `
                                          Where-Object {$_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $sourceDB } | `
                                          Where-Object {$_.vmDocument.objectName -eq "$sourceInstance/$sourceDB"}

        if($null -eq $dbresults){
            Write-Host "Database $sourceInstance/$sourceDB on Server $sourceServer Not Found" -ForegroundColor Yellow
            continue
        }

        # if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
        $latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

        if($null -eq $latestdb){
            Write-Host "Database $sourceInstance/$sourceDB on Server $sourceServer Not Found" -ForegroundColor Yellow
            continue
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
            continue
        }

        # identify physical or vm
        $entityType = $latestdb.registeredSource.type

        # search for source server
        if($null -eq $entities){
            $entities = api get /appEntities?appEnvType=3`&envType=$entityType
        }
        
        $ownerId = $latestdb.vmDocument.objectId.entity.sqlEntity.ownerId

        $versionNum = 0
        $dbVersions = $latestdb.vmDocument.versions

        $restoreTaskName = "Migrate-{0}_{1}_{2}_{3}" -f $sourceServer, $sourceInstance, $s, $(get-date -UFormat '%b_%d_%Y_%H-%M%p')

        # create new clone task (RestoreAppArg Object)
        $restoreTask = @{
            "name" = $restoreTaskName;
            'action' = 'kRecoverApp';
            'restoreAppParams' = @{
                'type' = 3;
                'ownerRestoreInfo' = @{
                    "ownerObject" = @{
                        "attemptNum" = $dbVersions[$versionNum].instanceId.attemptNum;
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

        if($init){
            if($targetInstance -eq ''){
                $targetInstance = 'MSSQLSERVER'
            }
            if('' -eq $mdfFolder){
                Write-Host "-mdfFolder must be specified when restoring to a new database name or different target server" -ForegroundColor Yellow
                exit
            }
            $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['dataFileDestination'] = $mdfFolder;
            $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['logFileDestination'] = $ldfFolder;
            $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['secondaryDataFileDestinationVec'] = $secondaryFileLocation;
            $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['newDatabaseName'] = $targetDB;    
        
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
                Write-Host "Initiating migration of $sourceInstance/$sourceDB to $targetServer/$targetInstance/$targetDB"
                continue
            }else{
                Write-Host "An error occured" -ForegroundColor Yellow
                continue
            }
        }
    }
    if($allmigrations -and !$init){
        $migrations = $allmigrations #.clone()
        if($name -ne ''){
            $migrations = $migrations | Where-Object name -eq $name
        }
        if($id -ne ''){
            $migrations = $migrations | Where-Object id -eq $id
        }
        if($filter -ne ''){
            $migrations = $migrations | Where-Object name -match $filter
        }
        if($sourceDB -ne ''){
            if($migrations){
                $migrations = $migrations | Where-Object {($_.mssqlParams.PSObject.Properties['objects'] -and
                                                           $_.mssqlParams.objects[0].objectInfo.name -eq "$sourceInstance/$sourceDB") -or
                                                          ($_.mssqlParams.recoverAppParams[0].PSObject.Properties['objectInfo'] -and
                                                           $_.mssqlParams.recoverAppParams[0].objectInfo.name -eq "$sourceInstance/$sourceDB")}
            }
        }
        if($sourceServer -ne ''){
            if($migrations){
                $migrations = $migrations | Where-Object {($_.mssqlParams.PSObject.Properties['objects'] -and
                                                           $_.mssqlParams.objects[0].objectInfo.sourceId -eq $sqlSource.rootNode.id) -or
                                                          ($_.mssqlParams.recoverAppParams[0].PSObject.Properties['objectInfo'] -and
                                                           $_.mssqlParams.recoverAppParams[0].hostInfo.name -eq $sourceServer)}
            }
        }
        if($targetDB -ne '' -or $targetServer -ne ''){
            if($migrations){
                if($targetDB -match '/'){
                    $thisTargetInstance, $thisTargetDB = $targetDB.Split('/')
                }else{
                    $thisTargetDB = $targetDB
                }
                if($targetInstance){
                    $thisTargetInstance = $targetInstance
                }elseif($targetDB -match '/'){
                    $thisTargetInstance = $targetDB.Split('/')[0]
                }else{
                    $thisTargetInstance = 'MSSQLSERVER'
                }

                if($targetServer -ne ''){
                    $migrations = $migrations | Where-Object {($_.mssqlParams.recoverAppParams.PSObject.Properties['sqlTargetParams'] -and
                                                        $_.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.host.name -eq $targetServer) -or
                                                        ($_.mssqlParams.recoverAppParams[0].PSObject.Properties['sqlTargetParams'] -and
                                                        $_.mssqlParams.recoverAppParams[0].sqlTargetParams.newSourceConfig.host.name -eq $targetServer)}
                }
                if($noTargetDBSpecified -eq $false){
                    $migrations = $migrations | Where-Object {($_.mssqlParams.recoverAppParams.PSObject.Properties['sqlTargetParams'] -and
                    $_.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.instanceName -eq $thisTargetInstance -and
                    $_.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.databaseName -eq $thisTargetDB) -or
                    ($_.mssqlParams.recoverAppParams[0].PSObject.Properties['sqlTargetParams'] -and
                    $_.mssqlParams.recoverAppParams[0].sqlTargetParams.newSourceConfig.instanceName -eq $thisTargetInstance -and
                    $_.mssqlParams.recoverAppParams[0].sqlTargetParams.newSourceConfig.databaseName -eq $thisTargetDB)}
                }
            }
        }
        if($migrations){
            $migrations = $migrations | sort-object -Property id -Descending
            if($returnTaskIds){
                $taskIds = @($taskIds + $migrations.id)
                continue
            }
        }
    
        foreach($migration in $migrations){
            $migrationCount += 1
            $mTaskId = [int]($migration.id -split ':')[2]
            $mTask = $tasks | Where-Object {$_.restoreTask.performRestoreTaskState.base.taskId -eq $mTaskId}
            if($mTask.restoreTask.restoreSubTaskWrapperProtoVec.Count -gt 0){
                $mSnapshotUsecs = $mTask.restoreTask.restoreSubTaskWrapperProtoVec[-1].performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.startTimeUsecs
            }
            $mTargetHost = $migration.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.host.name
            $mTargetInstance = $migration.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.instanceName
            $mTargetDB = $migration.mssqlParams.recoverAppParams.sqlTargetParams.newSourceConfig.databaseName
            if($migration.mssqlParams.PSObject.Properties['objects']){
                $mSourceDB = $migration.mssqlParams.objects[0].objectInfo.name
                if("$($migration.mssqlParams.objects[0].objectInfo.sourceId)" -in $sourceNames.Keys){
                    $mSourceHost = $sourceNames["$($migration.mssqlParams.objects[0].objectInfo.sourceId)"]
                }else{
                    $hostSearch = api get /searchvms?entityIds=$($migration.mssqlParams.objects[0].objectInfo.sourceId)
                    $mSourceHost = $hostSearch.vms[0].vmDocument.objectAliases[0]
                    $sourceNames["$($migration.mssqlParams.objects[0].objectInfo.sourceId)"] = $mSourceHost
                }
            }elseif($migration.mssqlParams.recoverAppParams[0].PSObject.Properties['objectInfo']){
                $mSourceDB = $migration.mssqlParams.recoverAppParams[0].objectInfo.name
                $mSourceHost = $migration.mssqlParams.recoverAppParams[0].hostInfo.name
            }
            if($mTask.restoreTask.restoreSubTaskWrapperProtoVec.Count -gt 0){
                Write-Host "`nTask Name: $($migration.name)"
                Write-Host "  Task ID: $($migration.id)"
                Write-Host "Source DB: $mSourceHost/$mSourceDB"
                Write-Host "Target DB: $mTargetHost/$mTargetInstance/$mTargetDB"
                Write-Host "   Status: $($migration.status)"
                Write-Host "Synced To: $(usecsToDate $mSnapshotUsecs)"
            }
            if($mTask.restoreTask.restoreSubTaskWrapperProtoVec.Count -gt 0 -and $mTask.restoreTask.restoreSubTaskWrapperProtoVec[0].performRestoreTaskState.base.PSObject.Properties['warnings'] -and $mTask.restoreTask.restoreSubTaskWrapperProtoVec[0].performRestoreTaskState.base.warnings[0].errorMsg){
                Write-Host "  Warning: $($mTask.restoreTask.restoreSubTaskWrapperProtoVec[0].performRestoreTaskState.base.warnings[0].errorMsg)"
            }
            if($sync){
                if($migration.status -eq 'OnHold'){
                    Write-Host "Performing Sync..."
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
            if($cancel){
                if($migration.status -in @('OnHold', 'Running')){
                    Write-Host "Cancelling..."
                    $null = api put "restore/tasks/cancel/$mTaskId"
                }
            }
        }
    }
}

if($returnTaskIds -and !$init){
    return $taskIds
}

''
if($migrationCount -eq 0 -and !$init){
    Write-Host "No migrations found`n"
}
