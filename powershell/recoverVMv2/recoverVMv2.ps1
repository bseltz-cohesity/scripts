### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$vmName,
    [Parameter()][string]$vCenterName,
    [Parameter()][string]$datacenterName,
    [Parameter()][string]$hostName,
    [Parameter()][string]$folderName,
    [Parameter()][string]$networkName,
    [Parameter()][string]$datastoreName,
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$preserveMacAddress,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$powerOn,
    [Parameter()][ValidateSet('InstantRecovery','CopyRecovery')][string]$recoveryType = 'InstantRecovery'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find the VMs to recover
$vms = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=$vmName&environments=kVMware"
$exactVMs = $vms.objects | Where-Object name -eq $vmName
$latestsnapshot = ($exactVMs | Sort-Object -Property @{Expression={$_.latestSnapshotsInfo[0].protectionRunStartTimeUsecs}; Ascending = $False})[0]

### build recovery task
$recoverDate = (get-date).ToString('yyyy-MM-dd_hh-mm-ss')

$restoreParams = @{
    "name"                = "Recover_VM_$recoverDate";
    "snapshotEnvironment" = "kVMware";
    "vmwareParams"        = @{
        "objects"         = @(
            @{
                "snapshotId" = $latestsnapshot.latestSnapshotsInfo[0].localSnapshotInfo.snapshotId
            }
        );
        "recoveryAction"  = "RecoverVMs";
        "recoverVmParams" = @{
            "targetEnvironment"                = "kVMware";
            "recoverProtectionGroupRunsParams" = @();
            "vmwareTargetParams"               = @{
                "recoveryTargetConfig"       = @{
                    "recoverToNewSource"   = $false
                };
                "powerOnVms"                 = $False;
                "continueOnError"            = $false;
                "recoveryProcessType"        = $recoveryType
            }
        }
    }
}

# alternate restore location params
if($vCenterName){
    # require alternate location params
    if(!$datacenterName){
        Write-Host "datacenterName required" -ForegroundColor Yellow
        exit
    }
    if(!$hostName){
        Write-Host "hostName required" -ForegroundColor Yellow
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
    $vCenterSource = api get protectionSources?environments=kVMware | Where-Object {$_.protectionSource.name -eq $vCenterName}
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
    $hostSource = $dataCenterSource.nodes[0].nodes | Where-Object {$_.protectionSource.name -eq $hostName}
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
    $vmFolders = api get /vmwareFolders?resourcePoolId=$resourcePoolId`&vCenterId=$vCenterId
    $vmFolder = $vmFolders.vmFolders | Where-Object displayName -eq $folderName
    if(! $vmFolder){
        write-host "folder $folderName not found" -ForegroundColor Yellow
        exit
    }

    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryTargetConfig.recoverToNewSource = $True
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryTargetConfig["newSourceConfig"] = @{
        "sourceType"    = "kVCenter";
        "vCenterParams" = @{
            "source"        = @{
                "id" = $vCenterId
            };
            "networkConfig" = @{
                "detachNetwork"    = $False;
            };
            "datastores"    = @(
                $datastores[0]
            );
            "resourcePool"  = @{
                "id" = $resourcePoolId
            };
            "vmFolder"      = @{
                "id" = $vmFolder.id
            }
        }
    }

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
        $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryTargetConfig.newSourceConfig.vCenterParams.networkConfig["newNetworkConfig"] = @{
            "networkPortGroup"   = @{
                "id" = $network.id
            };
            "disableNetwork"     = $False;
            "preserveMacAddress" = $False
        }
        if($preserveMacAddress){
            $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryTargetConfig.newSourceConfig.vCenterParams.networkConfig.newNetworkConfig.preserveMacAddress = $True
        }
    }
}else{
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryTargetConfig["originalSourceConfig"] = @{
        "networkConfig" = @{
            "detachNetwork"  = $False;
            "disableNetwork" = $False
        }
    }
    if($detachNetwork){
        $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryTargetConfig.originalSourceConfig.networkConfig = @{
            "detachNetwork"  = $True;
            "disableNetwork" = $True
        }
    }
}

if($powerOn){
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.powerOnVms = $True
}

if ($prefix -ne '') {
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams['renameRestoredObjectParam'] = @{
        'prefix' = [string]$prefix + '-';
    }
    "Recovering $vmName as $prefix-$vmName..."
}else{
    "Recovering $vmName..."
}

$null = api post -v2 data-protect/recoveries $restoreParams
