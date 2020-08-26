### recover all VMs from a proptectino job

### usage: ./recoverVMJob.ps1 -vip mycluster -username admin [ -domain local ] -jobName myVMJob -vCenter myvcenter.mydomain.net -vmNetwork 'VM Network' -vmDatastore datastore1 [ -vmResourcePool resgroup1 ] [ -vmFolder folder1 ]
### example: ./recoverVMJob.ps1 -vip 192.168.1.199 -username admin -jobName GarrisonToVE1 -vCenter vCenter6-B.seltzer.net -vmNetwork 'VM Network' -vmDatastore 450GB

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$vmName,
    [Parameter(Mandatory = $True)][string]$vCenterName,
    [Parameter(Mandatory = $True)][string]$datacenterName,
    [Parameter(Mandatory = $True)][string]$hostName,
    [Parameter(Mandatory = $True)][string]$folderName,
    [Parameter(Mandatory = $True)][string]$networkName,
    [Parameter(Mandatory = $True)][string]$datastoreName,
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$preserveMacAddress,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$powerOn
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find the VMs to recover
$vms = api get "/searchvms?entityTypes=kVMware&vmName=$vmName"
$exactVMs = $vms.vms | Where-Object {$_.vmDocument.objectName -eq $vmName}
$latestsnapshot = ($exactVMs | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

### select vCenter
$vCenterList = api get /entitiesOfType?environmentTypes=kVMware`&vmwareEntityTypes=kVCenter`&vmwareEntityTypes=kStandaloneHost
$vCenter = $vCenterList | Where-Object { $_.displayName -ieq $vCenterName }
$vCenterId = $vCenter.id

if(! $vCenter){
    write-host "vCenter Not Found" -ForegroundColor Yellow
    exit
}

### select resource pool
$vCenterSource = api get protectionSources?environments=kVMware | Where-Object {$_.protectionSource.name -eq $vCenterName}
$dataCenterSource = $vCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $datacenterName}
$hostSource = $dataCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $hostName}
$resourcePoolSource = $hostSource.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kResourcePool'}
$resourcePoolId = $resourcePoolSource.protectionSource.id
$resourcePool = api get /resourcePools?vCenterId=$vCenterId | Where-Object {$_.resourcePool.id -eq $resourcePoolId}
$datastores = api get "/datastores?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId" | Where-Object { $_.vmWareEntity.name -eq $datastoreName }

### select VM folder
$vmFolders = api get /vmwareFolders?resourcePoolId=$resourcePoolId`&vCenterId=$vCenterId
$vmFolder = $vmFolders.vmFolders | Where-Object displayName -eq $folderName

if(! $vmFolder){
    write-host "folder $folderName not found" -ForegroundColor Yellow
    exit
}

### build recovery task
$recoverDate = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')

$restoreParams = @{
    'name' = "Recover-$vmName-$recoverDate";
    'objects' = @(
        @{
            'entity' = $latestsnapshot[0].vmDocument.objectId.entity
            'jobId' = $latestsnapshot[0].vmDocument.objectId.jobId;
            'jobUid' = $latestsnapshot[0].vmDocument.objectId.jobUid;
            'jobInstanceId' = $latestsnapshot[0].vmDocument.versions[0].instanceId.jobInstanceId
            'startTimeUsecs' = $latestsnapshot[0].vmDocument.versions[0].instanceId.jobStartTimeUsecs
            '_jobType' = 1
        }
    );
    'powerStateConfig' = @{
        'powerOn' = $False
    };
    'restoredObjectsNetworkConfig' = @{
        'disableNetwork' = $False
    };
    'continueRestoreOnError' = $False;
    'restoreParentSource' = $vCenter;
    'resourcePoolEntity' = $resourcePool.resourcePool;
    'datastoreEntity' = $datastores[0];
    'vmwareParams' = @{
        'targetVmFolder' = $vmFolder
    }
}

if($powerOn){
    $restoreParams.powerStateConfig.powerOn = $True
}

if($detachNetwork){
    $restoreParams.restoredObjectsNetworkConfig['detachNetwork'] = $True
}else{
    ### select network
    if(! $networkName){
        Write-Host "network name required" -ForegroundColor Yellow
        exit
    }
    $networks = api get "/networkEntities?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId"
    $network = $networks | Where-Object displayName -eq $networkName

    if(! $network){
        Write-Host "network $networkName not found" -ForegroundColor Yellow
        exit
    }
    $restoreParams.restoredObjectsNetworkConfig['networkEntity'] = $network
    if($preserveMacAddress){
        $restoreParams.restoredObjectsNetworkConfig['preserveMacAddressOnNewNetwork'] = $True
    }
}

if ($prefix -ne '') {
    $restoreParams['renameRestoredObjectParam'] = @{
        'prefix' = [string]$prefix + '-';
    }
    "Recovering $vmName as $prefix-$vmName..."
}else{
    "Recovering $vmName..."
}

$null = api post /restore $restoreParams
