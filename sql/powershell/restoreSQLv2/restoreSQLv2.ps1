# version 2025-12-15
# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory=$True)][string]$sourceServer,
    [Parameter()][array]$sourceDB,
    [Parameter()][string]$sourceDBList,
    [Parameter()][switch]$allDBs,
    [Parameter()][switch]$includeSystemDBs,
    [Parameter()][string]$sourceInstance,
    [Parameter()][array]$sourceNodes,
    [Parameter()][string]$targetServer = $sourceServer,
    [Parameter()][string]$targetInstance,
    [Parameter()][string]$targetDB,
    [Parameter()][string]$prefix,
    [Parameter()][string]$suffix,
    [Parameter()][string]$mdfFolder,
    [Parameter()][string]$ldfFolder = $mdfFolder,
    [Parameter()][hashtable]$ndfFolders,
    [Parameter()][switch]$noRecovery,
    [Parameter()][switch]$noStop,
    [Parameter()][datetime]$logTime,
    [Parameter()][int64]$logRangeDays = 14,
    [Parameter()][int64]$newerThan,
    [Parameter()][switch]$overwrite,
    [Parameter()][switch]$keepCdc,
    [Parameter()][switch]$captureTailLogs,
    [Parameter()][switch]$wait,
    [Parameter()][switch]$progress,
    [Parameter()][int64]$pageSize = 100,
    [Parameter()][int64]$dbsPerRecovery = 100,
    [Parameter()][int64]$sleepTime = 60,
    [Parameter()][switch]$exportPaths,
    [Parameter()][switch]$importPaths,
    [Parameter()][switch]$showPaths,
    [Parameter()][switch]$commit,
    [Parameter()][switch]$noLogs,
    [Parameter()][switch]$dbg
)

if($sleepTime -lt 30){
    $sleepTime = 30
}

if(! $commit -and ! $exportPaths -and ! $showPaths){
    Write-Host "Running in test mode. Please use the -commit switch to perform the recoveries" -ForegroundColor Yellow
}

