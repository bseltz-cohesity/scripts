### usage: ./recoverFileScheduled.ps1 -vip mycluster -username myusername -d mydomain.net -objectName someVM -fileName someFile -outPath /Users/myusername/Downloads/myfile -keepFor 7

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$objectName, # view or server where file is from
    [Parameter(Mandatory = $True)][string]$fileName, # file name or path to download
    [Parameter(Mandatory = $True)][string]$outPath, # target folder to download to
    [Parameter(Mandatory = $True)][int]$keepFor # number of days yo keep old downloaded files
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$encodedFileName = [System.Web.HttpUtility]::UrlEncode($fileName)

### log file
$logFile = 'recoverFileScheduledLog.txt'
"---------------------------" | Out-File $logFile -Append
(get-date).ToString() | Out-File $logFile -Append

### search for my file
$fileResults = api get "/searchfiles?filename=$($encodedFileName)"
if (!$fileResults.count){
    Write-Host "no files found" -ForegroundColor Yellow
    "no files found" | Out-File $logFile -Append
    exit    
}

### narrow results to exact server and file name
$files = $fileResults.files | 
            Where-Object { $_.fileDocument.objectId.entity.displayName -eq $objectName -and
                           (Split-Path $_.fileDocument.filename -Leaf) -eq $fileName }

if (!$files){
    Write-Host "no files found" -ForegroundColor Yellow
    "no files found" | Out-File $logFile -Append
    exit    
}

### get file properties
$clusterId = $files[0].fileDocument.objectId.jobUid.clusterId
$clusterIncarnationId = $files[0].fileDocument.objectId.jobUid.clusterIncarnationId
$jobId = $files[0].fileDocument.objectId.jobUid.objectId
$localJobId = $files[0].fileDocument.objectId.jobId
$viewBoxId = $files[0].fileDocument.viewBoxId
$filePath = $files[0].fileDocument.filename
$shortFile = Split-Path $filePath -Leaf
$outFile = "$outPath-$((get-date).tostring('yyyy-MM-dd-hh-mm-ss'))"
$shortOutFile = Split-Path $outPath -Leaf
$filePath = [System.Web.HttpUtility]::UrlEncode($filePath)

### find most recent version
$entity = $files[0].fileDocument.objectId.entity
$versions = api get "/file/versions?clusterId=$($clusterId)&clusterIncarnationId=$($clusterIncarnationId)&entityId=$($entity.id)&filename=$($filePath)&fromObjectSnapshotsOnly=false&jobId=$($jobId)"

$attemptNum = $versions.versions[0].instanceId.attemptNum
$jobInstanceId = $versions.versions[0].instanceId.jobInstanceId
$jobStartTimeUsecs = $versions.versions[0].instanceId.jobStartTimeUsecs

### download the file
"Downloading $shortFile to $outFile..."
"Downloading $shortFile to $outFile..." | Out-File $logFile -Append

fileDownload "/downloadfiles?attemptNum=$($attemptNum)&clusterId=$($clusterId)&clusterIncarnationId=$($clusterIncarnationId)&entityId=$($entity.id)&filepath=$($filePath)&jobId=$($localJobId)&jobInstanceId=$($jobInstanceId)&jobStartTimeUsecs=$($jobStartTimeUsecs)&viewBoxId=$($viewBoxId)" $outFile

### clean up old files
$oldestFileToKeep = "$shortOutFile-$((get-date).AddDays(-$keepFor).ToString('yyyy-MM-dd-hh-mm-ss'))"
foreach($oldfile in Get-ChildItem -Path (split-path -Path $outPath -Parent)){
    if($oldfile.Name.StartsWith("$shortOutFile-")){
        if($oldfile.Name -lt $oldestFileToKeep){
            write-host "Deleting $($oldfile.Name)..."
            "Deleting $($oldfile.Name)..." | Out-File $logFile -Append
            $oldfile.Delete()
        }
    }
}
"---------------------------`n" | Out-File $logFile -Append