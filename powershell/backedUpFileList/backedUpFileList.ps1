# usage: ./backedUpFileList.ps1 -vip mycluster \
#                               -username myuser \
#                               -domain mydomain.net \
#                               -sourceServer server1.mydomain.net \
#                               -jobName myjob \
#                               -fileDate '2020-06-29 12:00:00'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username='helios', # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][switch]$useApiKey, # use API key for authentication
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$sourceServer, # source server
    [Parameter(Mandatory = $True)][string]$jobName, # narrow search by job name
    [Parameter()][datetime]$fileDate
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

$searchResults = api get "/searchvms?entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAWSSnapshotManager&entityTypes=kAzure&entityTypes=kAzureNative&entityTypes=kFlashBlade&entityTypes=kGCP&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware&vmName=$sourceserver"
$searchResults = $searchResults.vms | Where-Object {$_.vmDocument.objectName -eq $sourceServer}

# narrow search by job name
$searchResults = $searchResults | Where-Object {$_.vmDocument.jobName -eq $jobName}

if(!$searchResults){
    Write-Host "$sourceServer is not protected by $jobName" -ForegroundColor Yellow
    exit 1
}

$searchResult = ($searchResults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$doc = $searchResult.vmDocument

# find version just after requested date
if($fileDate){
    $version = ($doc.versions | Where-Object {$fileDate -le (usecsToDate ($_.snapshotTimestampUsecs))})[-1]
}else{
    $version = $doc.versions[0]
}

$versionDate = (usecsToDate $version.instanceId.jobStartTimeUsecs).ToString('yyyy-MM-dd_hh-mm-ss')

$outputfile = "backedUpFiles-$($sourceServer)-$versionDate.txt"

$instance = "attemptNum={0}&clusterId={1}&clusterIncarnationId={2}&entityId={3}&jobId={4}&jobInstanceId={5}&jobStartTimeUsecs={6}&jobUidObjectId={7}" -f
            $version.instanceId.attemptNum,
            $doc.objectId.jobUid.clusterId,
            $doc.objectId.jobUid.clusterIncarnationId,
            $doc.objectId.entity.id,
            $doc.objectId.jobId,
            $version.instanceId.jobInstanceId,
            $version.instanceId.jobStartTimeUsecs,
            $doc.objectId.jobUid.objectId

function listdir($dirPath, $instance, $volumeInfoCookie=$null, $volumeName=$null){
    $thisDirPath = [System.Web.HttpUtility]::UrlEncode($dirPath)
    if($null -ne $volumeName){
        $dirList = api get "/vm/directoryList?$instance&dirPath=$thisDirPath&statFileEntries=false&volumeInfoCookie=$volumeInfoCookie&volumeName=$volumeName"
    }else{
        $dirList = api get "/vm/directoryList?$instance&dirPath=$thisDirPath&statFileEntries=false"
    }
    if($dirList.PSObject.Properties['entries']){
        foreach($entry in $dirList.entries | Sort-Object -Property name){
            if($entry.type -eq 'kDirectory'){
                listdir "$dirPath/$($entry.name)" $instance $volumeInfoCookie $volumeName
            }else{
                $entry.fullPath | Tee-Object -FilePath $outputfile -Append  
            }
        }
    }
}

$volumeTypes = @(1, 6)
$backupType = $doc.backupType
if($backupType -in $volumeTypes){
    $volumeList = api get "/vm/volumeInfo?$instance&statFileEntries=false"
    if($volumeList.PSObject.Properties['volumeInfos']){
        $volumeInfoCookie = $volumeList.volumeInfoCookie
        foreach($volume in $volumeList.volumeInfos | Sort-Object -Property name){
            $volumeName = [System.Web.HttpUtility]::UrlEncode($volume.name)
            listdir '/' $instance $volumeInfoCookie $volumeName
        }
    }
}else{
    listdir '/' $instance
}
