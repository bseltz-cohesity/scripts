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
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmlist = '', # list of VMs to recover
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$ahvSourceName,
    [Parameter()][string]$networkName,
    [Parameter()][string]$storageContainer,
    [Parameter()][string]$prefix = '',
    [Parameter()][int]$vlan,
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$poweron, # leave powered off by default
    [Parameter()][switch]$wait, # wait for restore tasks to complete
    [Parameter()][switch]$noPrompt,
    [Parameter()][int]$maxConcurrentVMRestores = 10,
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
    "name" = "Recover_VM_$recoverDateString";
    "snapshotEnvironment" = "kAcropolis";
    "acropolisParams" = @{
        "objects" = @();
        "recoveryAction" = "RecoverVMs";
        "recoverVmParams" = @{
            "targetEnvironment" = "kAcropolis";
            "recoverProtectionGroupRunsParams" = @();
            "acropolisTargetParams" = @{
                "recoveryProcessType" = $recoveryType;
                "recoveryTargetConfig" = @{
                    "recoverToNewSource" = $false;
                    "originalSourceConfig" = @{
                        "networkConfig" = @{
                            "detachNetwork" = $false
                        }
                    }
                };
                "renameRecoveredVmsParams" = $null;
                "powerOnVms" = $false;
                "continueOnError" = $false
            }
        }
    }
}

# alternate restore location params
if($ahvSourceName){
    # require alternate location params
    if(!$storageContainer){
        Write-Host "storageContainer required" -ForegroundColor Yellow
        exit
    }
    # select AHV target
    $ahvSource = api get "protectionSources/rootNodes?allUnderHierarchy=false&environments=kAcropolis" | Where-Object {$_.protectionSource.name -eq $ahvSourceName}
    if(! $ahvSource){
        Write-Host "AHV source $ahvSourceName not found!" -ForegroundColor Yellow
        exit
    }
    $ahvSourceId = $ahvSource.protectionSource.id
    
    # select storageContainer
    $storageContainerObject = api get "/entitiesOfType?acropolisEntityTypes=kStorageContainer&environmentTypes=kAcropolis&rootEntityId=$ahvSourceId" | Where-Object { $_.displayName -eq $storageContainer }
    if(!$storageContainerObject){
        Write-Host "storageContainer $storageContainer not found" -ForegroundColor Yellow
        exit
    }

    $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams.recoveryTargetConfig.recoverToNewSource = $True
    $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams.recoveryTargetConfig["newSourceConfig"] = @{
        "source" = @{
            "id" = $ahvSourceId
        };
        "networkConfig" = @{
            "detachNetwork" = $True;
        };
        "storageContainer" = @{
            "id" = $storageContainerObject.id
        }
    }

    if(!$detachNetwork){
        # select network
        if(! $networkName){
            Write-Host "network name required" -ForegroundColor Yellow
            exit
        }
        $networks = api get "/entitiesOfType?acropolisEntityTypes=kNetwork&environmentTypes=kAcropolis&rootEntityId=$ahvSourceId&parentEntityId=$ahvSourceId"
        $network = $networks | Where-Object displayName -eq $networkName

        if(! $network){
            Write-Host "network $networkName not found" -ForegroundColor Yellow
            exit
        }
        # ["newNetworkConfig"]
        $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams.recoveryTargetConfig.newSourceConfig.networkConfig = @{
            "networkPortGroup"   = @{
                "id" = $network[0].id
            };
            "detatchNetwork"     = $False;
        }
    }
}else{
    $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams.recoveryTargetConfig["originalSourceConfig"] = @{
        "networkConfig" = @{
            "detachNetwork"  = $False
        }
    }
    if($detachNetwork){
        $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams.recoveryTargetConfig.originalSourceConfig.networkConfig = @{
            "detachNetwork"  = $True;
        }
    }
}

if($poweron){
    $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams.powerOnVms = $True
}

if($prefix -ne ''){
    $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams['renameRecoveredVmsParams'] = @{
        'prefix' = [string]$prefix;
    }
}

# select cluster interface
if($vlan){
    $vlanObj = api get vlans | Where-Object id -eq $vlan
    if($vlanObj){
        $restoreParams.acropolisParams.recoverVmParams.acropolisTargetParams['vlanConfig'] = @{
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
    $vms = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=$vmName&environments=kAcropolis"
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
            $restoreParams.acropolisParams.objects = @(
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
