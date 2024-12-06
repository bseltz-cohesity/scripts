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
    [Parameter(Mandatory = $True)][string]$objectName,
    [Parameter()][string]$jobName,
    [Parameter()][array]$filePath,
    [Parameter()][string]$fileList,
    [Parameter()][string]$downloadPath = '.',
    [Parameter()][datetime]$before,
    [Parameter()][datetime]$after,
    [Parameter()][switch]$abortOnMissing,
    [Parameter()][int]$sleepTime = 30,
    [Parameter()][ValidateSet('OneDrive','Sharepoint')][string]$objectType = 'OneDrive'
)

$sourceEnvironment = @{"OneDrive" = "kO365OneDrive"; "Sharepoint" = "kO365Sharepoint"}
$snapshotAction = @{"OneDrive" = "RecoverOneDrive"; "Sharepoint" = "RecoverSharePoint"}

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

# outfile
$cluster = api get cluster
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
    $jobId = ($snapshot.protectionGroupRunId -split ":")[0]
    $jobUidObjectId = ($snapshot.protectionGroupId -split ":")[-1]
    $instance = "attemptNum=1&clusterId=$($cluster.id)&clusterIncarnationId=$($cluster.incarnationId)&entityId=$($snapshot.objectId)&jobId=$jobId&jobInstanceId=$($snapshot.runInstanceId)&jobUidObjectId=$jobUidObjectId&useLibrarian=false&statFileEntries=false&jobStartTimeUsecs=$($snapshot.runStartTimeUsecs)&protectionSourceEnvironment=$($sourceEnvironment[$objectType])&maxEntries=100"
    listdir '/' $instance
}

$restoreIds = @()
$restoreParams = @()
$downloads = 0

# find the requested object
$protectedObjects = api get -v2 "data-protect/search/protected-objects?snapshotActions=$($snapshotAction[$objectType])&searchString=$objectName&environments=kO365"
$thisObject = $protectedObjects.objects | Where-Object name -eq $objectName
if(! $thisObject){
    Write-Host "No object $objectName found" -ForegroundColor Yellow
    exit 1
}
$allSnapshots = @()

# filter snapshots
if($jobName){
    $thisObject.latestSnapshotsInfo = @($thisObject.latestSnapshotsInfo | Where-Object protectionGroupName -eq $jobName)
    if($thisObject.latestSnapshotsInfo.Count -eq 0){
        Write-Host "No backups found for $objectName in protection group: $jobName"
    }
}
foreach($snapshotsInfo in $thisObject.latestSnapshotsInfo){
    $snapshots = api get -v2 "data-protect/objects/$($thisObject.id)/snapshots?protectionGroupIds=$($snapshotsInfo.protectionGroupId)&objectActionKeys=$($sourceEnvironment[$objectType])"
    $allSnapshots = @($allSnapshots + $snapshots.snapshots)
}
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
            "filesAndFolders" = @($global:filesToDownload)
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
        $response = api post -v2 "data-protect/recoveries/downloadFilesAndFoldersRecovery" $downloadParams
        $restoreIds = @($restoreIds + $response.id)
    }
    Start-Sleep 5
    $finishedStates = @('Succeeded', 'Warning', 'Canceled', 'Canceling', 'Failed', 'Skipped')
    $happyStates = @('Succeeded', 'Warning')
    $downloads = 1
    while($True){
        $stillRunning = $False
        $restoreTasks = api get -v2 "data-protect/recoveries?startTimeUsecs=$nowUsecs&recoveryActions=RecoverFiles,DownloadFilesAndFolders&includeTenants=true"
        $restoreTasks = $restoreTasks.recoveries | Where-Object {$_.id -in $restoreIds}
        
        foreach($recovery in $restoreTasks){
            if($recovery.status -notin $finishedStates){
                $stillRunning = $True
            }else{
                $restoreIds = @($restoreIds | Where-Object {$_ -ne $recovery.id})
                if($recovery.status -notin $happyStates){
                    Write-Host "recovery $($recovery.id) $($recovery.status)" -ForegroundColor Yellow
                }else{
                    $fileName = Join-Path -Path $downloadPath -ChildPath "$($objectType)Download-$(($objectName -split "@")[0])-$downloads.zip"
                    fileDownload -v2 -uri "data-protect/recoveries/$($recovery.id)/downloadFiles?clusterId=$($cluster.id)&includeTenants=true" -fileName $fileName
                    Write-Host "Downloaded file: $fileName"
                    $downloads += 1
                }
            }
        }
        if($stillRunning -eq $False -or $restoreIds.Count -eq 0){
            break
        }else{
            Start-Sleep $sleepTime
        }
    }
}
