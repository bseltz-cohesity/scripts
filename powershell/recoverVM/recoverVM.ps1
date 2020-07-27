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
    [Parameter(Mandatory = $True)][string]$vCenter,
    [Parameter()][string]$vmResourcePool = 'Resources',
    [Parameter(Mandatory = $True)][string]$vmDatastore,
    [Parameter()][string]$vmFolder = 'vm',
    [Parameter()][string]$prefix = '',
    [Parameter(Mandatory = $True)][string]$vmNetwork
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find the VMs to recover
$vms = api get "/searchvms?entityTypes=kVMware&vmName=$vmName"
$exactVMs = $vms.vms | Where-Object {$_.vmDocument.objectName -eq $vmName}
$latestsnapshot = ($exactVMs | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

### find vCenter
$hv = api get '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter' | Where-Object { $_.displayName -eq $vCenter }
$vCenterId = $hv[0].id

### find vSphere recovery target pool, datastore, folder, network
$resourcePools = api get "/resourcePools?vCenterId=$vCenterId" | where-object { $_.resourcePool.displayName -eq $vmResourcePool }
$resourcePoolId = $resourcePools[0].resourcePool.id

$datastores = api get "/datastores?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId" | Where-Object { $_.vmWareEntity.name -eq $vmDatastore }
$vmFolders = (api get "/vmwareFolders?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId").vmFolders  | Where-Object { $_.displayName -eq $vmFolder }
$networks = api get "/networkEntities?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId" | Where-Object { $_.displayName -eq $vmNetwork }

### build recovery task
$recoverDate = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')

$myObject = @{
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
        'powerOn' = $true
    };
    'restoredObjectsNetworkConfig' = @{
        'networkEntity' = $networks[0];
        'disableNetwork' = $false
    };
    'continueRestoreOnError' = $false;
    'restoreParentSource' = $hv[0];
    'resourcePoolEntity' = $resourcePools[0].resourcePool;
    'datastoreEntity' = $datastores[0];
    'vmwareParams' = @{
        'targetVmFolder' = $vmFolders[0]
    }
}

if ($prefix -ne '') {
    $myObject['renameRestoredObjectParam'] = @{
        'prefix' = [string]$prefix + '-';
    }
    "Recovering $vmName as $prefix-$vmName"
}else{
    "Recovering $vmName"
}

"Restoring VMs..."
$null = api post /restore $myObject
