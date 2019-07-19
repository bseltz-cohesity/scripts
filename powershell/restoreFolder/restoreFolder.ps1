### usage: ./restoreFolder.ps1 -vip mycluster -username myusername -domain mydomain.net -source server1.mydomain.net -folderName /C/Users/myusername/documents/stuff -target server2.mydomain.net -targetPath /C/Users/myuser/documents

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$source, # source server
    [Parameter(Mandatory = $True)][string]$folderName, # folder path
    [Parameter(Mandatory = $True)][string]$target, # target server
    [Parameter(Mandatory = $True)][string]$targetPath # target path
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$encodedFileName = [System.Web.HttpUtility]::UrlEncode($folderName)

### search for my file
$fileResults = api get "/searchfiles?filename=$($encodedFileName)&isFolder=true"
if (!$fileResults.files){
    Write-Host "no search results" -ForegroundColor Yellow
    exit    
}

### narrow results to exact server and file name
$files = $fileResults.files | 
            Where-Object { $_.fileDocument.objectId.entity.displayName -eq $source -and
                           $_.fileDocument.filename -eq $folderName }

if (!$files){
    Write-Host "no search results that match source name" -ForegroundColor Yellow
    exit    
}

$clusterId = $files[0].fileDocument.objectId.jobUid.clusterId
$clusterIncarnationId = $files[0].fileDocument.objectId.jobUid.clusterIncarnationId
$jobId = $files[0].fileDocument.objectId.jobUid.objectId
$sourceEntityId = $files[0].fileDocument.objectId.entity.id
$versions = api get "/file/versions?clusterId=$clusterId&clusterIncarnationId=$clusterIncarnationId&entityId=$sourceEntityId&filename=$encodedFileName&fromObjectSnapshotsOnly=false&jobId=$jobId"

### get target server
$physicalServerNode = api get '/backupsources?allUnderHierarchy=true&envTypes=6&excludeTypes=5&excludeTypes=10&onlyReturnOneLevel=true'
$psid = $physicalServerNode.entityHierarchy.children[0].entity.id
$physicalServers = api get "/backupsources?allUnderHierarchy=true&entityId=$psid&excludeTypes=5&excludeTypes=10&includeVMFolders=true"
$targetServer = $physicalServers.entityHierarchy.children | Where-Object { $_.entity.displayName -eq $target }

if(!$targetServer){
    write-host "target server $target not found!" -ForegroundColor Yellow
    exit
}

$now = (get-date).ToString().replace('/','_').replace(':','_').replace(' ','_')

$restoreParams = @{
    "filenames" = @(
      $files[0].fileDocument.filename
    );
    "sourceObjectInfo" = @{
      "jobId" = $files[0].fileDocument.objectId.jobId;
      "jobInstanceId" = $versions.versions[0].instanceId.jobInstanceId;
      "startTimeUsecs" = $versions.versions[0].instanceId.jobStartTimeUsecs;
      "entity" = $files[0].fileDocument.objectId.entity;
      "jobUid" = $files[0].fileDocument.objectId.jobUid
    };
    "params" = @{
      "targetEntity" = $targetServer.entity;
      "targetEntityCredentials" = @{
        "username" = "";
        "password" = ""
      };
      "restoreFilesPreferences" = @{
        "restoreToOriginalPaths" = $false;
        "overrideOriginals" = $true;
        "preserveTimestamps" = $true;
        "preserveAcls" = $true;
        "preserveAttributes" = $true;
        "continueOnError" = $false;
        "alternateRestoreBaseDirectory" = $targetPath
      }
    };
    "name" = "Recover-Files_$now"
  }

$result = api post /restoreFiles $restoreParams
write-host "Restoring $source$folderName to $target$targetPath"
