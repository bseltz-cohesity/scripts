### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmList,
    [Parameter(Mandatory = $True)][string]$vCenterName,
    [Parameter(Mandatory = $True)][string]$dataCenterName,
    [Parameter(Mandatory = $True)][string]$computeResource,
    [Parameter(Mandatory = $True)][string]$folderName,
    [Parameter()][string]$networkName,
    [Parameter()][string]$viewName = 'cloneVMs',
    [Parameter()][string]$prefix = 'clone-',
    [Parameter()][switch]$powerOn,
    [Parameter()][switch]$showVersions,
    [Parameter()][int64]$runId,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$wait
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$vmnames = @(gatherList -Param $vmName -FilePath $vmList -Name 'VMs' -Required $True)

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

# select vCenter
$vCenterList = api get /entitiesOfType?environmentTypes=kVMware`&vmwareEntityTypes=kVCenter`&vmwareEntityTypes=kStandaloneHost
$vCenter = $vCenterList | Where-Object { $_.displayName -ieq $vCenterName }
$vCenterId = $vCenter.id

if(! $vCenter){
    Write-Host "vCenter Not Found" -ForegroundColor Yellow
    exit
}

# select vCenter
$vCenterSource = api get "protectionSources?environments=kVMware&includeVMFolders=true&excludeTypes=kVirtualMachine" | Where-Object {$_.protectionSource.name -eq $vCenterName}
$vCenterList = api get "/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter&vmwareEntityTypes=kStandaloneHost"
$vCenter = $vCenterList | Where-Object { $_.displayName -ieq $vCenterName }
$vCenterId = $vCenter.id

if(! $vCenter){
    Write-Host "vCenter Not Found" -ForegroundColor Yellow
    exit
}

# select data center
$dataCenterSource = $vCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $datacenterName}
if(!$dataCenterSource){
    Write-Host "Datacenter $datacenterName not found" -ForegroundColor Yellow
    exit
}

# get host folder
$hostFolder = $dataCenterSource.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.folderType -eq 'kHostFolder'}

# select host
$hostSource = $hostFolder.nodes | Where-Object {$_.protectionSource.name -eq $computeResource}
if(!$hostSource){
    Write-Host "ESXi Cluster/Host $computeResource not found (use HA cluster name if ESXi hosts are clustered)" -ForegroundColor Yellow
    exit
}

# select resource pool
$resourcePoolSource = $hostSource.nodes | Where-Object {$_.protectionSource.vmWareProtectionSource.type -eq 'kResourcePool'}
$resourcePoolId = $resourcePoolSource.protectionSource.id
$resourcePool = api get /resourcePools?vCenterId=$vCenterId | Where-Object {$_.resourcePool.id -eq $resourcePoolId}

# select VM folder
$vmfolderId = @{}


walkVMFolders $vCenterSource

$folderId = $vmfolderId[$folderName]
if(! $folderId){
    Write-Host "folder $folderName not found" -ForegroundColor Yellow
    exit
}

$vmFolders = api get /vmwareFolders?resourcePoolId=$resourcePoolId`&vCenterId=$vCenterId

$vmFolder = $vmFolders.vmFolders | Where-Object id -eq $folderId
if(! $vmFolder){
    Write-Host "folder $folderName not found" -ForegroundColor Yellow
    exit
}

$cloneTask = @{
    'name' = 'Clone-VM';
    'objects' = @();
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
    $cloneTask.restoredObjectsNetworkConfig = @{'networkEntity' = $network}
}

foreach($thisVmName in $vmnames){
    $searchResults = api get /searchvms?entityTypes=kVMware`&vmName=$thisVmName
    $searchResult = $searchResults.vms | Where-Object {$_.vmDocument.objectName -ieq $thisVmName }
    if(! $searchResult){
        Write-Host "VM $thisVmName Not Found" -foregroundcolor yellow
        exit 1
    }
    $latestVM = ($searchResult | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]
    $versions = $latestVM.vmDocument.versions
    if($showVersions){
        $versions | Select-Object -Property @{label='runId'; expression={$_.instanceId.jobInstanceId}}, @{label='runDate'; expression={usecsToDate $_.instanceId.jobStartTimeUsecs}}
        exit 0
    }
    
    if($runId){
        $version = $versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId}
        if(! $version){
            Write-Host "No snapshot of VM $thisVmName from run ID: $runId"
            exit 1
        }
    }else{
        $version = $versions[0]
    }
    $cloneTask.objects = @($cloneTask.objects + @{
        'jobId' = $latestVM.vmDocument.objectId.jobId;
        'jobUid' = $latestVM.vmDocument.objectId.jobUid;
        'entity' = $latestVM.vmDocument.objectId.entity;
        'jobInstanceId' = $version.instanceId.jobInstanceId;
        'startTimeUsecs' = $version.instanceId.jobStartTimeUsecs
    })
}

$response = api post /clone $cloneTask

if($response){
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    foreach($thisVmName in $vmnames){
        Write-Host "Cloning $thisVmName as $prefix$thisVmName..."
    }
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
            sleep 5
        }
    }
    Write-Host "Clone task completed with status: $publicStatus"
    if($publicStatus -eq 'kFailure'){
        Write-Host "Error Message: $($task.restoreTask.performRestoreTaskState.base.error.errorMsg)"
    }
}
