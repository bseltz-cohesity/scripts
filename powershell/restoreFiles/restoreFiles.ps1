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
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$sourceServer, # source server
    [Parameter()][string]$targetServer = $sourceServer, # target server
    [Parameter()][array]$fileNames, # one or more file paths comma separated
    [Parameter()][string]$fileList, # text file with file paths
    [Parameter()][string]$restorePath, # target path
    [Parameter()][datetime]$fileDate, # date time to restore to
    [Parameter()][switch]$wait
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

# gather file names
$files = @()
if(Test-Path $fileList -PathType Leaf){
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

# find source and target servers
$physicalEntities = api get "/entitiesOfType?environmentTypes=kPhysical&physicalEntityTypes=kHost"
$sourceEntity = $physicalEntities | Where-Object displayName -eq $sourceServer
$targetEntity = $physicalEntities | Where-Object displayName -eq $targetServer
if(!$sourceEntity){
    Write-Host "$sourceServer not found" -ForegroundColor Yellow
    exit 1
}
if(!$targetEntity){
    Write-Host "$targetServer not found" -ForegroundColor Yellow
    exit 1
}

# find backups for source server
$searchResults = api get "/searchvms?entityTypes=kPhysical&vmName=$sourceServer"
$searchResults = $searchResults.vms | Where-Object {$_.vmDocument.objectName -eq $sourceServer}
if(!$searchResults){
    Write-Host "$sourceServer is not protected" -ForegroundColor Yellow
    exit 1
}
$doc = $searchResults[0].vmDocument

# find version just after requested date
if($fileDate){
    $version = ($doc.versions | Where-Object {$fileDate -le (usecsToDate ($_.snapshotTimestampUsecs))})[-1]
}else{
    $version = $doc.versions[0]
}

$restoreTaskName = "Recover-Files_$(get-date -UFormat '%b_%d_%Y_%H-%M%p')"

$restoreParams = @{
    "filenames"        = $files;
    "sourceObjectInfo" = @{
        "jobId"          = $doc.objectId.jobId;
        "jobInstanceId"  = $version.instanceId.jobInstanceId;
        "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
        "entity"         = $sourceEntity;
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

Write-Host "Restoring Files..."
$restoreTask = api post /restoreFiles $restoreParams
if($restoreTask){
    $taskId = $restoreTask.restoreTask.performRestoreTaskState.base.taskId
    if($wait){
        $finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
        $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
        do {
            sleep 3
            $restoreTask = api get /restoretasks/$taskId
            $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
        } until ($restoreTaskStatus -in $finishedStates)
        if($restoreTaskStatus -eq 'kSuccess'){
            Write-Host "Restore finished with status $($restoreTaskStatus.Substring(1))" -ForegroundColor Green
            exit 0
        }else{
            $errorMsg = $restoreTask.restoreTask.performRestoreTaskState.base.error.errorMsg
            Write-Host "Restore finished with status $($restoreTaskStatus.Substring(1))" -ForegroundColor Yellow
            write-host "$errorMsg" -ForegroundColor Yellow
            exit 1
        }
    }else{
        exit 0
    }
}else{
    exit 1
}