$conflictingSelections = $False
if($allDBs){
    if($sourceDBList -ne '' -or $sourceDB.Count -gt 0){
        $conflictingSelections = $True
    }
}
if($sourceDBList -ne ''){
    if($sourceDB.Count -gt 0){
        $conflictingSelections = $True
    }
}
if($conflictingSelections -eq $True){
    Write-Host "Conflicting DB selections. Please use only one of -allDBs, -sourceDBList, -sourceDB" -ForegroundColor Yellow
    exit 1
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

$sourceDbNames = @(gatherList -Param $sourceDB -FilePath $sourceDBList -Name 'DBs' -Required $False)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

if(! $showPaths -and ! $exportPaths){
    $cluster = api get cluster
    if($cluster.clusterSoftwareVersion -lt '6.8.1'){
        Write-Host "This script requires Cohesity 6.8.1 or later" -ForegroundColor Yellow
        exit 1
    }
}

# import file paths
$exportFilePath = Join-Path -Path $PSScriptRoot -ChildPath "$sourceServer.json"
$importedFileInfo = $null
if($importPaths){
    if(!(Test-Path -Path $exportFilePath)){
        Write-Host "Import file $exportFilePath not found" -ForegroundColor Yellow
        exit 1
    }
    $importedFileInfo = Get-Content -Path $exportFilePath | ConvertFrom-JSON
}

if($newerThan){
    $newerThanUsecs = timeAgo $newerThan days
}

# find all databases on server
if($allDBs -or $exportPaths){
    $from = 0
    $allsearch = api get "/searchvms?environment=SQL&entityTypes=kSQL&vmName=$sourceServer&size=$pageSize&from=$from"
    $dbresults = @{'vms' = @()}
    if($allsearch.count -gt 0){
        while($True){
            $dbresults.vms = @($dbresults.vms + $allsearch.vms)
            if($allsearch.count -gt ($pageSize + $from)){
                $from += $pageSize
                $allsearch = api get "/searchvms?environment=SQL&entityTypes=kSQL&vmName=$sourceServer&size=$pageSize&from=$from"
            }else{
                break
            }
        }
    }
    $dbresults.vms = $dbresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer}

    if(! $dbresults.vms){
        Write-Host "no DBs found for $sourceServer" -ForegroundColor Yellow
        exit
    }

    # exportFileInfo
    if($exportPaths){
        $fileInfoVec = @()
        foreach($vm in $dbresults.vms){
            if($vm.vmDocument.objectId.entity.sqlEntity.PSObject.Properties['dbFileInfoVec']){
                $dbName = $vm.vmDocument.objectName
                $fileInfo = $vm.vmDocument.objectId.entity.sqlEntity.dbFileInfoVec
                $fileInfoVec = @($fileInfoVec + @{
                    'name' = $dbName
                    'fileInfo' = $fileInfo
                })
            }
        }
        $fileInfoVec | ConvertTo-JSON -Depth 99 | Out-File -FilePath $exportFilePath
        "Exported file paths to $exportFilePath"
        exit 0
    }

    # filter by source instance
    if($sourceInstance){
        $dbresults.vms = $dbresults.vms | Where-Object {($_.vmDocument.objectName -split '/')[0] -eq $sourceInstance}
        if(! $dbresults.vms){
            Write-Host "no DBs found for $sourceServer/$sourceInstance" -ForegroundColor Yellow
            exit
        }
    }

    # filter by source AAG nodes
    if($sourceNodes){
        $dbresults.vms = $dbresults.vms | Where-Object {
            ([array]$x = Compare-Object -Referenceobject $sourceNodes -DifferenceObject $_.vmDocument.objectAliases  -excludedifferent -IncludeEqual)
        }
        if(! $dbresults.vms){
            Write-Host "no DBs found for source nodes $($sourceNodes -join ', ')" -ForegroundColor Yellow
            exit
        }
    }

    # filter by age of most recent backup
    if($newerThan){
        $dbresults.vms = $dbresults.vms | Where-Object {$_.vmDocument.versions[0].instanceId.jobStartTimeUsecs -ge $newerThanUsecs}
        if(! $dbresults.vms){
            Write-Host "no DBs found newer than $newerThan days" -ForegroundColor Yellow
            exit
        }
    }

    $sourceDbNames = @($dbresults.vms.vmDocument.objectName | Sort-Object -Unique)

    if(! $includeSystemDBs){
        $sourceDbNames = $sourceDbNames | Where-Object {($_ -split '/')[-1] -notin @('Master', 'Model', 'MSDB')}
    }
}

if($sourceDbNames.Count -eq 0){
    Write-Host "No DBs specified for restore" -ForegroundColor Yellow
    exit
}

if($sourceDbNames.Count -gt 1 -and $targetDB){
    Write-Host "Can't specify -targetDB when more than one database is speficified. Please use -prefix or -suffix for renaming" -ForegroundColor Yellow
    exit
}

# find target server
$targetEntity = (api get protectionSources/registrationInfo?environments=kSQL).rootNodes | Where-Object { $_.rootNode.name -eq $targetServer }
if($null -eq $targetEntity -and ! $showPaths){
    Write-Host "Target Server $targetServer Not Found" -ForegroundColor Yellow
    exit 1
}

$restoreDate = Get-Date -UFormat '%Y-%m-%d_%H:%M:%S'

$desiredPIT = dateToUsecs
if($logTime){
    $desiredPIT = dateToUsecs $logTime
}

# recovery params
$skippedDBs = @()
$recoveryParamNum = 1
$dbsSelected = 0
$recoveryIds = @()
$recoveryParams = @{
    "name" = "Recover_MS_SQL_$($sourceServer)_$($restoreDate)_$($recoveryParamNum)";
    "snapshotEnvironment" = "kSQL";
    "mssqlParams" = @{
        "recoveryAction" = "RecoverApps";
        "recoverAppParams" = @()
    }
}

