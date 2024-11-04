# version 2023-08-16
# usage: ./restore-SQL.ps1 -vip mycluster `
#                          -username myusername `
#                          -domain mydomain.net `
#                          -sourceServer sqlserver1.mydomain.net `
#                          -sourceDB myinstance/mydb `
#                          -targetInstance otherinstance `
#                          -targetDB otherdb `
#                          -mdfFolder c:\SQLData `
#                          -ldfFolder c:\SQLData\logs `
#                          -ndfFolders @{'*1.ndf'='E:\sqlrestore\ndf1'; '*2.ndf'='E:\sqlrestore\ndf2'}
#                          -overWrite `
#                          -resume `
#                          -noRecovery `
#                          -logTime '2020-08-28 02:30:00'

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key for authentication
    [Parameter()][string]$password,                      # optional password
    [Parameter()][switch]$noPrompt,                      # do not prompt for password
    [Parameter()][string]$tenant,                        # org to impersonate
    [Parameter()][switch]$mcm,                           # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,               # MFA code
    [Parameter()][switch]$emailMfaCode,                  # email MFA code
    [Parameter()][string]$clusterName = $null,           # helios cluster to access 
    [Parameter(Mandatory = $True)][string]$sourceServer, # protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$sourceDB,     # name of the source DB we want to restore
    [Parameter()][array]$sourceInstance,                 # one or more source instances
    [Parameter()][string]$targetServer = $sourceServer,  # where to restore the DB to
    [Parameter()][string]$targetDB = $sourceDB,          # desired restore DB name
    [Parameter()][switch]$overWrite,                     # overwrite existing DB
    [Parameter()][string]$mdfFolder,                     # path to restore the mdf
    [Parameter()][string]$ldfFolder = $mdfFolder,        # path to restore the ldf
    [Parameter()][hashtable]$ndfFolders,                 # paths to restore the ndfs (requires Cohesity 6.0x)
    [Parameter()][string]$ndfFolder,                     # single path to restore ndfs (Cohesity 5.0x)
    [Parameter()][string]$logTime,                       # date time to replay logs to e.g. '2019-01-20 02:01:47'
    [Parameter()][switch]$wait,                          # wait for completion
    [Parameter()][string]$targetInstance,                # SQL instance name on the targetServer
    [Parameter()][switch]$latest,                        # use latest point in time available
    [Parameter()][switch]$noRecovery,                    # restore with NORECOVERY option
    [Parameter()][switch]$progress,                      # display progress
    [Parameter()][switch]$resume,                        # resume recovery of previously restored DB
    [Parameter()][switch]$keepCdc,                       # keepCDC
    [Parameter()][switch]$showPaths,                     # show data file paths and exit
    [Parameter()][switch]$useSourcePaths,                # use same paths from source server for target server
    [Parameter()][switch]$update,
    [Parameter()][switch]$noStop,
    [Parameter()][switch]$captureTailLogs,
    [Parameter()][switch]$restoreFromArchive,
    [Parameter()][int64]$sleepTimeSecs = 30,
    [Parameter()][string]$withClause,
    [Parameter()][array]$sourceNodes,                       # limit results to these AAG nodes
    [Parameter()][switch]$returnErrorMessage
)

function warn($message){
    if($returnErrorMessage){
        $message
    }else{
        Write-Host $message -ForegroundColor Yellow
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

if($update){
    $resume = $True
    $noRecovery = $True
    $latest = $True
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        warn "Please provide -clusterName when connecting through helios"
        exit 1
    }
}

if(!$cohesity_api.authorized){
    warn "Not authenticated"
    exit 1
}

# handle source instance name e.g. instance/dbname
if($sourceDB.Contains('/')){
    if($targetDB -eq $sourceDB){
        $targetDB = $sourceDB.Split('/')[1]
    }
    $si, $sourceDB = $sourceDB.Split('/')
    $sourceInstance = @($si)
}
if(!$sourceInstance -or $sourceInstance.Count -eq 0){
    $sourceInstance = @('MSSQLSERVER')
}
$sourceDBObjectNames = @()
foreach($si in $sourceInstance){
    $sourceDBObjectNames = @($sourceDBObjectNames + "$si/$sourceDB")
}

# search for database to clone
$searchresults = api get "/searchvms?environment=SQL&entityTypes=kSQL&entityTypes=kVMware&vmName=$sourceDB"

# narrow the search results to the correct source server
$dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer } | `
                                  Where-Object {$_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $sourceDB } | `
                                  Where-Object {$_.vmDocument.objectName -in $sourceDBObjectNames}

