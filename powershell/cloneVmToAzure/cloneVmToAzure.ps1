[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$vmName,
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$prefix,
    [Parameter()][string]$suffix,
    [Parameter()][switch]$powerOn,
    [Parameter(Mandatory = $True)][string]$azureSource,
    [Parameter(Mandatory = $True)][string]$resourceGroup,
    [Parameter()][string]$storageResourceGroup,
    [Parameter()][string]$vnetResourceGroup,
    [Parameter(Mandatory = $True)][string]$storageAccount,
    [Parameter(Mandatory = $True)][string]$storageContainer,
    [Parameter(Mandatory = $True)][string]$virtualNetwork,
    [Parameter(Mandatory = $True)][string]$subnet,
    [Parameter(Mandatory = $True)][string]$instanceType,
    [Parameter()][switch]$wait,
    [Parameter()][switch]$useManagedDisks,
    [Parameter()][ValidateSet('kStandardSSD', 'kPremiumSSD', 'kStandardHDD')]$osDiskType = 'kStandardSSD',
    [Parameter()][ValidateSet('kStandardSSD', 'kPremiumSSD', 'kStandardHDD')]$dataDiskType = 'kStandardSSD'
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

# find registered Azure protection source
$sources = api get protectionSources/registrationInfo?environments=kAzure
if($sources){
    $source = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $azureSource}
    if(!$source){
        Write-Host "Azure protection source $azureSource not found" -ForegroundColor Yellow
        exit 1
    }
}else{
    Write-Host "Azure protection source $azureSource not found" -ForegroundColor Yellow
    exit 1
}
$subscriptionEntity = (api get /backupsources?entityId=$($source.rootNode.id)).entityHierarchy

# get resource group
$rg = $subscriptionEntity.children | Where-Object {$_.entity.azureEntity.type -eq 1 -and $_.entity.displayName -eq $resourceGroup}
if(!$rg){
    Write-Host "Resource Group $resourceGroup not found" -ForegroundColor Yellow
    exit 1
}

# get storage resource group
if(!$storageResourceGroup){
    $srg = $rg
}else{
    $srg = $subscriptionEntity.children | Where-Object {$_.entity.azureEntity.type -eq 1 -and $_.entity.displayName -eq $storageResourceGroup}
}
if(!$srg){
    Write-Host "Storage Resource Group $resourceGroup not found" -ForegroundColor Yellow
    exit 1
}

# get vnet resource group
if(!$vnetResourceGroup){
    $vrg = $rg
}else{
    $vrg = $subscriptionEntity.children | Where-Object {$_.entity.azureEntity.type -eq 1 -and $_.entity.displayName -eq $vnetResourceGroup}
}
if(!$vrg){
    Write-Host "VNET Resource Group $resourceGroup not found" -ForegroundColor Yellow
    exit 1
}

# get compute
$compute = $rg.children | Where-Object {$_.entity.azureEntity.type -eq 7 -and $_.entity.displayName -eq $instanceType}
if(! $compute){
    Write-Host "Instance type $instanceType not found" -ForegroundColor Yellow
    exit 1
}

# get storage account

$sa = $srg.children | Where-Object {$_.entity.azureEntity.type -eq 3 -and $_.entity.displayName -eq $storageAccount}
if(! $sa){
    Write-Host "Storage account $storageAccount not found" -ForegroundColor Yellow
    exit 1
}

# get storage container
$sc = $sa.children | Where-Object {$_.entity.azureEntity.type -eq 9 -and $_.entity.displayName -eq $storageContainer}
if(! $sc){
    Write-Host "Storage container $storageContainer not found" -ForegroundColor Yellow
    exit 1
}

# get vnet
$vnet = $vrg.children | Where-Object {$_.entity.azureEntity.type -eq 5 -and $_.entity.displayName -eq $virtualNetwork}
if(! $vnet){
    Write-Host "Virtual network $virtualNetwork not found" -ForegroundColor Yellow
    exit 1
}

# get subnet
$vsubnet = $vnet.children | Where-Object {$_.entity.azureEntity.type -eq 6 -and $_.entity.displayName -eq $subnet}
if(! $vsubnet){
    Write-Host "Subnet $subnet not found" -ForegroundColor Yellow
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
    "continueRestoreOnError" = $false;
    "restoreParentSource" = $subscriptionEntity.entity;
    "deployVmsToCloudParams" = @{
        "deployVmsToAzureParams" = @{
            "resourceGroup" = $rg.entity;
            "computeOptions" = $compute.entity;
            "storageAccount" = $sa.entity;
            "storageContainer" = $sc.entity;
            "storageResourceGroup" = $srg.entity;
            "virtualNetwork" = $vnet.entity;
            "networkResourceGroup" = $vrg.entity;
            "subnet" = $vsubnet.entity
        }
    };
    "action" = 9;
    "vaultRestoreParams" = @{
        "glacier" = @{
            "retrievalType" = "kStandard"
        }
    }
}

if($useManagedDisks){
    $cloneParams.deployVmsToCloudParams.deployVmsToAzureParams['azureManagedDiskParams'] = @{
        "osDiskSKUType" = $osDiskType;
        "dataDisksSKUType" = $dataDiskType
    }
}

if($prefix -or $suffix){
    $cloneParams['renameRestoredObjectParam'] = @{};
    if($prefix){
        $cloneParams['renameRestoredObjectParam']['prefix'] = "{0}-" -f $prefix
        $targetName = "{0}{1}" -f $prefix, $vmName
    }
    if($suffix){
        $cloneParams['renameRestoredObjectParam']['suffix'] = "-{0}" -f $suffix
        $targetName = "{0}{1}" -f $vmName, $suffix
    }
}

$response = api post /clone $cloneParams

if($response){
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    Write-Host "Cloning $vmName as $targetName (snapshot date: $recoveryDate)..."
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
            Write-Host "Cloned VM IP address is $ipAddress"
        }
        exit 0
    }
}else{
    exit 0
}
