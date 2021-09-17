### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$vmName,
    [Parameter(Mandatory = $True)][string]$vCenterName,
    [Parameter(Mandatory = $True)][string]$dataCenterName,
    [Parameter(Mandatory = $True)][string]$computeResource,
    [Parameter(Mandatory = $True)][string]$folderName,
    [Parameter()][string]$networkName,
    [Parameter()][string]$viewName = 'cloneVMs',
    [Parameter()][string]$prefix = 'clone-',
    [Parameter()][switch]$powerOn,
    [Parameter()][switch]$detachNetwork
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for latest snapshot of VM
$searchResults = api get /searchvms?entityTypes=kVMware`&vmName=$vmName
$searchResult = $searchResults.vms | Where-Object {$_.vmDocument.objectName -ieq $vmName }
if(! $searchResult){
    write-host "VM Not Found" -foregroundcolor yellow
    exit
}

$latestVM = ($searchResult | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

### select vCenter
$vCenterList = api get /entitiesOfType?environmentTypes=kVMware`&vmwareEntityTypes=kVCenter`&vmwareEntityTypes=kStandaloneHost
$vCenter = $vCenterList | Where-Object { $_.displayName -ieq $vCenterName }
$vCenterId = $vCenter.id

if(! $vCenter){
    write-host "vCenter Not Found" -ForegroundColor Yellow
    exit
}

### select resource pool
$vCenterSource = api get protectionSources?environments=kVMware`&includeVMFolders=true`&excludeTypes=kVirtualMachine | Where-Object {$_.protectionSource.name -eq $vCenterName}
$dataCenterSource = $vCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $dataCenterName}
$hostSource = $dataCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $computeResource}
$resourcePoolSource = $hostSource.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kResourcePool'}
$resourcePoolId = $resourcePoolSource.protectionSource.id
$resourcePool = api get /resourcePools?vCenterId=$vCenterId | Where-Object {$_.resourcePool.id -eq $resourcePoolId}
if(! $resourcePoolId){
    Write-Host "host/cluster $computeResource not found" -ForegroundColor Yellow
    exit
}

### select VM folder
$vmfolderId = @{}

function walkVMFolders($node, $parent=$null, $fullPath=''){
    $fullPath = "{0}/{1}" -f $fullPath, $node.protectionSource.name
    $relativePath = $fullPath.split('vm/', 2)[1]
    if($relativePath -and $node.protectionSource.vmWareProtectionSource.type -eq 'kFolder'){
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
    write-host "folder $folderName not found" -ForegroundColor Yellow
    exit
}

$vmFolders = api get /vmwareFolders?resourcePoolId=$resourcePoolId`&vCenterId=$vCenterId

$vmFolder = $vmFolders.vmFolders | Where-Object id -eq $folderId
if(! $vmFolder){
    write-host "folder $folderName not found" -ForegroundColor Yellow
    exit
}

$cloneTask = @{
    'name' = 'Clone-VM';
    'objects' = @(
        @{
            'jobId' = $latestVM.vmDocument.objectId.jobId;
            'jobUid' = $latestVM.vmDocument.objectId.jobUid;
            'entity' = $latestVM.vmDocument.objectId.entity;
            'jobInstanceId' = $latestVM.vmDocument.versions[0].instanceId.jobInstanceId;
            'startTimeUsecs' = $latestVM.vmDocument.versions[0].instanceId.jobStartTimeUsecs
        }
    );
    'powerStateConfig' = @{
        'powerOn' = $False
    };
    'continueRestoreOnError' = $false;
    'renameRestoredObjectParam' = @{
        'prefix' = "$prefix"
    };
    'restoreParentSource' = @{
        'type' = $vCenter.type;
        'vmwareEntity' = $vCenter.vmwareEntity;
        'id' = $vCenter.id;
        'displayName' = $vCenter.displayName;
        '_entityKey' = 'vmwareEntity';
        '_typeEntity' = $vCenter.vmwareEntity
    };
    'resourcePoolEntity' = $resourcePool.resourcePool;
    'vmwareParams' = @{
        'targetVmFolder' = $vmFolder
    };
    'viewName' = $viewName;
    'restoredObjectsNetworkConfig' = @{}
}

if($powerOn){
    $cloneTask.powerStateConfig.powerOn = $True
}

if($detachNetwork){
    $cloneTask.restoredObjectsNetworkConfig = @{
        'detachNetwork' = $True;
        'disableNetwork' = $False
    }
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
    $cloneTask.restoredObjectsNetworkConfig = @{'networkEntity' = $network}
}

$null = api post /clone $cloneTask
"Cloning $vmName as $prefix$vmName..."
