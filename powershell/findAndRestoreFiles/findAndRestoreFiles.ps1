# version 2023.01.29

### process commandline arguments
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
    [Parameter(Mandatory = $True)][string]$sourceObject, # source server
    [Parameter(Mandatory = $True)][string]$jobName, # narrow search by job name
    [Parameter()][switch]$showVersions,
    [Parameter()][switch]$listFiles,
    [Parameter()][datetime]$backupNewerThan,
    [Parameter()][datetime]$backupOlderThan,
    [Parameter()][datetime]$filesNewerThan,
    [Parameter()][datetime]$filesOlderThan,
    [Parameter()][string]$matchString,
    [Parameter()][Int64]$runId,
    [Parameter()][datetime]$fileDate,
    [Parameter()][string]$startPath = '/',
    [Parameter()][switch]$showStats = $True,
    [Parameter()][switch]$recurse,
    [Parameter()][switch]$restore,
    [Parameter()][switch]$restorePrevious,
    [Parameter()][string]$restoreFileList = '',
    [Parameter()][string]$targetObject = $sourceObject,
    [Parameter()][string]$targetRegisteredSource,
    [Parameter()][string]$restorePath,
    [Parameter()][int]$maxFilesPerRestore = 500,
    [Parameter()][switch]$overwrite,
    [Parameter()][ValidateSet('ExistingAgent','AutoDeploy','VMTools')][string]$restoreMethod = 'AutoDeploy',
    [Parameter()][int]$vlan = 0,
    [Parameter()][string]$vmUser, # user name for vmtools 
    [Parameter()][string]$vmPwd # password for vm tools
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$restoreMethods = @{
    'ExistingAgent' = 'UseExistingAgent';
    'AutoDeploy' = 'AutoDeploy';
    'VMTools' = 'UseHypervisorApis'
}

if($overWrite){
    $override = $True
}else{
    $override = $False
}

if(! $restorePrevious){
    Remove-Item -Path "filesToRestore.tsv" -ErrorAction SilentlyContinue
    "Path`tFileName`tRunID`tBytes" | Out-File -FilePath "filesToRestore.tsv"
}

