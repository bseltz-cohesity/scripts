### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmlist = '',
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$vCenterName,
    [Parameter()][string]$datacenterName,
    [Parameter()][string]$hostName,
    [Parameter()][string]$folderName,
    [Parameter()][string]$networkName,
    [Parameter()][array]$datastoreName,
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$preserveMacAddress,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$poweron,
    [Parameter()][switch]$wait,
    [Parameter()][string]$taskName,
    [Parameter()][switch]$overwrite,
    [Parameter()][switch]$dbg,
    [Parameter()][int]$newerThanHours,
    [Parameter()][string]$cacheFolder = '.',
    [Parameter()][int]$maxCacheMinutes = 60,
    [Parameter()][switch]$noCache
)

$useCache = $True
if($noCache){
    $useCache = False
}

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

$vmNames = @(gatherList -Param $vmName -FilePath $vmList -Name 'vms' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','
$selectedRegion = $null
$selectedRegionObject = $null

$restores = @()
$restoreParams = @{}

$nowUsecs = dateToUsecs
if($newerThanHours){
   $newerthanUsecs = $nowUsecs - ($newerThanHours * 3600000000)
}

$recoverDateString = (get-date).ToString('yyyy-MM-dd_hh-mm-ss')

if(! $taskName){
    $taskName = "Recover_VM_$recoverDateString"
}

$restoreParams = @{
    "name"                = $taskName;
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
                "overwriteExistingVm"        = $false;
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
    $vCenterList = api get "protectionSources/registrationInfo?environments=kVMware&regionId=$region"
    $vCenter = $vCenterList.rootNodes | Where-Object { $_.rootNode.name -ieq $vCenterName }
    if(! $vCenter){
        write-host "vCenter Not Found" -ForegroundColor Yellow
        exit
    }
    $vCenterId = $vCenter.rootNode.id
    $getVcenter = $True
    if($useCache -eq $True){
        $cacheFile = $(Join-Path -Path $cacheFolder -ChildPath "$($vCenterId).json")
        if(Test-Path -Path $cacheFile -PathType Leaf){
            $vCenterSource = Get-Content $cacheFile | ConvertFrom-Json
            if($vCenterSource.PSObject.Properties['timestamp']){
                $cacheAge = $nowUsecs - $vCenterSource[0].timestamp
                if($cacheAge -le ($maxCacheMinutes * 60000000)){
                    $getVcenter = $False
                }
            }
        }
    }
    if($getVcenter -eq $True){
        $vCenterSource = api get "protectionSources?id=$($vCenterId)&environments=kVMware&includeVMFolders=true&excludeTypes=kDatastore,kVirtualMachine,kVirtualApp,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&regionId=$region" | Where-Object {$_.protectionSource.name -eq $vCenterName}
        if($useCache -eq $True){
            $vCenterSource | Add-Member -MemberType NoteProperty -Name 'timestamp' -Value $nowUsecs
            $vCenterSource | ConvertTo-Json -Depth 99 | Out-File -FilePath $cacheFile
        }
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

    # select datastore
    $datastores = api get "/datastores?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId&regionId=$region" | Where-Object { $_.vmWareEntity.name -in $datastoreName }
    if(!$datastores -or $datastores.Count -lt $datastoreName.Count){
        $notFoundDatastores = $datastoreName | Where-Object {$_ -notin @($datastores.displayName)}
        foreach($notFoundDatastore in $notFoundDatastores){
            Write-Host "Datastore $notFoundDatastore not found" -ForegroundColor Yellow
        }
        exit
    }

    # select VM folder
    $vmfolderId = @{}

    function walkVMFolders($node, $parent=$null, $fullPath=''){
        $fullPath = "{0}/{1}" -f $fullPath, $node.protectionSource.name
        $relativePath = ($fullPath -split 'vm/', 2)[1]
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
                $datastores
            );
            "resourcePool"  = @{
                "id" = $resourcePoolId
            };
            "vmFolder"      = @{
                "id" = $folderId
            }
        }
    }

    if(!$detachNetwork){
        # select network
        if(! $networkName){
            Write-Host "network name required" -ForegroundColor Yellow
            exit
        }
        $networks = api get "/networkEntities?resourcePoolId=$resourcePoolId&vCenterId=$vCenterId&regionId=$region"
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

$restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryProcessType = "CopyRecovery"

# overwrite existing vm
if($overwrite){
    $restoreParams.vmwareParams.recoverVmParams.vmwareTargetParams.overwriteExistingVm = $True
}

# get list of VM backups
foreach($vm in $vmNames){
    $vmName = [string]$vm
    $vms = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=$vmName&environments=kVMware&regionId=$region"
    $exactVMs = $vms.objects | Where-Object name -eq $vmName
    $exactVMs = $exactVMs | Where-Object {$_.PSObject.Properties['latestSnapshotsInfo']}
    $latestsnapshot = ($exactVMs | Sort-Object -Property @{Expression={$_.latestSnapshotsInfo[0].protectionRunStartTimeUsecs}; Ascending = $False})[0]

    if($recoverDate){
        $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))
        $snapshots = api get -v2 "data-protect/objects/$($latestsnapshot.id)/snapshots?regionId=$region" # protectionGroupIds=$($latestsnapshot.latestSnapshotsInfo.protectionGroupId)&
        $snapshots = $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending | Where-Object runStartTimeUsecs -lt $recoverDateUsecs
        if($snapshots -and $snapshots.Count -gt 0){
            $snapshot = $snapshots[0]
            $snapshotId = $snapshot.id
        }else{
            Write-Host "No snapshots available for $vmName"
        }
    }else{
        $snapshot = $latestsnapshot.latestSnapshotsInfo[0].archivalSnapshotsInfo[0]
        $snapshotId = $snapshot.snapshotId
        if($newerThanHours -and $latestsnapshot.latestSnapshotsInfo[0].protectionRunStartTimeUsecs -lt $newerthanUsecs){
            Write-Host "Skipping $vmName (last backup was more than $($newerThanHours) hours ago)"
            $snapshotId = $null
            $vmNames = @($vmNames | Where-Object {$_ -ne $vmName})
            continue
        }
    }

    if($snapshotId){
        write-host "restoring $($prefix)$($vmName)"
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

# prompt for confirmation
if(!$noPrompt){
    Write-Host "Ready to restore:`n    $prefix$($vmNames -join "`n    $prefix")" 
    $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
    if($confirm.ToLower() -ne 'yes' -and $confirm.ToLower() -ne 'y'){
        exit
    }
}

if($dbg){
    $restoreParams | ConvertTo-Json -Depth 99 | Out-file 'debug-recoverVMsV2.json'
}

if($restoreParams.vmwareParams.objects.Count -gt 0){
    $recovery = api post -v2 "data-protect/recoveries?regionId=$region" $restoreParams
}else{
    Write-Host "No VMs to restore" -ForegroundColor Yellow
    exit
}

# wait for restores to complete
if($wait){
    "Waiting for restores to complete..."
    $finishedStates = @('Canceled', 'Succeeded', 'Failed')
    $pass = 0
    do{
        Start-Sleep 30
        $recoveryTask = api get -v2 "data-protect/recoveries/$($recovery.id)?includeTenants=true&regionId=$region"
        $status = $recoveryTask.status

    } until ($status -in $finishedStates)
    write-host "Restore task finished with status: $status"
}
