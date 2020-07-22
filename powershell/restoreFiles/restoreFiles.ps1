# version 2020.07.21
### usage: ./restoreFiles.ps1 -vip mycluster -username myuser -domain mydomain.net `
#                             -sourceServer server1.mydomain.net `
#                             -targetServer server2.mydomain.net `
#                             -fileNames /home/myuser/file1, /home/myuser/file2 `
#                             -restorePath /tmp/restoretest1/ `
#                             -fileDate '2020-04-18 18:00:00' `
#                             -wait

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username='helios', # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][switch]$useApiKey, # use API key for authentication
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$sourceServer, # source server
    [Parameter()][string]$targetServer = $sourceServer, # target server
    [Parameter()][string]$jobName, # narrow search by job name
    [Parameter()][array]$fileNames, # one or more file paths comma separated
    [Parameter()][string]$fileList, # text file with file paths
    [Parameter()][string]$restorePath, # target path
    [Parameter()][Int64]$runId, # restore from specific runid
    [Parameter()][datetime]$start,
    [Parameter()][datetime]$end,
    [Parameter()][switch]$latest,
    [Parameter()][switch]$wait
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# gather file names
$files = @()
if($fileList -and (Test-Path $fileList -PathType Leaf)){
    $files += Get-Content $fileList | Where-Object {$_ -ne ''}
}elseif($fileList){
    Write-Warning "File $fileList not found!"
    exit 1
}
if($fileNames){
    $files += $fileNames
}
if($files.Length -eq 0){
    Write-Host "No files selected for restore"
    exit 1
}

