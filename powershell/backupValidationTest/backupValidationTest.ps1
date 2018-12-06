
### usage: ./backupValidationTest.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -sourceServer 'SQL2012' [ -targetServer 'SQLDEV01' ] [ -targetUsername 'myDomain\ADuser' ] [ -targetPw 'myPassword' ] [-testFile C:\test.txt] [-testText 'hello world']

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'mycluster', #the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'admin', #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$sourceServer = 'w2012b.seltzer.net', #source server that was backed up
    [Parameter()][string]$targetServer = 'w2012a.seltzer.net', #target server to mount the volumes to
    [Parameter()][string]$targetUsername = '', #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
    [Parameter()][string]$targetPw = '', #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
    [Parameter()][string]$testFile = 'C:\Users\myuser\Downloads\test.txt',
    [Parameter()][string]$testText = 'Hello World',
    [Parameter()][string]$smtpServer = '192.168.1.95',
    [Parameter()][string]$smtpPort = '25',
    [Parameter()][string]$sendTo = 'somebody@mydomain.com',
    [Parameter()][string]$sendFrom = 'backuptest@mydomain.com'
)

### source the cohesity-api helper code
$scriptLocation = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
$apimodule = Join-Path -Path $scriptLocation -ChildPath 'cohesity-api.ps1'
. $($apimodule)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for the source server
$searchResults = api get "/searchvms?entityTypes=kVMware&entityTypes=kPhysical&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kAcropolis&entityTypes=kView&vmName=$sourceServer"

### narrow the results to the correct server
$searchResults2 = $searchresults.vms | Where-Object { $_.vmDocument.objectName -ieq $sourceServer }

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestResult = ($searchResults2 | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

if($latestResult -eq $null){
    write-host "Source Server $sourceServer Not Found" -foregroundcolor yellow
    exit
}

### get source and target entity info
$physicalEntities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&physicalEntityTypes=kHost&vmwareEntityTypes=kVCenter"
$virtualEntities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&isProtected=true&physicalEntityTypes=kHost&vmwareEntityTypes=kVirtualMachine" #&vmwareEntityTypes=kVCenter
$sourceEntity = (($physicalEntities + $virtualEntities) | Where-Object { $_.displayName -ieq $sourceServer })[0]
$targetEntity = (($physicalEntities + $virtualEntities) | Where-Object { $_.displayName -ieq $targetServer })[0]

if($sourceEntity -eq $null){
    Write-Host "Source Server $sourceServer Not Found" -ForegroundColor Yellow
    exit
}

if($targetEntity -eq $null){
    Write-Host "Target Server $targetServer Not Found" -ForegroundColor Yellow
    exit
}

### confirm age of last backup
$mostRecentBackupUsecs = $latestResult.vmDocument.versions[0].instanceId.jobStartTimeUsecs
$mostRecentBackup = usecsToDate $mostRecentBackupUsecs
$24hoursAgo = timeAgo 24 hours
if ($mostRecentBackupUsecs -lt $24hoursAgo){
    $backupWarning = 'Warning: latest backup is more than 24 hours old'
    Write-Host $backupWarning -ForegroundColor Yellow
}else{
    $backupWarning = "latest backup occurred within the last 24 hours ($mostRecentBackup)"
    write-host $backupWarning -ForegroundColor Green
}

### mount backup to this server
$mountTask = @{
    'name' = 'myMountOperation';
    'objects' = @(
        @{
            'jobId' = $latestResult.vmDocument.objectId.jobId;
            'jobUid' = $latestResult.vmDocument.objectId.jobUid;
            'entity' = $sourceEntity;
            'jobInstanceId' = $latestResult.vmDocument.versions[0].instanceId.jobInstanceId;
            'startTimeUsecs' = $latestResult.vmDocument.versions[0].instanceId.jobStartTimeUsecs
        }
    );
    'mountVolumesParams' = @{
        'targetEntity' = $targetEntity;
        'vmwareParams' = @{
            'bringDisksOnline' = $true;
            'targetEntityCredentials' = @{
                'username' = $targetUsername;
                'password' = $targetPw;
            }
        }
    }
}

if($targetEntity.parentId ){
    $mountTask['restoreParentSource'] = @{ 'id' = $targetEntity.parentId }
}

write-host "mounting volumes to $targetServer..." -ForegroundColor Green
$result = api post /restore $mountTask

$taskid = $result.restoreTask.performRestoreTaskState.base.taskId

$finishedStates =  @('kCanceled', 'kSuccess', 'kFailure') 

### wait for mount to complete
do
{
    sleep 3
    $restoreTask = api get /restoretasks/$taskid
    $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
} until ($restoreTaskStatus -in $finishedStates)

if($restoreTaskStatus -eq 'kSuccess'){

    $mountResult = 'Success'
    Write-Host "Volume mounted successfully" -ForegroundColor Green

    ### gather mount information
    $mountPoints = $restoreTask.restoreTask.performRestoreTaskState.mountVolumesTaskState.mountInfo.mountVolumeResultVec
    $taskId = $restoreTask.restoreTask.performRestoreTaskState.base.taskId
    $mounts = @{}
    foreach($mountPoint in $mountPoints){
        $mounts[$($mountPoint.originalVolumeName)] = $mountPoint.mountPoint
    }
    
    ### check contents of test file
    $testFile = $mounts[$testFile.split(':')[0] + ':'] + $testFile.split(':')[1]
    
    ### report test as successful or failed
    $backupValidation = 'Failed'
    if((gc $testFile)[0] -eq $testText){
        $backupValidation = 'Success'
        write-host "Backup Validation Successful!" -ForegroundColor Green
    }else{
        Write-Host "Warning: test file not as expected!" -ForegroundColor Yellow
    }
    
    ### tear down the mount
    $tearDownTask = api post /destroyclone/$taskId
    write-host "Tearing down mount points..." -ForegroundColor Green

}else{
    ### report that the mount operation failed
    $mountResult = "Warining: mount result = $restoreTaskStatus"
    Write-Host "mount operation ended with: $restoreTaskStatus" -ForegroundColor Yellow
    Exit
}

$body = @" 
Backup Validation Report for $sourceServer

Backup Status: $backupWarning
Mount Operation: $mountResult
Validation Test: $backupValidation
"@

Send-MailMessage -From $sendFrom -To $sendTo -SmtpServer $smtpServer -Port $smtpPort -Subject "backupValidationReport for $sourceServer" -Body $body 

Write-Host "Process Complete`n" -ForegroundColor Green