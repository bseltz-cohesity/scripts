### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$vmName,
    [Parameter()][string]$vCenterName,
    [Parameter()][string]$datacenterName,
    [Parameter()][string]$computeResource,
    [Parameter()][string]$folderName,
    [Parameter()][string]$networkName,
    [Parameter()][string]$datastoreName,
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$preserveMacAddress,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$powerOn,
    [Parameter()][switch]$showVersions,
    [Parameter()][int64]$version = 0
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find the VMs to recover
$vms = api get "/searchvms?entityTypes=kVMware&vmName=$vmName"
$exactVMs = $vms.vms | Where-Object {$_.vmDocument.objectName -eq $vmName}
$latestsnapshot = ($exactVMs | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

### show versions
if($showVersions){
    "Version  Date"
    "=======  ===="
    0..($latestsnapshot[0].vmDocument.versions.count - 1) | ForEach-Object{
        "{0,7}  {1}" -f $_, (usecsToDate $latestsnapshot[0].vmDocument.versions[$_].instanceId.jobStartTimeUsecs)
    }
    exit 0
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
            'jobInstanceId' = $latestsnapshot[0].vmDocument.versions[$version].instanceId.jobInstanceId
            'startTimeUsecs' = $latestsnapshot[0].vmDocument.versions[$version].instanceId.jobStartTimeUsecs
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
}

# allow cloudRetrieve
$nowUsecs = dateToUsecs
$localreplica = $latestsnapshot[0].vmDocument.versions[$version].replicaInfo.replicaVec | Where-Object {$_.target.type -eq 1 -and $_.expiryTimeUsecs -gt $nowUsecs}
$archivereplica = $latestsnapshot[0].vmDocument.versions[$version].replicaInfo.replicaVec | Where-Object {$_.target.type -eq 3 -and $_.expiryTimeUsecs -gt $nowUsecs}

if($archivereplica -and (! $localreplica)){
    $restoreParams['objects'][0]['archivalTarget'] = $archivereplica[0].target.archivalTarget
}

# alternate restore location params
if($vCenterName){
    # require alternate location params
    if(!$datacenterName){
        Write-Host "datacenterName required" -ForegroundColor Yellow
        exit
    }
    if(!$computeResource){
        Write-Host "computeResource required" -ForegroundColor Yellow
        exit
    }
    if(!$datastoreName){
        Write-Host "datastoreName required" -ForegroundColor Yellow
        exit
    }
    if(!$folderName){
        Write-Host "folderName required" -ForegroundColor Yellow
        exit
    }

    # select vCenter
    $vCenterSource = api get protectionSources?environments=kVMware`&includeVMFolders=true`&excludeTypes=kVirtualMachine | Where-Object {$_.protectionSource.name -eq $vCenterName}
    $vCenterList = api get /entitiesOfType?environmentTypes=kVMware`&vmwareEntityTypes=kVCenter`&vmwareEntityTypes=kStandaloneHost
    $vCenter = $vCenterList | Where-Object { $_.displayName -ieq $vCenterName }
    $vCenterId = $vCenter.id

    if(! $vCenter){
        write-host "vCenter Not Found" -ForegroundColor Yellow
        exit
    }

    # select data center
    $dataCenterSource = $vCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $datacenterName}
    if(!$dataCenterSource){
        Write-Host "Datacenter $datacenterName not found" -ForegroundColor Yellow
        exit
    }

    # select host
    $hostSource = $dataCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $computeResource}
    if(!$dataCenterSource){
        Write-Host "Datacenter $datacenterName not found" -ForegroundColor Yellow
        exit
    }

    # select resource pool
    $resourcePoolSource = $hostSource.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kResourcePool'}
    $resourcePoolId = $resourcePoolSource.protectionSource.id
    $resourcePool = api get /resourcePools?vCenterId=$vCenterId | Where-Object {$_.resourcePool.id -eq $resourcePoolId}

    # select datastore
    $datastores = api get "/datastores?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId" | Where-Object { $_.vmWareEntity.name -eq $datastoreName }
    if(!$datastores){
        Write-Host "Datastore $datastoreName not found" -ForegroundColor Yellow
        exit
    }

    # select VM folder
    $vmfolderId = @{}

    function walkVMFolders($node, $parent=$null, $fullPath=''){
        $fullPath = "{0}/{1}" -f $fullPath, $node.protectionSource.name
        $relativePath = $fullPath.split('vm/', 2)[1]
        if($relativePath){
            $vmFolderId[$fullPath] = $node.protectionSource.id
            $vmFolderId[$relativePath] = $node.protectionSource.id
            $vmFolderId["/$relativePath"] = $node.protectionSource.id
            $vmFolderId["$($fullPath.Substring(1))"] = $node.protectionSource.id
        }
        if($node.PSObject.Properties['nodes']){
            foreach($subnode in $node.nodes){
                walkVMFolders $subnode $node $fullPath
            }
        }
    }
    
    walkVMFolders $vCenterSource

    $folderId = $vmfolderId[$folderName]
    if(! $folderId){
        write-host "folder $folderName not found x" -ForegroundColor Yellow
        exit
    }

    $vmFolders = api get /vmwareFolders?resourcePoolId=$resourcePoolId`&vCenterId=$vCenterId

    $vmFolder = $vmFolders.vmFolders | Where-Object id -eq $folderId
    if(! $vmFolder){
        write-host "folder $folderName not found" -ForegroundColor Yellow
        exit
    }

    $restoreParams['restoreParentSource'] = $vCenter
    $restoreParams['resourcePoolEntity'] = $resourcePool.resourcePool
    $restoreParams['datastoreEntity'] = $datastores[0]
    $restoreParams['vmwareParams'] = @{'targetVmFolder' = $vmFolder}

    if(!$detachNetwork){
        # select network
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
}

if($powerOn){
    $restoreParams.powerStateConfig.powerOn = $True
}

if($detachNetwork){
    $restoreParams.restoredObjectsNetworkConfig['detachNetwork'] = $True
}

if ($prefix -ne '') {
    $restoreParams['renameRestoredObjectParam'] = @{
        'prefix' = [string]$prefix;
    }
    "Recovering $vmName as $prefix$vmName..."
}else{
    "Recovering $vmName..."
}

$null = api post /restore $restoreParams
