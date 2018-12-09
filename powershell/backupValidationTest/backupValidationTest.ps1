
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'mycluster', #the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'admin', #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$smtpServer = '192.168.1.95', #outbound smtp server 
    [Parameter()][string]$smtpPort = '25', #outbound smtp port
    [Parameter()][string]$sendTo = 'myaddress@mydomain.com', #send to address
    [Parameter()][string]$sendFrom = 'backuptest@mydomain.com' #send from address
)

### list of backed up files to check
$fileChecks = @(
    @{'server' = 'w2012b.seltzer.net'; 'fileName' = 'MobaXterm.ini'; 'expectedText' = '[Bookmarks]'};
      @{'server' = 'w2016'; 'fileName' = 'lsasetup.log'; 'expectedText' = '[11/28 08:45:36] 508.512>  - In LsapSetupInitialize()'};
      @{'server' = 'centos1'; 'fileName' = 'jobMonitor.sh'; 'expectedText' = '#!/usr/bin/env python'}
)

### local file paths
$scriptLocation = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
$outpath = Join-Path -Path $scriptLocation -ChildPath 'temp'
New-Item -ItemType directory -Path $outpath -ErrorAction Ignore 

### source the cohesity-api helper code
$apimodule = Join-Path -Path $scriptLocation -ChildPath 'cohesity-api.ps1'
. $($apimodule)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$now = get-date

### search and download file function
function getFile($fileName, $objectName) {
    $encodedFileName = [System.Web.HttpUtility]::UrlEncode($fileName)

    ### find entity
    $entities = api get '/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&environmentTypes=kView&isProtected=true&physicalEntityTypes=kHost&viewEntityTypes=kView&vmwareEntityTypes=kVirtualMachine'
    $entity = $entities | Where-Object { $_.displayName -ieq $objectName }
    if (!$entity) {
        Write-Host "objectName not found" -ForegroundColor Yellow
        exit
    }

    ### find my file
    $files = api get "/searchfiles?entityIds=$($entity.id)&filename=$($encodedFileName)"
    if (!$files.count) {
        Write-Host "no files found" -ForegroundColor Yellow
        return $null
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
    return @{ 'startTime' = $jobStartTimeUsecs; 'resultText' = $(Get-Content $outFile -TotalCount 1) }
}

$results = @()

foreach ($fileCheck in $fileChecks){

    write-host "getting $($fileCheck.fileName) from $($fileCheck.server)..." -NoNewline
    $fileStatus = getFile $fileCheck.fileName $fileCheck.server
    if($fileStatus){
        write-host ''
        remove-item $(Join-Path $outpath $fileCheck.fileName)
        ### evaluate backup age
        $lastBackup = usecsToDate $fileStatus.startTime
        $backupAge = New-TimeSpan -Start $lastBackup.DateTime -End $now
        $hoursOld = $backupAge.Hours
        if($hoursOld -lt 24){
            $meetsSLA = "Met"
        }else{
            $meetsSLA = "Violated"
        }
        ### evaluate expected text
        if($fileStatus.resultText -eq $fileCheck.expectedText){
            $validation = 'Successful'
        }else{
            $validation = 'Text Mismatch'
        }
        $results += @{'Server'=$fileCheck.server; 'BackupAgeHours'=$hoursOld; 'SLA'=$meetsSLA; 'Validation'=$validation}
    }else{
        $results += @{'Server'=$fileCheck.server; 'BackupAgeHours'='N/A'; 'SLA'='N/A'; 'Validation'='Check Failed'}
    }
}


### format output
$resultTable = $results | ForEach-Object { [pscustomobject] $_ } | Format-Table | Out-String
$resultTable
$resultTable = $resultTable.Replace("`n","<br/>").Replace(" ","&nbsp;")
$resultHTML='<html><div style="background:#eeeeee;border:1px solid #cccccc;padding:5px 10px;"><code>' + $resultTable + '</code></div></html>'
$resultHTML=$resultHTML.Replace('Check&nbsp;Failed','<span style="color:#ff0000;">Check Failed</span>')
$resultHTML=$resultHTML.Replace('Text&nbsp;Mismatch','<span style="color:#ff0000;">Text Mismatch</span>')
$resultHTML=$resultHTML.Replace('Violated','<span style="color:#ff0000;">Violated</span>')

### send email report
Send-MailMessage -From $sendFrom -To $sendTo -SmtpServer $smtpServer -Port $smtpPort -Subject "backupValidationReport" -BodyAsHtml $resultHTML 
