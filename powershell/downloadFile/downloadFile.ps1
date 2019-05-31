### usage: ./downloadFile.ps1 -vip mycluster -username myusername -objectName myserver -fileName myfile.txt -outPath '/Users/myusername/Downloads'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$objectName, #view or server where file is from
    [Parameter(Mandatory = $True)][string]$fileName, #file name or path to download
    [Parameter(Mandatory = $True)][string]$outPath #target folder to download to
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$encodedFileName = [System.Web.HttpUtility]::UrlEncode($fileName)

### find entity
$entities = api get '/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&environmentTypes=kView&isProtected=true&physicalEntityTypes=kHost&viewEntityTypes=kView&vmwareEntityTypes=kVirtualMachine'
$entity = $entities | Where-Object { $_.displayName -ieq $objectName }
if (!$entity){
    Write-Host "objectName not found" -ForegroundColor Yellow
    exit
}

### find my file
$files = api get "/searchfiles?entityIds=$($entity.id)&filename=$($encodedFileName)"
if (!$files.count){
    Write-Host "no files found" -ForegroundColor Yellow
    exit    
}
$clusterId = $files.files[0].fileDocument.objectId.jobUid.clusterId
$clusterIncarnationId = $files.files[0].fileDocument.objectId.jobUid.clusterIncarnationId
$jobId = $files.files[0].fileDocument.objectId.jobUid.objectId
$viewBoxId = $files.files[0].fileDocument.viewBoxId
$filePath = $files.files[0].fileDocument.filename
$shortFile = Split-Path $filePath -Leaf
$outFile = Join-Path $outPath $shortFile
$filePath = [System.Web.HttpUtility]::UrlEncode($filePath)
### find most recent version
$versions = api get "/file/versions?clusterId=$($clusterId)&clusterIncarnationId=$($clusterIncarnationId)&entityId=$($entity.id)&filename=$($encodedFileName)&fromObjectSnapshotsOnly=false&jobId=$($jobId)"
$attemptNum = $versions.versions[0].instanceId.attemptNum
$jobInstanceId = $versions.versions[0].instanceId.jobInstanceId
$jobStartTimeUsecs = $versions.versions[0].instanceId.jobStartTimeUsecs

### download the file
"Downloading $shortFile..."
fileDownload "/downloadfiles?attemptNum=$($attemptNum)&clusterId=$($clusterId)&clusterIncarnationId=$($clusterIncarnationId)&entityId=$($entity.id)&filepath=$($filePath)&jobId=$($jobId)&jobInstanceId=$($jobInstanceId)&jobStartTimeUsecs=$($jobStartTimeUsecs)&viewBoxId=$($viewBoxId)" $outFile