# narrow by source AAG nodes
if($sourceNodes){
    $dbresults = $dbresults | Where-Object {
        ([array]$x = Compare-Object -Referenceobject $sourceNodes -DifferenceObject $_.vmDocument.objectAliases  -excludedifferent -IncludeEqual)
    }
}

if($null -eq $dbresults){
    foreach($si in $sourceInstance){
        warn "Database $si/$sourceDB on Server $sourceServer Not Found"
    }
    exit 1
}

# if there are multiple results (e.g. old/new jobs?) sort from newest to oldest
$dbVersions = @()
foreach($dbresult in $dbresults){
    foreach($version in $dbresult.vmDocument.versions){
        setApiProperty -object $version -name vmDocument -value $dbresult.vmDocument
        setApiProperty -object $version -name registeredSource -value $dbresult.registeredSource
        $dbVersions = @($dbVersions + $version)
    }
}
$dbVersions = $dbVersions | Sort-Object -Property {$_.instanceId.jobStartTimeUsecs} -Descending

if($dbVersions.Count -eq 0){
    foreach($si in $sourceInstance){
        warn "Database $si/$sourceDB on Server $sourceServer Not Found"
    }
    exit 1
}

$latestdbDoc = $dbVersions[0].vmDocument

if($showPaths){

    $latestdbDoc.objectId.entity.sqlEntity.dbFileInfoVec | Format-Table -Property logicalName, @{l='Size (MiB)'; e={$_.sizeBytes / (1024 * 1024)}}, fullPath

    Write-Host "Example Restore Path Parameters:`n"

    $ndfFolderExample = '@{'
    $mdfFolderExample = ''
    $ldfFolderExample = ''
    foreach($file in $latestdbDoc.objectId.entity.sqlEntity.dbFileInfoVec){
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

    exit
}

# identify physical or vm
$entityType = $dbVersions[0].registeredSource.type

# search for source server
$entities = api get /appEntities?appEnvType=3`&envType=$entityType
$ownerId = $latestdbDoc.objectId.entity.sqlEntity.ownerId
$dbId = $latestdbDoc.objectId.entity.id

# handle log replay
$versionNum = 0
$validLogTime = $False
$useLogTime = $False
$latestUsecs = 0
$oldestUsecs = 0

if ($logTime -or $latest -or $noStop){
    if($logTime){
        $logUsecs = dateToUsecs $logTime
        $logUsecsDayStart = $dbVersions[-1].instanceId.jobStartTimeUsecs
        $logUsecsDayEnd = [int64] (dateToUsecs (get-date $logTime).Date.AddDays(1).AddSeconds(-1))
    }elseif($latest -or $noStop){
        $logUsecsDayEnd = [int64]( dateToUsecs (get-date))
    }
    if($logTime){
        $dbVersions = $dbVersions | Where-Object {$_.snapshotTimestampUsecs -lt ($logUsecs + 60000000)}
    }
    foreach ($version in $dbVersions) {
        if($latest -or $noStop){
            $logUsecsDayStart = [int64] $version.snapshotTimestampUsecs
        }
        $snapshotTimestampUsecs = $version.snapshotTimestampUsecs
        $oldestUsecs = $snapshotTimestampUsecs
        $timeRangeQuery = @{
            "endTimeUsecs"       = $logUsecsDayEnd;
            "protectionSourceId" = $dbId;
            "environment"        = "kSQL";
            "jobUids"            = @(
                @{
                    "clusterId"            = $version.vmDocument.objectId.jobUid.clusterId;
                    "clusterIncarnationId" = $version.vmDocument.objectId.jobUid.clusterIncarnationId;
                    "id"                   = $version.vmDocument.objectId.jobUid.objectId
                }
            );
            "startTimeUsecs"     = $logUsecsDayStart
        }
        $pointsForTimeRange = api post restore/pointsForTimeRange $timeRangeQuery
        if($pointsForTimeRange.PSobject.Properties['timeRanges']){
            # log backups available
            foreach($timeRange in $pointsForTimeRange.timeRanges){
                $logStart = $timeRange.startTimeUsecs
                $logEnd = $timeRange.endTimeUsecs
                if($latestUsecs -eq 0){
                    $latestUsecs = $logEnd - 1000000
                }
                if($latest -or $noStop){
                    $logUsecs = $logEnd - 1000000
                }
                if((($logUsecs - 1000000) -le $snapshotTimestampUsecs -or $snapshotTimestampUsecs -ge ($logUsecs + 1000000)) -and !$resume){
                    $validLogTime = $True
                    $useLogTime = $False
                    break
                }elseif($logStart -le $logUsecs -and $logUsecs -le $logEnd -and $logUsecs -ge ($snapshotTimestampUsecs - 1000000)) {
                    $validLogTime = $True
                    $useLogTime = $True
                    break
                }
            }
        }else{
            # no log backups available
            foreach($snapshot in $pointsForTimeRange.fullSnapshotInfo){
                if($latestUsecs -eq 0){
                    $latestUsecs = $snapshotTimestampUsecs
                }
                if($logTime){
                    if($snapshotTimestampUsecs -le ($logUsecs + 60000000)){

                        $validLogTime = $True
                        $useLogTime = $False
                        break
                    }
                }elseif($latest -or $noStop) {
                    $validLogTime = $True
                    $useLogTime = $False
                    break
                }
            }
        }
        if($latestUsecs -eq 0){
            $latestUsecs = $oldestUsecs
        }
        if(! $validLogTime){
            $versionNum += 1
        }else{
            break
        }
    }
    if(! $validLogTime){
        Write-Host "log time is out of range" -ForegroundColor Yellow        
        Write-Host "Valid range is $(usecsToDate $oldestUsecs) to $(usecsToDate $latestUsecs)"
        exit(1)
    }
}

# same or different instance
$thisSourceInstance, $thisSourceDB = ($dbVersions[$versionNum].vmDocument.objectId.entity.displayName).split('/')

if($targetInstance -ne '' -and $targetInstance -ne $thisSourceInstance){
    $differentInstance = $True
}else{
    $differentInstance = $False
}

if($targetInstance -eq '' -and $targetServer -eq $sourceServer){
    $targetInstance = $thisSourceInstance
}
if($targetInstance -eq '' -and $targetServer -ne $sourceServer){
    $targetInstance = 'MSSQLSERVER'
}

# overwrite warning
if($targetDB -eq $sourceDB -and $targetServer -eq $sourceServer -and $differentInstance -eq $False){
    if(! $overWrite){
        Write-Host "Please use the -overWrite parameter to confirm overwrite of the source database!" -ForegroundColor Yellow
        exit
    }
    if($captureTailLogs){
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['captureTailLogs'] = $True
    }
}else{
    if($captureTailLogs){
        Write-Host "-captureTailLogs only applies when overwriting the database in the oroginal location" -ForegroundColor Yellow
    }
}

$restoreTaskName = "Recover-{0}_{1}_{2}_{3}" -f $sourceServer, $thisSourceInstance, $sourceDB, $(get-date -UFormat '%b_%d_%Y_%H-%M%p')

# create new clone task (RestoreAppArg Object)
$restoreTask = @{
    "name" = $restoreTaskName;
    'action' = 'kRecoverApp';
    'restoreAppParams' = @{
        'type' = 3;
        'ownerRestoreInfo' = @{
            "ownerObject" = @{
                "attemptNum" = $dbVersions[$versionNum].instanceId.attemptNum;
                "jobUid" = $dbVersions[$versionNum].vmDocument.objectId.jobUid;
                "jobId" = $dbVersions[$versionNum].vmDocument.objectId.jobId;
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
                "appEntity" = $dbVersions[$versionNum].vmDocument.objectId.entity;
                'restoreParams' = @{
                    'sqlRestoreParams' = @{
                        'captureTailLogs' = $false;
                        'secondaryDataFileDestinationVec' = @();
                        'alternateLocationParams' = @{};
                    };
                }
            }
        )
    }
}

# allow cloudRetrieve
$localreplica = $dbVersions[$versionNum].replicaInfo.replicaVec | Where-Object {$_.target.type -eq 1}
$archivereplica = $dbVersions[$versionNum].replicaInfo.replicaVec | Where-Object {$_.target.type -eq 3}

if($archivereplica -and (! $localreplica -or $restoreFromArchive)){
    $restoreTask.restoreAppParams.ownerRestoreInfo.ownerObject['archivalTarget'] = $archivereplica[0].target.archivalTarget
}

# noRecovery
if($noRecovery){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.withNoRecovery = $True
}

# keepCDC
if($keepCdc){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['keepCdc'] = $True
}

# if not restoring to original server/DB
if($targetDB -ne $sourceDB -or $targetServer -ne $sourceServer -or $differentInstance){
    if($useSourcePaths){
        $mdfFolderFound = $False
        $ldfFolderFound = $False
        foreach($datafile in $latestdbDoc.objectId.entity.sqlEntity.dbFileInfoVec){
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
        warn "-mdfFolder must be specified when restoring to a new database name or different target server"
        exit 1
    }
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['dataFileDestination'] = $mdfFolder;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['logFileDestination'] = $ldfFolder;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['secondaryDataFileDestinationVec'] = $secondaryFileLocation;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['newDatabaseName'] = $targetDB;    
}

# apply log replay time
if($useLogTime -eq $True){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['restoreTimeSecs'] = $([int64]($logUsecs/1000000))
    $newRestoreUsecs = $logUsecs
}else{
    $newRestoreUsecs = $dbVersions[$versionNum].instanceId.jobStartTimeUsecs
}
$restoreTime = usecsToDate $newRestoreUsecs

if($noStop -and $useLogTime){
    # replay logs to one day in the future to ensure no STOPAT
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['restoreTimeSecs'] = (3600 + (datetousecs (Get-Date)) / 1000000)
}

# search for target server
if($targetServer -ne $sourceServer -or $differentInstance){
    $targetEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $targetServer }
    if($null -eq $targetEntity){
        warn "Target Server Not Found"
        exit 1
    }
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHost'] = $targetEntity.appEntity.entity;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHostParentSource'] = @{ 'id' = $targetEntity.appEntity.entity.parentId }
    if($targetInstance){
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = $targetInstance
    }else{
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = 'MSSQLSERVER'
    }
}else{
    $targetServer = $sourceServer
}

# handle 5.0x secondary file location
if($ndfFolder){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['secondaryDataFileDestination'] = $ndfFolder
}

# overWrite existing DB
if($overWrite){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['dbRestoreOverwritePolicy'] = 1
}

if($withClause){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.withClause = $withClause
}

# resume only if newer point in time available
if($resume){
    $previousRestoreUsecs = 0
    $uStart = dateToUsecs ((get-date).AddDays(-32))
    $restores = api get "/restoretasks?_includeTenantInfo=true&restoreTypes=kRecoverApp&startTimeUsecs=$uStart&targetType=kLocal"
    if($restores){
        $restores = $restores | Where-Object{$_.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec.Count -gt 0 -and
        ($_.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].appEntity.displayName -eq "$targetDB" -or 
        $_.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.newDatabaseName -eq "$targetDB") -and 
        $_.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.instanceName -eq $targetInstance -and
        $_.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName -eq $targetServer}
    }
    if($restores){
        $previousRestore = $restores[0]
        if($previousRestore.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.PSObject.Properties['restoreTimeSecs']){
            $previousRestoreUsecs = $previousRestore.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.restoreTimeSecs * 1000000
        }else{
            $previousRestoreUsecs = $previousRestore.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.startTimeUsecs
        }
    }
    if($newRestoreUsecs -le $previousRestoreUsecs ){
        Write-Host "Target database is already up to date" -ForegroundColor Yellow
        exit 0
    }
}

# execute the recovery task (post /recoverApplication api call)
$response = api post /recoverApplication $restoreTask

if($response){
    Write-Host "Restoring $thisSourceInstance/$sourceDB to $targetServer/$targetInstance/$targetDB (Point in time: $restoreTime)"
}else{
    exit 1
}

if($wait -or $progress){
    $lastProgress = -1
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    if($taskId){
        $finishedStates = @('kSuccess','kFailed','kCanceled', 'kFailure')
        while($True){
            $task = api get /restoretasks/$taskId
            $status = $task.restoreTask.performRestoreTaskState.base.publicStatus
            if($progress){
                $progressMonitor = api get "/progressMonitors?taskPathVec=restore_sql_$($taskId)&includeFinishedTasks=true&excludeSubTasks=false"
                try{
                    $percentComplete = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
                    if($percentComplete -gt $lastProgress){
                        Write-Host $("{0} percent complete" -f [math]::Round($percentComplete, 0))
                        $lastProgress = $percentComplete
                    }
                }catch{
                    $percentComplete = 0
                    Write-Host $("{0} percent complete" -f [math]::Round($percentComplete, 0))
                    $lastProgress = 0
                }
            }
            if ($status -in $finishedStates){
                break
            }
            Start-Sleep $sleepTimeSecs
        }
        Write-Host "restore ended with $status"
        if($status -eq 'kSuccess'){
            exit 0
        }else{
            if($status -eq 'kFailure'){
                if($returnErrorMessage){
                    $($task.restoreTask.performRestoreTaskState.base.error.errorMsg)
                }else{
                    Write-Host "Error Message: $($task.restoreTask.performRestoreTaskState.base.error.errorMsg)"
                }
            }
            exit 1
        }
    }else{
        if($returnErrorMessage){
            "Failed to get restore task ID"
        }else{
            Write-Host "Failed to get restore task ID" -ForegroundColor Yellow
        }
        exit 1
    }
}

exit 0
