### usage: ./restoreVMs.ps1 -vip mycluster -username myusername -domain mydomain.net -vmlist ./vmlist.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][string]$tenant = $null,
    [Parameter()][string]$vmTag = $null,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmlist = '', # list of VMs to recover
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$vCenterName,
    [Parameter()][string]$datacenterName,
    [Parameter()][string]$hostName,
    [Parameter()][string]$folderName,
    [Parameter()][string]$networkName,
    [Parameter()][string]$datastoreName,
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$preserveMacAddress,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$poweron, # leave powered off by default
    [Parameter()][switch]$wait, # wait for restore tasks to complete
    [Parameter()][switch]$noPrompt,
    [Parameter()][ValidateSet('InstantRecovery','CopyRecovery')][string]$recoveryType = 'InstantRecovery'
)

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
    return $items | Sort-Object -Unique
}

$vmNames = @(gatherList -Param $vmName -FilePath $vmList -Name 'vms' -Required $false)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# search for vm tags
if($vmTag){
    $taggedVMlist = api get "/searchvms?entityTypes=kVMware&vmName=$vmTag"
    $taggedVMs = $taggedVMlist.vms | Where-Object  {$vmTag -in $_.vmDocument.objectId.entity.vmwareEntity.tagAttributesVec.name} 
    $vmNames = $vmNames + @($taggedVMs.vmDocument.objectName) | Sort-Object -Unique
}

# prompt for confirmation
if(!$noPrompt){
    Write-Host "Ready to restore:`n    $prefix$($vmNames -join "`n    $prefix")" 
    $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
    if($confirm.ToLower() -ne 'yes' -and $confirm.ToLower() -ne 'y'){
        exit
    }
}

if($vmNames.Count -eq 0){
    Write-Host "No VMs specified for restore" -ForegroundColor Yellow
    exit
}

$restores = @()
$restoreParams = @{}

$recoverDateString = (get-date).ToString('yyyy-MM-dd_hh-mm-ss')

$restoreParams = @{
    "name"                = "Recover_VM_$recoverDateString";
    "snapshotEnvironment" = "kVMware";
    "vmwareParams"        = @{
        "objects"         = @();
        "recoveryAction"  = "RecoverVMs";
        "recoverVmParams" = @{
            "targetEnvironment"                = "kVMware";
            "recoverProtectionGroupRunsParams" = @();
            "vmwareTargetParams"               = @{
                "recoveryTargetConfig"       = @{
                    "recoverToNewSource"   = $false;
                    "originalSourceConfig" = @{
                        "networkConfig" = @{
                            "detachNetwork"  = $false;
                            "disableNetwork" = $false
                        }
                    }
                };
                "renameRecoveredVmsParams"   = @{
                    "prefix" = $null;
                    "suffix" = $null
                };
                "renameRecoveredVAppsParams" = $null;
                "powerOnVms"                 = $false;
                "continueOnError"            = $false;
                "recoveryProcessType"        = "InstantRecovery"
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
                "detachNetwork" = $False;
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

if($poweron){
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.powerOnVms = $True
}

if($prefix -ne ''){
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.renameRecoveredVmsParams.prefix = "$prefix-"
}

$restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryProcessType = $recoveryType

# get list of VM backups

foreach($vm in $vmNames){
    $vmName = [string]$vm
    $vms = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=$vmName&environments=kVMware"
    $exactVMs = $vms.objects | Where-Object name -eq $vmName
    $latestsnapshot = ($exactVMs | Sort-Object -Property @{Expression={$_.latestSnapshotsInfo[0].protectionRunStartTimeUsecs}; Ascending = $False})[0]

    if($recoverDate){
        $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))
    
        $snapshots = api get -v2 "data-protect/objects/$($latestsnapshot.id)/snapshots?protectionGroupIds=$($latestsnapshot.latestSnapshotsInfo.protectionGroupId)"
        $snapshots = $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending | Where-Object runStartTimeUsecs -lt $recoverDateUsecs
        if($snapshots -and $snapshots.Count -gt 0){
            $snapshot = $snapshots[0]
            $snapshotId = $snapshot.id
        }else{
            Write-Host "No snapshots available for $vmName"
        }
    }else{
        $snapshot = $latestsnapshot.latestSnapshotsInfo[0].localSnapshotInfo
        $snapshotId = $snapshot.snapshotId
    }

    if($snapshotId){
        write-host "restoring $vmName"
        if($snapshotId -notin $restores){
            $restores += $snapshotId
            $restoreParams.vmwareParams.objects += @{
                "snapshotId" = $snapshotId
            }
        }
    }else{
        write-host "skipping $vmName no snapshot available"
    }
}

if($restoreParams.vmwareParams.objects.Count -gt 0){
    $recovery = api post -v2 data-protect/recoveries $restoreParams
}else{
    Write-Host "No VMs to restore" -ForegroundColor Yellow
    exit
}

# wait for restores to complete
if($wait){
    "Waiting for restores to complete..."
    $finishedStates = @('Canceled', 'Succeeded', 'kFailed')
    $pass = 0
    do{
        Start-Sleep 10
        $recoveryTask = api get -v2 data-protect/recoveries/$($recovery.id)?includeTenants=true
        $status = $recoveryTask.status

    } until ($status -in $finishedStates)
    write-host "Restore task finished with status: $status"
}