# convert to unix style file paths
$restorePath = ("/" + $restorePath.Replace('\','/').replace(':','')).Replace('//','/')
$files = [string[]]$files | ForEach-Object {("/" + $_.Replace('\','/').replace(':','')).Replace('//','/')}

# find target server
$physicalEntities = api get "/entitiesOfType?environmentTypes=kPhysical&physicalEntityTypes=kHost"
$targetEntity = $physicalEntities | Where-Object displayName -eq $targetServer

if(!$targetEntity){
    Write-Host "$targetServer not found" -ForegroundColor Yellow
    exit 1
}

# find backups for source server
$searchResults = api get "/searchvms?entityTypes=kPhysical&vmName=$sourceServer"
$searchResults = $searchResults.vms | Where-Object {$_.vmDocument.objectName -eq $sourceServer}

# narrow search by job name
if($jobName){
    $searchResults = $searchResults | Where-Object {$_.vmDocument.jobName -eq $jobName}
}

if(!$searchResults){
    if($jobName){
        Write-Host "$sourceServer is not protected by $jobName" -ForegroundColor Yellow
    }else{
        Write-Host "$sourceServer is not protected" -ForegroundColor Yellow
    }
    exit 1
}

$searchResult = ($searchResults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$doc = $searchResult.vmDocument

# find requested version
$independentRestores = $True
if($runId){
    $version = $doc.versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId}
    $independentRestores = $False
    if(! $version){
        Write-Host "Run ID $runId not found" -ForegroundColor Yellow
        exit 1
    }
}else{
    if($start){
        $doc.versions = $doc.versions | Where-Object {$start -le (usecsToDate ($_.snapshotTimestampUsecs))}
    }
    if($end){
        $doc.versions = $doc.versions | Where-Object {$end -ge (usecsToDate ($_.snapshotTimestampUsecs))}
    }
    if($doc.versions){
        if($latest){
            $independentRestores = $False
        }
        $version = $doc.versions[0]
    }else{
        write-host "No versions available for $sourceServer"
    }
}

function restore($thesefiles, $doc, $version, $targetEntity, $singleFile){
    $restoreTaskName = "Recover-Files_$(get-date -UFormat '%b_%d_%Y_%H-%M%p')"
    if($singleFile){
        $shortfile = ($thesefiles -split '/')[-1]
        $restoreTaskName = "Recover-Files_$(get-date -UFormat '%b_%d_%Y_%H-%M%p')_$shortfile"
    }

    $restoreParams = @{
        "filenames"        = [string[]]$thesefiles;
        "sourceObjectInfo" = @{
            "jobId"          = $doc.objectId.jobId;
            "jobInstanceId"  = $version.instanceId.jobInstanceId;
            "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
            "entity"         = $doc.objectId.entity;
            "jobUid"         = $doc.objectId.jobUid
        };
        "params"           = @{
            "targetEntity"            = $targetEntity;
            "targetEntityCredentials" = @{
                "username" = "";
                "password" = ""
            };
            "restoreFilesPreferences" = @{
                "restoreToOriginalPaths"        = $true;
                "overrideOriginals"             = $true;
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
        $restoreParams.params.restoreFilesPreferences["alternateRestoreBaseDirectory"] = $restorePath
    }
    if($singleFile){
        Write-Host "Restoring $file"
    }else{
        Write-Host "Restoring Files"
    }
    
    $restoreTask = api post /restoreFiles $restoreParams
    if($restoreTask){
        $taskId = $restoreTask.restoreTask.performRestoreTaskState.base.taskId
        if($wait){
            $finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
            $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
            do {
                Start-Sleep 3
                $restoreTask = api get /restoretasks/$taskId
                $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
            } until ($restoreTaskStatus -in $finishedStates)
            if($restoreTaskStatus -eq 'kSuccess'){
                Write-Host "Restore finished with status $($restoreTaskStatus.Substring(1))" -ForegroundColor Green
                if(! $singleFile){
                    exit 0
                }
            }else{
                $errorMsg = $restoreTask.restoreTask.performRestoreTaskState.base.error.errorMsg
                Write-Host "Restore finished with status $($restoreTaskStatus.Substring(1))" -ForegroundColor Yellow
                write-host "$errorMsg" -ForegroundColor Yellow
                if(! $singleFile){
                    exit 1
                }
            }
        }else{
            if(! $singleFile){
                exit 0
            }
        }
    }else{
        if(! $singleFile){
            exit 1
        }
    }
}


if($False -eq $independentRestores){
    restore $files $doc $version $targetEntity $False
}else{
    # perform independent restores
    foreach($file in $files){
        # search for file
        $encodedFile = [System.Web.HttpUtility]::UrlEncode($file)
        $fileSearch = api get "/searchfiles?filename=$encodedFile"
        if(! $fileSearch.files){
            write-host "file $file not found..."
        }else{
            # narrow search to correct source server and file path
            $fileSearch.files = $fileSearch.files | Where-Object {$_.fileDocument.objectId.entity.displayName -eq $sourceServer -and $_.fileDocument.fileName -eq $file}
            if(! $fileSearch.files){
                write-host "file $file not found on server $sourceServer..."
            }else{
                # narrow by jobName
                if($jobName){
                    $fileSearch.files = $fileSearch.files | Where-Object {$doc.objectId.jobId -eq $_.fileDocument.objectId.jobId}
                }
                if(! $fileSearch.files){
                    write-host "file $file not found on server $sourceServer protected by $jobName..."
                }else{
                    $doc = $fileSearch.files[0].fileDocument
                    $versions = api get "/file/versions?clusterId=$($doc.objectId.jobUid.clusterId)&clusterIncarnationId=$($doc.objectId.jobUid.clusterIncarnationId)&entityId=$($doc.objectId.entity.id)&filename=$encodedFile&fromObjectSnapshotsOnly=false&jobId=$($doc.objectId.jobId)"
                    if($start){
                        $versions.versions = $versions.versions | Where-Object {$start -le (usecsToDate ($_.instanceId.jobStartTimeUsecs))}
                    }
                    if($end){
                        $versions.versions = $versions.versions | Where-Object {$end -ge (usecsToDate ($_.instanceId.jobStartTimeUsecs))}
                    }
                    if(! $versions.versions){
                        write-host "no versions available for $file"
                    }else{
                        $version = $versions.versions[0]
                        restore $file $doc $version $targetEntity $True
                    }
                }
            }
        }
    }
}
