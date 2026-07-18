# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$objectName,
    [Parameter()][string]$sourceName,
    [Parameter()][array]$filePath,
    [Parameter()][string]$fileList,
    [Parameter()][string]$downloadPath = '.',
    [Parameter()][datetime]$before,
    [Parameter()][datetime]$after,
    [Parameter()][switch]$abortOnMissing,
    [Parameter()][int]$sleepTimeSeconds = 30,
    [Parameter()][ValidateSet('OneDrive','Sharepoint')][string]$objectType = 'OneDrive'
)

$sourceEnvironment = @{"OneDrive" = "kO365OneDrive"; "Sharepoint" = "kO365Sharepoint"} # kO365OneDrive

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
apiauth -username $username -password $password -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# end authentication =========================================

# outfile
$nowUsecs = (dateToUsecs) - 60000000

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

$filePaths = @(gatherList -Param $filePath -FilePath $fileList -Name 'file paths' -Required $false)
$foundPaths = @()

$allFiles = $False
if($filePaths.Count -eq 0){
    $allFiles = $True
}

function listdir($dirPath, $instance, $cookie=$null){
    $thisDirPath = [System.Web.HttpUtility]::UrlEncode($dirPath).Replace('%2f%2f','%2F')
    if($cookie){
        $dirList = api get "/vm/directoryList?$instance&cookie=$cookie&dirPath=$thisDirPath"
    }else{
        $dirList = api get "/vm/directoryList?$instance&dirPath=$thisDirPath"
    }
    if($dirList.PSObject.Properties['entries'] -and $dirList.entries.Count -gt 0){
        foreach($entry in $dirList.entries | Sort-Object -Property name){
            $entryPath = ((("$($dirPath)/$($entry.name)") -replace '//', '/') -split '/metadata/rocksdb')[-1]
            if($allFiles){
                $global:filesToDownload = @($global:filesToDownload + @{"absolutePath" = $entryPath; "isDirectory" = $($entry.type -eq 'kDirectory')})
            }else{
                $recurse = $False
                foreach($fpath in $filePaths){
                    if($fpath -match $entryPath){
                        if($fpath -eq $entryPath){
                            $global:filesToDownload = @($global:filesToDownload + @{"absolutePath" = $entryPath; "isDirectory" = $($entry.type -eq 'kDirectory')})
                        }else{
                            if($entry.type -eq 'kDirectory'){
                                $recurse = $True
                            }
                        }
                    }
                }
                if($recurse -eq $True){
                    listdir $entry.fullPath $instance
                }
            }
        }
    }
    if($dirlist.PSObject.Properties['cookie'] -and $global:foundFile -eq $False){
        listdir "$dirPath" $instance $dirlist.cookie
    }
}

function findFiles($snapshot){
    $archivalTaskId = $snapshot.externalTargetInfo.archivalTaskId -split ':'
    $clusterId = $archivalTaskId[0]
    $clusterIncarnationId = $archivalTaskId[1]
    $runStartTimeUsecs = ($snapshot.protectionGroupRunId -split ':')[-1]
    $instance = "attemptNum=1&clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$($snapshot.objectId)&jobId=-1&jobInstanceId=$($snapshot.runInstanceId)&jobUidObjectId=-1&useLibrarian=true&statFileEntries=false&jobStartTimeUsecs=$runStartTimeUsecs&protectionSourceEnvironment=$($sourceEnvironment[$objectType])&maxEntries=100"
    listdir '/' $instance
}

$restoreIds = @()
$restoreParams = @()
$downloads = 0

# find the requested object
$protectedObjects = api get -v2 "data-protect/search/protected-objects?o365ObjectTypes=$($sourceEnvironment[$objectType])&searchString=$objectName&environments=kO365&regionIds=$region" # ,kUser

$thisObject = $protectedObjects.objects | Where-Object {$_.name -eq $objectName -or $_.o365Params.primarySMTPAddress -eq $objectName}
if($thisObject -and $sourceName){
    $thisObject = $thisObject | Where-Object {$_.sourceInfo.name -eq $sourceName}
}
if(! $thisObject){
    Write-Host "No object $objectName found" -ForegroundColor Yellow
    exit 1
}

$allSnapshots = @()

# filter snapshots
$snapshots = api get -v2 "data-protect/objects/$($thisObject.id)/snapshots?objectActionKeys=$($sourceEnvironment[$objectType])&regionId=$region"
$allSnapshots = @($allSnapshots + $snapshots.snapshots)

if($before){
    $beforeUsecs = dateToUsecs $before
    $allSnapshots = @($allSnapshots | Where-Object runStartTimeUsecs -le $beforeUsecs)
}
if($after){
    $afterUsecs = dateToUsecs $after
    $allSnapshots = @($allSnapshots | Where-Object runStartTimeUsecs -ge $afterUsecs)
}
if($allSnapshots.Count -eq 0){
     Write-Host "No backups found for $objectName from the specified time range" -ForegroundColor Yellow
     exit 1
}

