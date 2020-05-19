### usage: ./restoreFolders.ps1 -vip mycluster -username myusername -domain mydomain.net -csv ./restoreFolders.csv

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username='helios', # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][switch]$useApiKey, # use API key for authentication
    [Parameter()][string]$csv = './restoreFolders.csv'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -password $password -useApiKey
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

if(! (Test-Path -Path $csv -PathType Leaf)){
    Write-Host "Can't find file $csv" -ForegroundColor Yellow
    exit 1
}

$transfers = import-csv -Path $csv

foreach ($transfer in $transfers) {
    $folderName = $transfer.folderName
    $source = $transfer.source
    $target = $transfer.target
    $targetPath = $transfer.targetPath

    $encodedFileName = [System.Web.HttpUtility]::UrlEncode($folderName)

    ### search for my file
    $fileResults = api get "/searchfiles?filename=$($encodedFileName)&isFolder=true"
    if (!$fileResults.files) {
        Write-Host "no search results for $folderName" -ForegroundColor Yellow
        continue    
    }
  
    ### narrow results to exact server and file name
    $files = $fileResults.files | 
    Where-Object { $_.fileDocument.objectId.entity.displayName -eq $source -and
        $_.fileDocument.filename -eq $folderName }
  
    if (!$files) {
        Write-Host "no search results that match source name $source" -ForegroundColor Yellow
        continue   
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
  
    if (!$targetServer) {
        write-host "target server $target not found!" -ForegroundColor Yellow
        continue
    }
  
    $now = (get-date).ToString().replace('/', '_').replace(':', '_').replace(' ', '_')
  
    $restoreParams = @{
        "filenames"        = @(
            $files[0].fileDocument.filename
        );
        "sourceObjectInfo" = @{
            "jobId"          = $files[0].fileDocument.objectId.jobId;
            "jobInstanceId"  = $versions.versions[0].instanceId.jobInstanceId;
            "startTimeUsecs" = $versions.versions[0].instanceId.jobStartTimeUsecs;
            "entity"         = $files[0].fileDocument.objectId.entity;
            "jobUid"         = $files[0].fileDocument.objectId.jobUid
        };
        "params"           = @{
            "targetEntity"            = $targetServer.entity;
            "targetEntityCredentials" = @{
                "username" = "";
                "password" = ""
            };
            "restoreFilesPreferences" = @{
                "restoreToOriginalPaths"        = $false;
                "overrideOriginals"             = $true;
                "preserveTimestamps"            = $true;
                "preserveAcls"                  = $true;
                "preserveAttributes"            = $true;
                "continueOnError"               = $false;
                "alternateRestoreBaseDirectory" = $targetPath
            }
        };
        "name"             = "Recover-Files_$now"
    }
  
    $null = api post /restoreFiles $restoreParams
    write-host "Restoring $source$folderName to $target$targetPath"

}
