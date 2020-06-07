# usage: ./recoverVM.ps1 -vip mycluster `
#                        -username myusername `
#                        -domain mydomain.net `
#                        -vmName myvm `
#                        -vCenter myvcenter.mydomain.net `
#                        -vmNetwork 'VM Network' `
#                        -vmDatastore datastore1 `
#                        -vmResourcePool resgroup1 `
#                        -vmFolder folder1 `
#                        -poweron `
#                        -disableNetwork `
#                        -recoverDate '2020-06-02 14:00' `
#                        -prefix restore- `
#                        -wait

# process commandline arguments
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
    [Parameter(Mandatory = $True)][string]$vmNetwork,
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$poweron,
    [Parameter()][switch]$disableNetwork,
    [Parameter()][switch]$wait, # wait for restore tasks to complete
    [Parameter()][string]$recoverDate = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

if($recoverDate){
    $recoverUsecs = dateToUsecs $recoverDate
}

# find the VMs to recover
$vms = api get "/searchvms?entityTypes=kVMware&vmName=$vmName"
$exactVMs = $vms.vms | Where-Object {$_.vmDocument.objectName -eq $vmName}
$versions = $exactVMs.vmDocument.versions | Sort-Object -Property snapshotTimestampUsecs

# select vesion
if($recoverDate){
    $versions = $versions | Where-Object snapshotTimestampUsecs -gt $recoverUsecs
    if($versions){
        $version = $versions[0]
        $exactVM = ($exactVMs | Where-Object {$version -in $exactVMs.vmDocument.versions})[0]
    }
}else{
    $exactVM = ($exactVMs | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]
    $version = $exactVMs.vmDocument.versions[0]
}

# find vCenter
$hv = api get '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter' | Where-Object { $_.displayName -eq $vCenter }
$vCenterId = $hv[0].id

# find vSphere recovery target pool, datastore, folder, network
$resourcePools = api get "/resourcePools?vCenterId=$vCenterId" | where-object { $_.resourcePool.displayName -eq $vmResourcePool }
$resourcePoolId = $resourcePools[0].resourcePool.id

$datastores = api get "/datastores?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId" | Where-Object { $_.vmWareEntity.name -eq $vmDatastore }
$vmFolders = (api get "/vmwareFolders?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId").vmFolders  | Where-Object { $_.displayName -eq $vmFolder }
$networks = api get "/networkEntities?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId" | Where-Object { $_.displayName -eq $vmNetwork }

# build recovery task
$recoverTime = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')

$restoreParams = @{
    'name' = "Recover-$vmName-$recoverTime";
    'objects' = @(
        @{
            'entity' = $exactVM.vmDocument.objectId.entity
            'jobId' = $exactVM.vmDocument.objectId.jobId;
            'jobUid' = $exactVM.vmDocument.objectId.jobUid;
            'jobInstanceId' = $version.instanceId.jobInstanceId;
            'startTimeUsecs' = $version.instanceId.jobStartTimeUsecs
        }
    );
    'powerStateConfig' = @{
        'powerOn' = $False
    };
    'restoredObjectsNetworkConfig' = @{
        'networkEntity' = $networks[0];
        'disableNetwork' = $false
    };
    'continueRestoreOnError' = $False;
    'restoreParentSource' = $hv[0];
    'resourcePoolEntity' = $resourcePools[0].resourcePool;
    'datastoreEntity' = $datastores[0];
    'vmwareParams' = @{
        'targetVmFolder' = $vmFolders[0]
    }
}

if($poweron){
    $restoreParams.powerStateConfig.powerOn = $True
}

if($prefix -ne ''){
    $restoreParams['renameRestoredObjectParam'] = @{'prefix' = "$prefix"}
}

if($disableNetwork){
    $restoreParams.restoredObjectsNetworkConfig.disableNetwork = $True
}

"Restoring $vmName..."
$restore = api post /restore $restoreParams

if($wait){
    "Waiting for restore to complete..."
    $finishedStates = @('kCanceled', 'kSuccess', 'kFailure')
    $taskid = $restore.restoreTask.performRestoreTaskState.base.taskId
    do {
        if ($pass -gt 0){
            sleep 10
            $pass = 1
        }
        $restoreTask = api get /restoretasks/$taskid
        $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
    } until ($restoreTaskStatus -in $finishedStates)
    write-host "Restore task $($restoreTask.restoreTask.performRestoreTaskState.base.name) finished with status: $($restoreTask.restoreTask.performRestoreTaskState.base.publicStatus)"
}