# find files for download
foreach($snapshot in $allSnapshots | Sort-Object -Property runStartTimeUsecs -Descending){
    "Looking for files in backup from $(usecsToDate $snapshot.runStartTimeUsecs)..."
    $global:filesToDownload = @()
    findFiles $snapshot
    if($global:filesToDownload.Count -gt 0){
        $downloads += 1
        $downloadParams = @{
            "name" = "Download_Files_$($objectName)_$($downloads)";
            "object" = @{
                "snapshotId" = $snapshot.id
            };
            "filesAndFolders" = @($global:filesToDownload);
            "ContinueOnError" = $True
        }
        $restoreParams = @($restoreParams + $downloadParams)
    }
    $foundPaths = @($foundPaths + $global:filesToDownload.absolutePath)
    if($allFiles -eq $false){
        $filePaths = @($filePaths | Where-Object {$_ -notin $global:filesToDownload.absolutePath})
        if($filePaths.Count -eq 0){
            break
        }
    }else{
        break
    }
}

# report missing paths
if($filePaths.Count -gt 0){
    Write-Host "The following paths were not found" -ForegroundColor Yellow
    $filePaths | ForEach-Object{
        Write-Host "    $_" -ForegroundColor Yellow
    }
    if($abortOnMissing){
        Write-Host "Aborting due to missing files/folders" -ForegroundColor Yellow
        exit 1
    }
}

# perform download tasks
if($restoreParams.Count -gt 0){
    Write-Host "Waiting for download tasks..."
    foreach($downloadParams in $restoreParams){
        $response = api post -v2 "data-protect/recoveries/downloadFilesAndFoldersRecovery?regionIds=$region" $downloadParams
        if($cohesity_api.last_api_error -eq 'Duplicate API request'){
            Write-Host "Looking for previous download task..."
            $foundOldRecovery = $False
            $recoveryQuery = @{
                "statsParams" = @{
                    "attributes" = @(
                        "Status";
                        "ActivityType"
                    )
                };
                "statuses" = @(
                    "Succeeded"
                );
                "fromTimeUsecs" = timeAgo 1 hour;
                "toTimeUsecs" = timeAgo 1 second;
                "environments" = @(
                    "kO365"
                );
                "restoreParams" = @{
                    "recoveryTypes" = @(
                        "RecoverSharePoint";
                        "RecoverSharePointCSM";
                        "DownloadFilesAndFolders"
                    )
                };
                "activityTypes" = @(
                    "Restore"
                );
                "excludeStats" = $true
            }
            $recoveries = api post -mcmv2 "data-protect/objects/activity?regionIds=$region" $recoveryQuery
            foreach($activity in $recoveries.activity){
                $thisRecovery = api get -v2 "data-protect/recoveries/$($activity.recoveryParams.id)?includeTenants=true&regionId=$region"
                if($thisRecovery.office365Params.objects[0].snapshotId -eq $downloadParams.object.snapshotId){
                    $match = $True
                    foreach($path in $downloadParams.filesAndFolders.absolutePath){
                        if($path -notin @($thisRecovery.office365Params.downloadFileAndFolderParams.filesAndFolders.absolutePath)){
                            $match = $false
                        }
                    }
                    if($match -eq $True){
                        $restoreIds = @($restoreIds + $thisRecovery.id)
                        $foundOldRecovery = $True
                        break
                    }
                }
            }
            if($foundOldRecovery -eq $False){
                Write-Host "Couldn't find existing recovery to download" -ForegroundColor Yellow
            }
        }else{
            $restoreIds = @($restoreIds + $response.id)
        }   
    }

    Start-Sleep 5
    $finishedStates = @('Succeeded', 'Warning', 'Canceled', 'Canceling', 'Failed', 'Skipped')
    $happyStates = @('Succeeded', 'Warning')
    $downloads = 1
    # wait for recovery to complete
    $finishedStates = @('Canceled', 'Succeeded', 'Failed')
    $pass = 0
    $recoveryNum = 0
    foreach($restoreId in $restoreIds){
        $recoveryNum += 1
        do{
            $recoveryTask = api get -v2 "data-protect/recoveries/$($restoreId)?includeTenants=true&regionId=$region"
            $status = $recoveryTask.status
            if($status -notin $finishedStates){
                Start-Sleep $sleepTimeSeconds
            }
        } until ($status -in $finishedStates)
        # download files
        $downloadURL = "https://helios.cohesity.com/v2/data-protect/recoveries/$restoreId/downloadFiles?regionId=$region&includeTenants=true"
        if($status -eq 'Succeeded'){
            $restoreIdString = $restoreId -replace ':', '-'
            $thisFileName = "download-$($restoreIdString).zip"
            Write-Host "==> Downloading zip file $thisFilename"
            fileDownload -uri $downloadURL -filename "$thisFilename"
        }else{
            Write-Host "*** PST conversion finished with status: $status ***"
        }
    }
}