foreach($sourceDbName in $sourceDbNames | Sort-Object){
    if(! $sourceDbName.Contains('/')){
        if($sourceInstance){
            $sourceDbName = "$sourceInstance/$sourceDbName"
        }else{
            $sourceDbName = "MSSQLSERVER/$sourceDbName"
        }
    }
    $thisSourceInstance, $shortDbName = $sourceDbName -split '/'
    $search = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverApps&searchString=$shortDbName&environments=kSQL"
    $search.objects = $search.objects | Where-Object {$_.name -eq $sourceDbName -or ('/' -notin $_.name -and $_.name -eq $shortDbName)}
    $search.objects = $search.objects | Where-Object {$_.mssqlParams.hostInfo.name -eq $sourceServer -or $_.mssqlParams.aagInfo.name -eq $sourceServer}
    
    if($search.objects.Count -eq 0){
        Write-Host "$sourceDbName not found on server $sourceServer" -ForegroundColor Yellow
        continue
    }
    if($dbg){
        $search | toJson | Out-File -FilePath debug-search1.json
    }
    
    $ranges = @()
    foreach($obj in $search.objects){
        $objId = $obj.id
        foreach($protection in $obj.latestSnapshotsInfo | Sort-Object -Property protectionRunStartTimeUsecs -Descending){
            $protectionGroupId = $protection.protectionGroupId
            $snapshots = api get -v2 "data-protect/objects/$objId/snapshots?protectionGroupIds=$protectionGroupId"
            $snapshots.snapshots = @($snapshots.snapshots | Where-Object runStartTimeUsecs -le $desiredPIT)
            if($newerThan){
                $snapshots.snapshots = @($snapshots.snapshots | Where-Object runStartTimeUsecs -ge $newerThanUsecs)
            }
            foreach($snapshot in $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending){
                $ranges = @($ranges + @{'object' = $obj ;'snapshot' = $snapshot; 'protection' = $protection; 'pit' = $snapshot.runStartTimeUsecs})
                break
            }
        }
    }

    Write-Host "`n$($search.objects[0].name)"
    if(@($ranges).Count -gt 0){
        $range = $ranges[0]
    }else{
        Write-Host "    No snapshots for $logTime, skipping" -ForegroundColor Yellow
        continue
    }

    if(!$noLogs){
        $clusterId, $clusterIncarnationId, $jobId = $range.protection.protectionGroupId -split ':'

        $logRangeLimitUsecs = $desiredPIT - ($logRangeDays * 86400000000)
        $logRangeStart = $range.pit
        if($logRangeLimitUsecs -gt $logRangeStart){
            $logRangeStart = $logRangeLimitUsecs
        }

        # PIT lookup
        $pitQuery = @{
            "jobUids" = @(
                @{
                    "clusterId" = [int64]$clusterId;
                    "clusterIncarnationId" = [int64]$clusterIncarnationId;
                    "id" = [int64]$jobId
                }
            );
            "environment" = "kSQL";
            "protectionSourceId" = $range.object.id;
            "startTimeUsecs" = $logRangeStart;
            "endTimeUsecs" = $desiredPIT
        }
        $logs = api post restore/pointsForTimeRange $pitQuery
        if($logs.PSObject.Properties['timeRanges']){
            foreach($timeRange in $logs.timeRanges){
                if($desiredPIT -ge $timeRange.startTimeUsecs){
                    if($desiredPIT -ge $timeRange.endTimeUsecs -and $timeRange.endTimeUsecs -gt $range.pit){
                        $range.pit = $timeRange.endTimeUsecs
                    }elseif($desiredPIT -lt $timeRange.endTimeUsecs){
                        $range.pit = $desiredPIT
                    }
                }
            }
        }
    }

    $thisSourceServer = $search.objects[0].mssqlParams.hostInfo.name

    if(! $showPaths){
        Write-Host "    Selected Snapshot $(usecsToDate $range.snapshot.runStartTimeUsecs)"
        if($desiredPIT -and $desiredPIT -gt $range.pit){
            Write-Host "    Best available PIT is $(usecsToDate $range.pit)" -ForegroundColor Yellow
        }elseif($desiredPIT -and $desiredPIT -lt $range.pit){
            Write-Host "    Best available PIT is $(usecsToDate $range.pit)" -ForegroundColor Yellow
        }
        Write-Host "    Selected PIT $(usecsToDate $range.pit)"
    }

    $thisParam  = @{
        "snapshotId" = $range.snapshot.id;
        "targetEnvironment" = "kSQL";
        "sqlTargetParams" = @{
            "recoverToNewSource" = $false;
            "originalSourceConfig" = @{
                "keepCdc" = $false;
                "withNoRecovery" = $false;
                "captureTailLogs" = $false
            }
        }
    }

    if(! $nologs){
        if($range.pit -ne $range.snapshot.runStartTimeUsecs){
            $thisParam['pointInTimeUsecs'] = $range.pit
            $thisParam.sqlTargetParams.originalSourceConfig['restoreTimeUsecs'] = $range.pit
        }
    }

    $targetConfig = $thisParam.sqlTargetParams.originalSourceConfig
    if($captureTailLogs){
        $targetConfig.captureTailLogs = $True        
    }

    # rename DB
    $newDbName = $shortDbName
    $renameDB = $false
    if($targetDB -or $prefix -or $suffix){
        $renameDB = $True
        if($targetDB){
            $newDbName = $targetDB
        }
        if($prefix){
            $newDbName = "$($prefix)-$($newDbName)"
        }
        if($suffix){
            $newDbName = "$($newDbName)-$($suffix)"
        }
        $thisParam.sqlTargetParams.originalSourceConfig['newDatabaseName'] = $newDbName
    }

    # recover to alternate instance
    $alternateInstance = $false
    if($targetServer -ne $thisSourceServer -or ($targetInstance -and $targetInstance -ne $thisSourceInstance)){
        $alternateInstance = $True
        if(! $targetInstance){
            $targetInstance = 'MSSQLSERVER'
        }
        $targetInstanceObj = ($targetEntity.applications | Where-Object environment -eq kSQL).applicationTreeInfo | Where-Object {$_.protectionSource.name -eq $targetInstance}
        if(! $targetInstanceObj){
            Write-Host "    Target instance $($targetEntity.rootNode.name)/$($targetInstance) not found" -ForegroundColor Yellow
            exit 1
        }
        $thisParam.sqlTargetParams = @{
            "recoverToNewSource" = $true;
            "newSourceConfig" = @{
                "host" = @{
                    "id" = $targetEntity.rootNode.id
                };
                "instanceName" = $targetInstanceObj.protectionSource.name;
                "keepCdc" = $false;
                "withNoRecovery" = $false;
                "databaseName" = $newDbName
            }
        }

        $targetConfig = $thisParam.sqlTargetParams.newSourceConfig
        if(! $noLogs){
            if($range.pit -ne $range.snapshot.runStartTimeUsecs){
                $targetConfig['restoreTimeUsecs'] = $range.pit
            }
        }
    }else{
        if($renameDB -eq $false){
            if(! $overWrite -and ! $showPaths){
                Write-Host "Please use -overwrite to overwrite original database(s)" -ForegroundColor Yellow
                exit 1
            }
        }
    }

    # file destinations
    if($alternateInstance -eq $True -or $renameDB -eq $True -or $showPaths){
        # use source paths
        $secondaryFileLocation = $null
        if(! $mdfFolder){
            $useSourcePaths = $True
        }
        if($useSourcePaths -or $showPaths){
            $dbFileInfoVec = $null
            if($importedFileInfo){
                $importedDBFileInfo = $importedFileInfo | Where-Object {$_.name -eq $sourceDbName}
                if($importedDBFileInfo){
                    $dbFileInfoVec = $importedDBFileInfo.fileInfo                    
                }
            }else{
                $fileSearch = api get "/searchvms?environment=SQL&entityIds=$($range.object.id)"
                if($fileSearch.vms[0].vmDocument.objectId.entity.sqlEntity.PSObject.Properties['dbFileInfoVec']){
                    $dbFileInfoVec = $fileSearch.vms[0].vmDocument.objectId.entity.sqlEntity.dbFileInfoVec
                }
            }
            if(! $dbFileInfoVec){
                if(! $mdfFolder){
                    Write-Host "    Skipping: File info not found, please use -mdfFolder, -ldfFolder, -ndfFolders (or -importPaths)" -ForegroundColor Yellow
                    $skippedDBs = @($skippedDBs + $sourceDbName)
                    continue
                }
            }
            if($showPaths){
                $dbFileInfoVec | Format-Table -Property logicalName, @{l='Size (MiB)'; e={$_.sizeBytes / (1024 * 1024)}}, fullPath
                # exit 0
            }
            $mdfFolderFound = $False
            $ldfFolderFound = $False
            $secondaryFileLocation = @()
            foreach($datafile in $dbFileInfoVec){
                $path = $datafile.fullPath.subString(0, $datafile.fullPath.LastIndexOf('\'))
                if($datafile.type -eq 0){
                    if($mdfFolderFound -eq $False){
                        $mdfFolder = $path
                        $mdfFolderFound = $True
                    }else{
                        $secondaryFileLocation = @($secondaryFileLocation + @{"filenamePattern" = $datafile.fullPath; "directory" = $path})
                    }
                }
                if($datafile.type -eq 1){
                    if($ldfFolderFound -eq $False){
                        $ldfFolder = $path
                        $ldfFolderFound = $True
                    }else{
                        $secondaryFileLocation = @($secondaryFileLocation + @{"filenamePattern" = $datafile.fullPath; "directory" = $path})
                    }
                }
            }
        }
        if(! $mdfFolder -or ! $ldfFolder){
            Write-Host "    Skipping: File info not found, please use -mdfFolder, -ldfFolder, -ndfFolders (or -importPaths)" -ForegroundColor Yellow
            $skippedDBs = @($skippedDBs + $sourceDbName)
            continue
        }
        $targetConfig['dataFileDirectoryLocation'] = $mdfFolder
        $targetConfig['logFileDirectoryLocation'] = $ldfFolder
        if($secondaryFileLocation){
            $targetConfig['secondaryDataFilesDirList'] = $secondaryFileLocation
        }elseif($ndfFolders){
            $ndfParams = @()
            foreach($key in $ndfFolders.Keys){
                $ndfParams = @($ndfParams + @{"filenamePattern" = "$key"; "directory" = $ndfFolders["$key"]})
            }
            $targetConfig['secondaryDataFilesDirList'] = @($ndfParams)
        }
    }

    # overwrite
    if($overWrite){
        $targetConfig['overwritingPolicy'] = 'Overwrite'
    }

    # no recovery
    if($noRecovery){
        $targetConfig['withNoRecovery'] = $True
    }

    # keep CDC
    if($keepCdc){
        $targetConfig['keepCdc'] = $True
    }

    # add this param to recovery params
    if(! $showPaths -and $commit){
        $recoveryParams.mssqlParams.recoverAppParams = @($recoveryParams.mssqlParams.recoverAppParams + $thisParam)
        $dbsSelected += 1
    }

    # perform recovery group
    if($dbsSelected -ge $dbsPerRecovery){
        # perform this recovery
        $recovery = api post -v2 data-protect/recoveries $recoveryParams
        if(! $recovery.id){
            exit 1
        }
        $recoveryIds = @($recoveryIds + $recovery.id)
        # reset params for next recovery
        $recoveryParamNum += 1
        $dbsSelected = 0
        $recoveryParams = @{
            "name" = "Recover_MS_SQL_$($sourceServer)_$($restoreDate)_$($recoveryParamNum)";
            "snapshotEnvironment" = "kSQL";
            "mssqlParams" = @{
                "recoveryAction" = "RecoverApps";
                "recoverAppParams" = @()
            }
        }
    }
}

if($dbg){
    $recoveryParams | toJson | Out-File -FilePath debug-recoveryParams.json
}

# perform last recovery group (if any)
if($recoveryParams.mssqlParams.recoverAppParams.Count -gt 0){
    $recovery = api post -v2 data-protect/recoveries $recoveryParams
    if(! $recovery.id){
        exit 1
    }
    $recoveryIds = @($recoveryIds + $recovery.id)
}

# wait for completion
$failuresDetected = $False
if(($wait -or $progress) -and $recoveryIds.Count -gt 0){
    $finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning')
    Write-Host "`nWaiting for recoveries to complete...`n"
    Start-Sleep 10
    foreach($recoveryId in $recoveryIds){
        $thisRecovery = api get -v2 "data-protect/recoveries/$recoveryId"
        $finishedDBs = @()
        while($thisRecovery.status -notin $finishedStates){
            if($progress){
                $dbStatus = 'unknown'
                while($dbStatus -notin $finishedStates){
                    $dbStatus = 'Succeeded'
                    $childRecoveries = api get -v2 "data-protect/recoveries?returnOnlyChildRecoveries=true&ids=$recoveryId"
                    foreach($childRecovery in $childRecoveries.recoveries | Sort-Object -Property {$_.mssqlParams.recoverAppParams[0].objectInfo.name}){
                        $dbName = $childRecovery.mssqlParams.recoverAppParams[0].objectInfo.name
                        $status = $childRecovery.status
                        if(! $status){
                            $dbStatus = 'unknown'
                        }
                        if($status -notin $finishedStates){
                            $dbStatus = $status
                        }
                        $progressTaskId = $childRecovery.progressTaskId
                        $progressMonitor = api get "/progressMonitors?taskPathVec=$progressTaskId&excludeSubTasks=true&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0"
                        $percentComplete = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
                        if($percentComplete -gt 0){
                            if($dbName -notin $finishedDBs){
                                Write-Host "`r$($dbName): $([math]::Round($percentComplete, 0))%" -NoNewLine
                                if([math]::Round($percentComplete, 0) -eq 100){
                                    Write-Host " $status"
                                    $finishedDBs = @($finishedDBs + $dbName)
                                }
                            }
                        }
                    }
                    if($dbStatus -notin $finishedStates){
                        Start-Sleep $sleepTime
                    }
                }
                Write-Host ""
            }else{
                Start-Sleep $sleepTime
            }
            $thisRecovery = api get -v2 "data-protect/recoveries/$recoveryId"
        }
        $childRecoveries = api get -v2 "data-protect/recoveries?returnOnlyChildRecoveries=true&ids=$recoveryId"
        foreach($childRecovery in $childRecoveries.recoveries | Sort-Object -Property {$_.mssqlParams.recoverAppParams[0].objectInfo.name}){
            $dbName = $childRecovery.mssqlParams.recoverAppParams[0].objectInfo.name
            $status = $childRecovery.status
            Write-Host "$dbName completed with status: $status"
            if($childRecovery.messages){
                Write-Host "$($childRecovery.messages[0])" -ForegroundColor Yellow
            }
            if($status -ne 'Succeeded'){
                $failuresDetected = $True
            }
        }
    }
    if($failuresDetected -or $recoveryIds.Count -eq 0){
        Write-Host "`nFailures Detected`n" -ForegroundColor Yellow
        if($skippedDBs.Count -gt 0){
            Write-Host "Skipped DBs (missing file paths):`n`n$($skippedDBs -join "`n")`n" -ForegroundColor Yellow
        }
        exit 1
    }else{
        Write-Host "`nRestores Completed Successfully`n" -ForegroundColor Green
        if($skippedDBs.Count -gt 0){
            Write-Host "Skipped DBs (missing file paths):`n`n$($skippedDBs -join "`n")`n" -ForegroundColor Yellow
            exit 1
        }
        exit 0
    }
}elseif($recoveryIds.Count -gt 0){
    Write-Host "`nPerforming recoveries...`n"
}else{
    Write-Host ""
}
if(! $commit){
    Write-Host "Exiting without recovering. Please use the -commit switch to perform the recoveries" -ForegroundColor Yellow
    exit 0
}
if($skippedDBs.Count -gt 0){
    Write-Host "Skipped DBs (missing file paths):`n`n$($skippedDBs -join "`n")`n" -ForegroundColor Yellow
    exit 1
}

exit 0