$startPath = "/" + $startPath.Replace('\','/').Replace('//','/')
$volPath = $null
if($startPath -match ':'){
    $volPath, $startPath = $startPath -split ':'
    $startPath = "$($volPath)$($startPath)"
}
$startPath = $startPath.Replace('//','/')
$script:foundStartPath = $False
$script:sawFiles = @()
$script:useLibrarian = $True
$script:fileCount = 0
$script:totalSize = 0

if($filesNewerThan){
    $filesNewerThanUsecs = dateToUsecs $filesNewerThan
    $showStats = $True
    $listFiles = $True
}else{
    $filesNewerThanUsecs = 0
}

if($filesOlderThan){
    $filesOlderThanUsecs = dateToUsecs $filesOlderThan
    $showStats = $True
    $listFiles = $True
}else{
    $filesOlderThanUsecs = dateToUsecs
}

if($showStats -or $filesNewerThan -or $filesOlderThan){
    $statfile = $True
}else{
    $statfile = $False
}

$volumeTypes = @(1, 6)

### authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

### select helios/mcm managed cluster
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

function listdir($dirPath, $instance, $volumeInfoCookie=$null, $volumeName=$null, $cookie=$null){
    $thisDirPath = [System.Web.HttpUtility]::UrlEncode($dirPath).Replace('%2f%2f','%2F')

    if($cookie){
        if($null -ne $volumeName){
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$($script:useLibrarian)&statFileEntries=$statfile&volumeInfoCookie=$volumeInfoCookie&cookie=$cookie&volumeName=$volumeName&dirPath=$thisDirPath"
        }else{
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$($script:useLibrarian)&statFileEntries=$statfile&cookie=$cookie&dirPath=$thisDirPath"
        }
    }else{
        if($null -ne $volumeName){
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$($script:useLibrarian)&statFileEntries=$statfile&volumeInfoCookie=$volumeInfoCookie&volumeName=$volumeName&dirPath=$thisDirPath"
        }else{
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$($script:useLibrarian)&statFileEntries=$statfile&dirPath=$thisDirPath"
        }
    }
    if($dirList.PSObject.Properties['entries'] -and $dirList.entries.Count -gt 0){
        $script:filesFound = $True
        foreach($entry in $dirList.entries | Sort-Object -Property name){
            if($entry.type -eq 'kDirectory' -and $startPath -match "$($entry.fullPath)"){
                listdir "$dirPath/$($entry.name)" $instance $volumeInfoCookie $volumeName
            }elseif($entry.type -eq 'kDirectory' -and $entry.fullPath -match $startPath -and $recurse){
                listdir "$dirPath/$($entry.name)" $instance $volumeInfoCookie $volumeName
            }else{
                if($entry.fullPath -match "^$($startPath)"){
                    if($statfile){
                        $filesize = $entry.fstatInfo.size
                        $mtime = usecsToDate $entry.fstatInfo.mtimeUsecs
                        if($entry.fstatInfo.mtimeUsecs -ge $filesNewerThanUsecs -and $entry.fstatInfo.mtimeUsecs -le $filesOlderThanUsecs){
                            if(! $matchString -or $entry.fullPath -match $matchString){
                                if($filesNewerThan -or $filesOlderThan){
                                    if($entry.fullPath -notin $script:sawFiles){
                                        "{0} ({1}) [{2} bytes]" -f $entry.fullPath, $mtime, $filesize
                                        $script:sawFiles = @($script:sawFiles + $entry.fullPath)
                                        "$($entry.fullPath.subString(0,$($entry.fullPath.LastIndexOf('/'))))`t$($entry.name)`t$($version.instanceId.jobInstanceId)`t$($filesize)" | Out-File -FilePath "filesToRestore.tsv" -Append
                                        # "$($entry.fullPath)" | Out-File -FilePath "filesToRestore-$($version.instanceId.jobInstanceId).txt" -Append
                                        $script:fileCount += 1
                                        $script:totalSize += $filesize
                                    }
                                }else{
                                    $script:fileCount += 1
                                    $script:totalSize += $filesize
                                    "$($entry.fullPath.subString(0,$($entry.fullPath.LastIndexOf('/'))))`t$($entry.name)`t$($version.instanceId.jobInstanceId)`t$($filesize)" | Out-File -FilePath "filesToRestore.tsv" -Append
                                    "{0} ({1}) [{2} bytes]" -f $entry.fullPath, $mtime, $filesize # | Tee-Object -FilePath $outputfile -Append
                                }
                            }
                        }
                    }else{
                        if(! $matchString -or $entry.fullPath -match $matchString){
                            "$($entry.fullPath.subString(0,$($entry.fullPath.LastIndexOf('/'))))`t$($entry.name)`t$($version.instanceId.jobInstanceId)`t$($filesize)" | Out-File -FilePath "filesToRestore.tsv" -Append           
                            "{0}" -f $entry.fullPath # | Tee-Object -FilePath $outputfile -Append
                        }
                    }
                }
            }
        }
    }
    if($dirlist.PSObject.Properties['cookie']){
        listdir "$dirPath" $instance $volumeInfoCookie $volumeName $dirlist.cookie
    }
}

function showFiles($doc, $version){
    if($version.numEntriesIndexed -eq 0){
        $script:useLibrarian = $False
    }else{
        $script:useLibrarian = $True
    }
    if(($version.replicaInfo.replicaVec | Sort-Object -Property {$_.target.type})[0].target.type -eq 3){
        $script:useLibrarian = $True
    }
    Remove-Item -Path "filesToRestore-$($version.instanceId.jobInstanceId).txt" -ErrorAction SilentlyContinue
    # $script:fileCount = 0
    # $script:totalSize = 0
    $script:filesFound = $False
    $versionDate = (usecsToDate $version.instanceId.jobStartTimeUsecs).ToString('yyyy-MM-dd_hh-mm-ss')
    $sourceObjectString = $sourceObject.Replace('\','-').Replace('/','-')
    $outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "backedUpFiles-$($version.instanceId.jobInstanceId)-$($sourceObjectString)-$versionDate.txt")
    $null = Remove-Item -Path $outputfile -Force -ErrorAction SilentlyContinue
    if(! $version.instanceId.PSObject.PRoperties['attemptNum']){
        $attemptNum = 0
    }else{
        $attemptNum = $version.instanceId.attemptNum
    }
    $instance = "attemptNum={0}&clusterId={1}&clusterIncarnationId={2}&entityId={3}&jobId={4}&jobInstanceId={5}&jobStartTimeUsecs={6}&jobUidObjectId={7}" -f
                $attemptNum,
                $doc.objectId.jobUid.clusterId,
                $doc.objectId.jobUid.clusterIncarnationId,
                $doc.objectId.entity.id,
                $doc.objectId.jobId,
                $version.instanceId.jobInstanceId,
                $version.instanceId.jobStartTimeUsecs,
                $doc.objectId.jobUid.objectId
    
    $backupType = $doc.backupType
    if($backupType -in $volumeTypes){
        $volumeList = api get "/vm/volumeInfo?$instance&statFileEntries=$statfile"
        if($volumeList.PSObject.Properties['volumeInfos']){
            $volumeInfoCookie = $volumeList.volumeInfoCookie
            foreach($volume in $volumeList.volumeInfos | Sort-Object -Property name){
                $volumeName = [System.Web.HttpUtility]::UrlEncode($volume.name)
                if(! $volPath -or ($volPath -eq $volume.name)){
                    listdir '/' $instance $volumeInfoCookie $volumeName
                }
            }
        }
    }else{
        listdir '/' $instance
    }
    if($script:filesFound -eq $False){
        "No Files Found" # | Tee-Object -FilePath $outputfile -Append
    }
}

$searchResults = api get "/searchvms?entityTypes=kView&entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAWSSnapshotManager&entityTypes=kAzure&entityTypes=kAzureNative&entityTypes=kFlashBlade&entityTypes=kGCP&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware&vmName=$sourceObject"
$searchResults = $searchResults.vms | Where-Object {$_.vmDocument.objectName -eq $sourceObject}

if(!$searchResults){
    Write-Host "no backups found for $sourceObject" -ForegroundColor Yellow
    exit 1
}

# narrow search by job name
$altJobName = "Old Name: $jobName"
$altJobName2 = "$jobName \(Old Name:"
$searchResults = $searchResults | Where-Object {($_.vmDocument.jobName -eq $jobName) -or ($_.vmDocument.jobName -match $altJobName) -or ($_.vmDocument.jobName -match $altJobName2)}

if(!$searchResults){
    Write-Host "$sourceObject is not protected by $jobName" -ForegroundColor Yellow
    exit 1
}

$searchResult = ($searchResults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$doc = $searchResult.vmDocument

if($backupNewerThan){
    $doc.versions = $doc.versions | Where-Object {$backupNewerThan -le (usecsToDate ($_.snapshotTimestampUsecs))}
}
if($backupOlderThan){
    $doc.versions = $doc.versions | Where-Object {$backupOlderThan -ge (usecsToDate ($_.snapshotTimestampUsecs))}
}
if($filesNewerThan){
    $doc.versions = $doc.versions | Where-Object {$filesNewerThan -le (usecsToDate ($_.snapshotTimestampUsecs))}
}

# find source and target server
if($restore -or $restorePrevious){
    # select cluster interface
    if($vlan -gt 0){
        $vlanObj = api get vlans | Where-Object id -eq $vlan
        if(! $vlanObj){
            Write-Host "vlan $vlan not found" -ForegroundColor Yellow
            exit
        }
    }

    if($doc.objectId.entity.type -eq 1){

        # set VM credentials
        if($restoreMethod -ne 'ExistingAgent'){
            if(!$vmUser){
                Write-Host "VM credentials required for 'AutoDeploy' and 'VMTools' restore methods" -ForegroundColor Yellow
                exit 1
            }
            if(!$vmPwd){
                $secureString = Read-Host -Prompt "Enter password for VM user ($vmUser)" -AsSecureString
                $vmPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
            }
            $vmCredentials = @{
                "username" = $vmUser;
                "password" = $vmPwd
            }
        }

        # find source object
        $objects = api get "data-protect/search/protected-objects?snapshotActions=RecoverFiles&searchString=$sourceObject&environments=kVMware" -v2
        $object = $objects.objects | Where-Object name -eq $sourceObject
        if(!$object){
            Write-Host "VM $sourceObject not found" -ForegroundColor Yellow
            exit 1
        }

        # get snapshots
        $objectId = $object[0].id
        $groupId = $object[0].latestSnapshotsInfo[0].protectionGroupId
        $snapshots = api get "data-protect/objects/$objectId/snapshots?protectionGroupIds=$groupId" -v2

        # find target VM
        if($targetObject -ne $sourceObject){
            if(!$restorePath){
                Write-Host "restorePath required when restoring to alternate target VM" -ForegroundColor Yellow
                exit 1
            }
        }

        $vms = api get protectionSources/virtualMachines
        $targetVM = $vms | where-object name -eq $targetObject
        if(!$targetVM){
            Write-Host "VM $targetObject not found" -ForegroundColor Yellow
            exit 1
        }
    }else{
        # physical / nas
        if($targetRegisteredSource){
            $parent = api get protectionSources/rootNodes | Where-Object {$_.protectionSource.name -eq $targetRegisteredSource}
            if(! $parent){
                Write-Host "registered source $targetRegisteredSource not found" -ForegroundColor Yellow
                exit 1
            }
            $parentId = $parent.protectionSource.id
            $entities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kFlashblade&environmentTypes=kGenericNas&environmentTypes=kGPFS&environmentTypes=kIsilon&environmentTypes=kNetapp&environmentTypes=kPhysical&flashbladeEntityTypes=kFileSystem&genericNasEntityTypes=kHost&gpfsEntityTypes=kFileset&isilonEntityTypes=kMountPoint&netappEntityTypes=kVolume&physicalEntityTypes=kHost&physicalEntityTypes=kWindowsCluster&parentEntityId=$parentId"
        }else{
            $entities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kFlashblade&environmentTypes=kGenericNas&environmentTypes=kGPFS&environmentTypes=kIsilon&environmentTypes=kNetapp&environmentTypes=kPhysical&flashbladeEntityTypes=kFileSystem&genericNasEntityTypes=kHost&gpfsEntityTypes=kFileset&isilonEntityTypes=kMountPoint&netappEntityTypes=kVolume&physicalEntityTypes=kHost&physicalEntityTypes=kWindowsCluster"
        }
        $targetEntity = $entities | Where-Object displayName -eq $targetObject
        if(!$targetEntity){
            Write-Host "$targetObject not found" -ForegroundColor Yellow
            exit 1
        }
        if($targetEntity.Count -gt 1){
            Write-Host "ambiguous target entity selected, please use -targetRegisteredSource to narrow target selection" -ForegroundColor Yellow
            exit 1
        }
    }
}

if(! $restorePrevious){
    # show versions
    if($showVersions -or $listFiles){

        if($listFiles){
            foreach($version in $doc.versions){
                Write-Host "`n=============================="
                Write-Host "   runId: $($version.instanceId.jobInstanceId)"
                write-host " runDate: $(usecsToDate $version.instanceId.jobStartTimeUsecs)"
                Write-Host "==============================`n"
                showFiles $doc $version
            }
        }else{
            $doc.versions | Select-Object -Property @{label='runId'; expression={$_.instanceId.jobInstanceId}}, @{label='runDate'; expression={usecsToDate $_.instanceId.jobStartTimeUsecs}}
        }
        # exit 0
    }

    $script:filesFound = $False

    # select version
    if($runId){
        # select version with matching runId
        $version = ($doc.versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId})
        if(! $version){
            Write-Host "Job run ID $runId not found" -ForegroundColor Yellow
            exit 1
        }
        showFiles $doc $version
    }elseif($fileDate){
        # select version just after requested date
        $version = ($doc.versions | Where-Object {$fileDate -le (usecsToDate ($_.snapshotTimestampUsecs))})[-1]
        if(! $version){
            $version = $doc.versions[0]
        }
        showFiles $doc $version
    }else{
        # just use latest version
        $version = $doc.versions[0]
        showFiles $doc $version
    }

    if($script:fileCount -gt 0){
        if($showStats -eq $True){
            "`n{0:n0} files found ({1:n0} bytes)`n" -f $script:fileCount, $script:totalSize
        }
    }
}

$restoreFile = 'filesToRestore.tsv'
if($restorePrevious){
    if($restoreFileList -ne ''){
        $restoreFile = $restoreFileList
    }
    $restore = $True
}

if($restore){
    Write-Host "Performing restores..."
    $restoreData = Import-Csv -Path $restoreFile -Delimiter `t 
    $runIdGroups = $restoreData | Group-Object -Property RunId
    foreach($runIdGroup in $runIdGroups){
        $runId = $runIdGroup.name
        $pathGroups = $runIdGroup.Group | Group-Object -Property Path
        foreach($pathGroup in $pathGroups){
            $path = $pathGroup.name
            $thisRestorePath = "$($restorePath)$path".replace('///','//').replace('//','/')
            $thisPathString = $path.replace('/','_').replace('__','_')
            $fileCounter = [pscustomobject] @{ Value = 0 }
            $fileGroups = @($pathGroup.Group.fileName) | Group-Object -Property { [math]::Floor($fileCounter.Value++ / $maxFilesPerRestore) }
            foreach($fileGroup in $fileGroups){
                $thisSnapshot = $snapshots.snapshots | Where-Object {$_.runInstanceId -eq $runId}
                $fileNames = @($fileGroup.Group | ForEach-Object {"$($path)/$_".replace('//','/')})
                $restoreTaskName = "Restore-Files-$($thisPathString)-$($runId)-$([int]$fileGroup.name + 1)".replace('-_','-')
                if($doc.objectId.entity.type -eq 1){
                    if($thisRestorePath -match '\\'){
                        $thisRestorePath = $thisRestorePath.replace('/','\')
                    }
                    # vmware restore
                    $restoreParams = @{
                        "snapshotEnvironment" = "kVMware";
                        "name"                = $restoreTaskName;
                        "vmwareParams"        = @{
                            "objects"                    = @(
                                @{
                                    "snapshotId" = $thisSnapshot.id
                                }
                            );
                            "recoveryAction"             = "RecoverFiles";
                            "recoverFileAndFolderParams" = @{
                                "filesAndFolders"    = @();
                                "targetEnvironment"  = "kVMware";
                                "vmwareTargetParams" = @{
                                    "recoverToOriginalTarget" = $true;
                                    "overwriteExisting"       = $override;
                                    "preserveAttributes"      = $true;
                                    "continueOnError"         = $true;
                                    "encryptionEnabled"       = $false
                                }
                            }
                        }
                    }
                    foreach($fileName in $fileNames){
                        $restoreParams.vmwareParams.recoverFileAndFolderParams.filesAndFolders += @{
                            "absolutePath" = $fileName;
                            "isDirectory" = $false
                        }
                    }                    
                    # select cluster interface
                    if($vlan -gt 0){
                        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams['vlanConfig'] = @{
                            "id" = $vlanObj.id;
                            "interfaceName" = $vlanObj.ifaceGroupName.split('.')[0]
                        }
                    }

                    if($targetObject -ne $sourceObject){
                        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.recoverToOriginalTarget = $false
                        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams['newTargetConfig']= @{
                            "targetVm" = @{
                            "id" = $targetObject[0].id
                            };
                            "recoverMethod" = $restoreMethods[$restoreMethod];
                            "absolutePath" = $restorePath;
                        }
                         # set VM credentials
                        if($restoreMethod -ne 'ExistingAgent'){
                            $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.newTargetConfig["targetVmCredentials"] = $vmCredentials
                        }
                    }else{
                        # original target config
                        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams["originalTargetConfig"] = @{
                            "recoverMethod"         = $restoreMethods[$restoreMethod];
                        }
                        if($restorePath){
                            $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig.recoverToOriginalPath = $false
                            $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig["alternatePath"] = $restorePath
                        }else{
                            $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig["recoverToOriginalPath"] = $true
                        }
                        if($restoreMethod -ne 'ExistingAgent'){
                            $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig["targetVmCredentials"] = $vmCredentials
                        }
                        if($restoreMethod -ne 'ExistingAgent'){
                            $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig["targetVmCredentials"] = $vmCredentials
                        }
                    }
                    $restoreTask = api post 'data-protect/recoveries' $restoreParams -v2
                    $restoreTaskId = $restoreTask.id
                    Write-Host "Restore Task: $restoreTaskName"
                    while($restoreTask.status -eq "Running"){
                        Start-Sleep 5
                        $restoreTask = api get -v2 "data-protect/recoveries/$($restoreTaskId)?includeTenants=true"
                    }
                    if($restoreTask.status -eq 'Succeeded'){
                        Write-Host "Restore $($restoreTask.status)" -ForegroundColor Green
                    }else{
                        Write-Host "Restore $($restoreTask.status): $($restoreTask.messages -join ', ')" -ForegroundColor Yellow
                    }
                }else{
                    # phys restore
                    
                    $version = $doc.versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId}
                    $restoreParams = @{
                        "filenames"        = [string[]]$fileNames;
                        "sourceObjectInfo" = @{
                            "jobId"          = $doc.objectId.jobId;
                            "jobInstanceId"  = $version.instanceId.jobInstanceId;
                            "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                            "entity"         = $doc.objectId.entity;
                            "jobUid"         = $doc.objectId.jobUid
                        };
                        "params"           = @{
                            "targetEntity"            = $targetEntity[0];
                            "targetEntityCredentials" = @{
                                "username" = "";
                                "password" = ""
                            };
                            "restoreFilesPreferences" = @{
                                "restoreToOriginalPaths"        = $true;
                                "overrideOriginals"             = $override;
                                "preserveTimestamps"            = $true;
                                "preserveAcls"                  = $true;
                                "preserveAttributes"            = $true;
                                "continueOnError"               = $true;
                            }
                        };
                        "name"             = $restoreTaskName
                    }
                    # set alternate restore path
                    if($restorePath){
                        $restoreParams.params.restoreFilesPreferences.restoreToOriginalPaths = $false
                        $restoreParams.params.restoreFilesPreferences["alternateRestoreBaseDirectory"] = $thisRestorePath
                    }

                    if(($version.replicaInfo.replicaVec | Sort-Object -Property {$_.target.type})[0].target.type -eq 3){
                        $restoreParams.sourceObjectInfo['archivalTarget'] = $version.replicaInfo.replicaVec[0].target.archivalTarget
                    }

                    # $restoreParams | ConvertTo-Json -Depth 99
                    Write-Host "Restore Task: $restoreTaskName"
                    $restoreTask = api post /restoreFiles $restoreParams
                    if($restoreTask){
                        $taskId = $restoreTask.restoreTask.performRestoreTaskState.base.taskId
                        $finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
                        $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
                        do {
                            Start-Sleep 3
                            $restoreTask = api get /restoretasks/$taskId
                            $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
                        } until ($restoreTaskStatus -in $finishedStates)
                        if($restoreTaskStatus -eq 'kSuccess'){
                            Write-Host "Restore finished with status $($restoreTaskStatus.Substring(1))" -ForegroundColor Green
                        }else{
                            $errorMsg = $restoreTask.restoreTask.performRestoreTaskState.base.error.errorMsg
                            Write-Host "Restore finished with status $($restoreTaskStatus.Substring(1))" -ForegroundColor Yellow
                            Write-Host "$errorMsg" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
    }    
}
