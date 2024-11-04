[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$vmName,
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$prefix = 'clone-',
    [Parameter()][switch]$powerOn,
    [Parameter(Mandatory = $True)][string]$awsSource,
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$vpc,
    [Parameter(Mandatory = $True)][string]$subnet,
    [Parameter(Mandatory = $True)][string]$securityGroup,
    [Parameter(Mandatory = $True)][string]$instanceType,
    [Parameter()][switch]$wait
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

if($powerOn){
    $powerState = $true
}else{
    $powerState = $false
}

# find VM to restore
$vms = api get "/searchvms?entityTypes=kVMware&vmName=$vmName"
$exactVMs = $vms.vms | Where-Object {$_.vmDocument.objectName -eq $vmName}

if(!$exactVMs){
    Write-Host "VM $vmName not found" -ForegroundColor Yellow
    exit 1
}

$latestsnapshot = ($exactVMs | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$versions = $latestsnapshot.vmDocument.versions

if($recoverDate){
    $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))
    $versions = $versions | Where-Object {$_.instanceId.jobStartTimeUsecs -lt $recoverDateUsecs}
}
if(!$versions -or $versions.Count -eq 0){
    Write-Host "No backups available for $vmName" -ForegroundColor Yellow
    exit 1
}

$recoveryDate = usecsToDate $versions[0].instanceId.jobStartTimeUsecs

# find registered AWS protection source
$thisBackupSource = (api get "/backupsources?allUnderHierarchy=true&envTypes=16").entityHierarchy.children | Where-Object {$_.entity.displayName -eq $awsSource}
if(!$thisBackupSource){
    Write-Host "aws source $awsSource not found" -ForegroundColor Yellow
    exit 1
}

# find AWS region
$thisRegion = $thisBackupSource.children | Where-Object {$_.entity.awsEntity.type -eq 1 -and $_.entity.displayName -eq $region}
if(!$thisRegion){
    Write-Host "Region $region not found" -ForegroundColor Yellow
    exit 1
}

# find Instance Type
$thisInstanceType = $thisRegion.children | Where-Object {$_.entity.awsEntity.type -eq 7 -and $_.entity.displayName -eq $instanceType}
if(!$thisInstanceType){
    Write-Host "Instance type $instanceType not found" -ForegroundColor Yellow
    exit 1
}

# find requested VPC
$thisVPC = $thisRegion.children | Where-Object {$_.entity.awsEntity.type -eq 4 -and $_.entity.displayName -eq $vpc}
if(!$thisVPC){
    Write-Host "VPC $vpc not found" -ForegroundColor Yellow
    exit 1
}

# find request subnet
$thisSubnet = $thisVPC.children | Where-Object {$_.entity.awsEntity.type -eq 5 -and $_.entity.displayName -eq $subnet}
if(!$thisSubnet){
    Write-Host "Subnet $subnet not found" -ForegroundColor Yellow
    exit 1
}

# find requested security group
$thisSecurityGroup = $thisVPC.children | Where-Object {$_.entity.awsEntity.type -eq 6 -and $_.entity.displayName -eq $securityGroup}
if(!$thisSecurityGroup){
    Write-Host "Security Group $securityGroup not found" -ForegroundColor Yellow
    exit 1
}

$cloneDate = (get-date).ToString('yyyy-MM-dd_hh-mm-ss')

$cloneParams = @{
    "name" = "Clone-VMs_$cloneDate";
    "objects" = @(
        @{
            'entity' = $latestsnapshot[0].vmDocument.objectId.entity
            'jobId' = $latestsnapshot[0].vmDocument.objectId.jobId;
            'jobUid' = $latestsnapshot[0].vmDocument.objectId.jobUid;
            'jobInstanceId' = $versions[0].instanceId.jobInstanceId
            'startTimeUsecs' = $versions[0].instanceId.jobStartTimeUsecs
        }
    );
    "powerStateConfig" = @{
        "powerOn" = $powerState
    };
    "restoredObjectsNetworkConfig" = @{
        "detachNetwork" = $true;
        "disableNetwork" = $false
    };
    "renameRestoredObjectParam" = @{
        "prefix" = $prefix
    };
    "continueRestoreOnError" = $false;
    "restoreParentSource" = $thisBackupSource.entity;
    "selectedAWSRegion" = $thisRegion.entity;
    "selectedAWSInstance" = $thisInstanceType;
    "selectedAWSVpc" = $thisVPC;
    "selectedAWSubnet" = $thisSubnet;
    "selectedAWSecurityGroup" = $thisSecurityGroup;
    "awsSecurityGroups" = @(
        $thisSecurityGroup.entity
    );
    "action" = 9;
    "deployVmsToCloudParams" = @{
        "deployVmsToAwsParams" = @{
            "networkSecurityGroups" = @(
                $thisSecurityGroup.entity
            );
            "region" = $thisRegion.entity;
            "subnet" = $thisSubnet.entity;
            "vpc" = $thisVPC.entity;
            "instanceType" = $thisInstanceType.entity
        }
    };
    "vaultRestoreParams" = @{
        "glacier" = @{
            "retrievalType" = "kStandard"
        }
    }
}

$response = api post /clone $cloneParams

if($response){
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    Write-Host "Cloning $vmName as $prefix$vmName (snapshot date: $recoveryDate)..."
}else{
    Write-Warning "No Response"
    exit 1
}

if($wait){
    $status = 'started'
    $finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')
    while($status -ne 'completed'){
        $task = api get "/restoretasks/$($taskId)"
        $publicStatus = $task.restoreTask.performRestoreTaskState.base.publicStatus
        if($publicStatus -in $finishedStates){
            $status = 'completed'
        }else{
            start-Sleep 30
        }
    }
    Write-Host "Clone task completed with status: $publicStatus"
    if($publicStatus -eq 'kFailure'){
        Write-Host "Error Message: $($task.restoreTask.performRestoreTaskState.base.error.errorMsg)"
        return $null
        exit 1
    }else{
        $progress = api get "/progressMonitors?taskPathVec=$($task.restoreTask.performRestoreTaskState.progressMonitorTaskPath)&excludeSubTasks=false&includeFinishedTasks=true"
        if($progress.resultGroupVec.taskVec.subTaskVec.progress.eventVec.eventMsg | Where-Object {$_ -match 'ip address'}){
            $ipAddress = ((($progress.resultGroupVec.taskVec.subTaskVec.progress.eventVec.eventMsg | Where-Object {$_ -match 'ip address'}) -split 'ip address: ')[1] -split ' and')[0]
            return $ipAddress
        }
        exit 0
    }
}else{
    # return $taskId
    exit 0
}
