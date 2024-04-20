### usage: ./restoreVMs.ps1 -vip mycluster -username myusername -domain mydomain.net -vmlist ./vmlist.txt

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][string]$vmTag = $null,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmlist = '', # list of VMs to recover
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$vCenterName,
    [Parameter()][string]$datacenterName,
    [Parameter()][string]$hostName,  # esx cluster or stand alone host
    [Parameter()][string]$folderName,
    [Parameter()][string]$networkName,
    [Parameter()][string]$datastoreName,
    [Parameter()][string]$prefix = '',
    [Parameter()][int]$vlan,
    [Parameter()][switch]$preserveMacAddress,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$poweron, # leave powered off by default
    [Parameter()][switch]$wait, # wait for restore tasks to complete
    [Parameter()][switch]$noPrompt,
    [Parameter()][int]$maxConcurrentVMRestores = 10
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

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# search for vm tags
if($vmTag){
    $taggedVMlist = api get "/searchvms?entityTypes=kVMware&vmName=$vmTag"
    $taggedVMs = $taggedVMlist.vms | Where-Object  {$vmTag -in $_.vmDocument.objectId.entity.vmwareEntity.tagAttributesVec.name} 
    $vmNames = $vmNames + @($taggedVMs.vmDocument.objectName) | Sort-Object -Unique
}

if($vmNames.Count -eq 0){
    Write-Host "No VMs specified for restore" -ForegroundColor Yellow
    exit
}

$restores = @()
$recoverIds = @()
$recoveryNames = @{}
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
                "powerOnVms"                 = $false;
                "continueOnError"            = $false;
                "recoveryProcessType"        = "CopyRecovery"
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
    if(!$hostSource){
        Write-Host "ESXi Cluster/Host $hostName not found (use HA cluster name if ESXi hosts are clustered)" -ForegroundColor Yellow
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
                "detachNetwork" = $True;
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
                "id" = $network[0].id
            };
            "disableNetwork"     = $False;
            "preserveMacAddress" = $False
        }
        $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryTargetConfig.newSourceConfig.vCenterParams.networkConfig["detachNetwork"] = $False
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
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams['renameRecoveredVmsParams'] = @{
        'prefix' = [string]$prefix;
    }
}

# select cluster interface
if($vlan){
    $vlanObj = api get vlans | Where-Object id -eq $vlan
    if($vlanObj){
        $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams['vlanConfig'] = @{
            "id" = $vlanObj.id;
            "interfaceName" = $vlanObj.vlanName.split('.')[0]
        }
    }else{
        Write-Host "vlan $vlan not found" -ForegroundColor Yellow
        exit
    }
}

# prompt for confirmation
if(!$noPrompt){
    Write-Host "Ready to restore:`n    $prefix$($vmNames -join "`n    $prefix")" 
    $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
    if($confirm.ToLower() -ne 'yes' -and $confirm.ToLower() -ne 'y'){
        exit
    }
}

$v1FinishedStates = @('kSuccess', 'kWarning', 'kFailure', 'kCanceled')

function waitForSlot($maxConcurrentVMRestores){
    $restoreTaskCount = 1000000
    do {
        $restoreTasks = api get "/restoretasks?restoreTypes=kRecoverVMs&startTimeUsecs=$(timeAgo 2 days)" | Where-Object {$_.restoreTask.performRestoreTaskState.base.publicStatus -notin $v1FinishedStates}
        $restoreTaskCount = $restoreTasks.Count
        if($restoreTaskCount -lt $maxConcurrentVMRestores){
            break
        }
        Start-Sleep 60
    } until($restoreTaskCount -lt $maxConcurrentVMRestores) 
}

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
        waitForSlot $maxConcurrentVMRestores
        $restoreParams.name = "Recover_VM_$($prefix)$($vmName)_$($recoverDateString)"
        write-host "restoring $($prefix)$($vmName)"
        if($snapshotId -notin $restores){
            $restores += $snapshotId
            $restoreParams.vmwareParams.objects = @(
                @{
                    "snapshotId" = $snapshotId
                }
            )
            $recovery = api post -v2 data-protect/recoveries $restoreParams
            $recoverIds = @($recoverIds + $recovery.id)
            $recoveryNames["$($recovery.id)"] = "$($prefix)$($vmName)"
        }
    }else{
        write-host "skipping $vmName no snapshot available"
    }
}

# wait for restores to complete
if($wait){
    $finishedStates = @('Canceled', 'Succeeded', 'Warning', 'Failed')
    "Waiting for restores to complete..."
    do{
        Start-Sleep 60
        foreach($recoveryId in $recoverIds){
            $recoveryTask = api get -v2 data-protect/recoveries/$($recoveryId)?includeTenants=true
            $status = $recoveryTask.status
            if($status -in $finishedStates){
                write-host "Restore task for $($recoveryNames["$($recoveryId)"]) finished with status: $status"
                $recoverIds = @($recoverIds | Where-Object {$_ -ne $recoveryId})
            }
        }
    } until ($recoverIds.Count -eq 0)
}
