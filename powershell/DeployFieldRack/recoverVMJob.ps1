### recover all VMs from a proptectino job

### usage: ./recoverVMJob.ps1 -vip mycluster -username admin [ -domain local ] -jobName myVMJob -vCenter myvcenter.mydomain.net -vmNetwork 'VM Network' -vmDatastore datastore1 [ -vmResourcePool resgroup1 ] [ -vmFolder folder1 ]
### example: ./recoverVMJob.ps1 -vip 192.168.1.199 -username admin -jobName GarrisonToVE1 -vCenter vCenter6-B.seltzer.net -vmNetwork 'VM Network' -vmDatastore 450GB

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter(Mandatory = $True)][string]$vCenter,
    [Parameter()][string]$vmResourcePool = 'Resources',
    [Parameter(Mandatory = $True)][string]$vmDatastore,
    [Parameter()][string]$vmFolder = 'vm',
    [Parameter(Mandatory = $True)][string]$vmNetwork
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find the VMs to recover
$vms = api get restore/objects?search=$jobName
$exactVMs = $vms | Where-Object { $_.objectSnapShotInfo.jobName -eq $jobName }
$latestsnapshot = ($exactvms | sort-object -property @{Expression={$_.objectSnapshotInfo.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

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
    'name' = "Recover-$jobName-$recoverDate";
    'objects' = @(
        @{
            'jobId' = $latestsnapshot.objectSnapshotInfo[0].jobId;
            'jobUid' = @{
                'clusterId' = $latestsnapshot.objectSnapshotInfo[0].jobUid.clusterId;
                'clusterIncarnationId' = $latestsnapshot.objectSnapshotInfo[0].jobUid.clusterIncarnationId;
                'objectId' = $latestsnapshot.objectSnapshotInfo[0].jobUid.id;
            };
            'jobInstanceId' = $latestsnapshot.objectSnapshotInfo[0].versions[0].jobRunId;
            'startTimeUsecs' = $latestsnapshot.objectSnapshotInfo[0].versions[0].startedTimeUsecs;
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

"Restoring VMs..."
$result = api post /restore $myObject

