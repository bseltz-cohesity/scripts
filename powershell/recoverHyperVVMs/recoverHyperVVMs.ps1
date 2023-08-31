### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # don't prompt for password
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmlist = '', # list of VMs to recover
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$scvmmName,
    [Parameter()][string]$failoverClusterName,
    [Parameter()][string]$hostName,  # hyper-v cluster or stand alone host
    [Parameter()][string]$networkName,
    [Parameter()][string]$volumeName,
    [Parameter()][string]$prefix = '',
    [Parameter()][switch]$detachNetwork,
    [Parameter()][switch]$poweron, # leave powered off by default
    [Parameter()][switch]$wait, # wait for restore tasks to complete
    [Parameter()][switch]$dbg
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

$vmNames = @(gatherList -Param $vmName -FilePath $vmList -Name 'vms' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$restores = @()
$restoreParams = @{}

$recoverDateString = (get-date).ToString('yyyy-MM-dd_hh-mm-ss')

$restoreParams = @{
    "name" = "Recover_VM_$recoverDateString";
    "snapshotEnvironment" = "kHyperV";
    "hypervParams" = @{
        "objects" = @();
        "recoveryAction" = "RecoverVMs";
        "recoverVmParams" = @{
            "targetEnvironment" = "kHyperV";
            "recoverProtectionGroupRunsParams" = @();
            "hypervTargetParams" = @{
                "recoveryTargetConfig" = @{
                    "recoverToNewSource" = $false;
                };
                "continueOnError" = $false;
                "powerOnVms" = $false;
                "instantRecovery" = $true;
                "preserveUuids" = $false
            }
        }
    }
}

# alternate restore location params
if($scvmmName -or $failoverClusterName -or $hostName){
    $standAloneHost = $False
    if($hostName -and !($scvmmName -or $failoverClusterName)){
        $standAloneHost = $True
        $scvmmName = $hostName
    }elseif($failoverClusterName){
        $scvmmName = $failoverClusterName
    }
    # require alternate location params
    if(!$hostName){
        Write-Host "hostName required" -ForegroundColor Yellow
        exit
    }
    if(!$volumeName){
        Write-Host "volumeName required" -ForegroundColor Yellow
        exit
    }

    # select scvmmServer/failover cluster
    $scvmmSource = api get protectionSources/rootNodes?environments=kHyperV | Where-Object {$_.protectionSource.name -eq $scvmmName}
    if(!$scvmmSource){
        Write-Host "$scvmmName is not a registered source" -ForegroundColor Yellow
        exit
    }
    # select host
    if($standAloneHost -eq $True){
        $hostEntityId = $scvmmSource.protectionSource.id
    }else{
        $hostEntity = api get "/entitiesOfType?environmentTypes=kHyperV,kHyperVVSS&hypervEntityTypes=kHypervHost" | Where-Object {$_.parentId -eq $scvmmSource.protectionSource.id -and $_.displayName -eq $hostName}
        if(!$hostEntity){
            Write-Host "host $hostName not found" -ForegroundColor Yellow
            exit
        }
        $hostEntityId = $hostEntity.id
    }
    
    # select volume
    $volEntity = api get "/entitiesOfType?environmentTypes=kHyperV,kHyperVVSS&hypervEntityTypes=kDatastore&rootEntityId=$($scvmmSource.protectionSource.id)&parentEntityId=$($hostEntityId)" | Where-Object {$(($_.hypervEntity.datastoreInfo.mountPointVec -split ' ')[0]) -eq $volumeName}
    if(!$volEntity){
        Write-Host "$volumeName not found" -ForegroundColor Yellow
        exit
    }

    $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.recoverToNewSource = $True
    if($standAloneHost -eq $True){
        $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig["newSourceConfig"] = @{
            "sourceType" = "kStandaloneHost";
            "standaloneHostParams" = @{
                "source" = @{
                    "id" = $scvmmSource.protectionSource.id
                };
                "volume" = @{
                    "id" = $volEntity.id
                };
                "networkConfig" = @{
                    "detachNetwork" = $true
                };
                "host" = @{
                    "id" = $hostEntityId
                }
            }
        }
    }elseif($failoverClusterName){
        $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig["newSourceConfig"] = @{
            "sourceType" = "kStandaloneCluster";
            "standaloneClusterParams" = @{
                "source" = @{
                    "id" = $scvmmSource.protectionSource.id
                };
                "volume" = @{
                    "id" = $volEntity.id
                };
                "networkConfig" = @{
                    "detachNetwork" = $true
                };
                "host" = @{
                    "id" = $hostEntityId
                }
            }
        }
    }else{
        $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig["newSourceConfig"] = @{
            "sourceType" = "kSCVMMServer";
            "scvmmServerParams" = @{
                "source" = @{
                    "id" = $scvmmSource.protectionSource.id
                };
                "volume" = @{
                    "id" = $volEntity.id
                };
                "networkConfig" = @{
                    "detachNetwork" = $true
                };
                "host" = @{
                    "id" = $hostEntityId
                }
            }
        }
    }

    if(!$detachNetwork){
        # select network
        if(! $networkName){
            Write-Host "network name required" -ForegroundColor Yellow
            exit
        }
        $network = api get "/entitiesOfType?environmentTypes=kHyperV,kHyperVVSS&hypervEntityTypes=kNetwork&rootEntityId=$($scvmmSource.protectionSource.id)&parentEntityId=$($hostEntityId)"  | Where-Object displayName -eq $networkName
        if(! $network){
            Write-Host "network $networkName not found" -ForegroundColor Yellow
            exit
        }
        if($standAloneHost -eq $True){
            $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.newSourceConfig.standaloneHostParams.networkConfig.detachNetwork = $false
            $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.newSourceConfig.standaloneHostParams.networkConfig['virtualSwitch'] = @{
                "id" = $network[0].id
            }
        }elseif($failoverClusterName){
            $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.newSourceConfig.standaloneClusterParams.networkConfig.detachNetwork = $false
            $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.newSourceConfig.standaloneClusterParams.networkConfig['virtualSwitch'] = @{
                "id" = $network[0].id
            }
        }else{
            $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.newSourceConfig.scvmmServerParams.networkConfig.detachNetwork = $false
            $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.newSourceConfig.scvmmServerParams.networkConfig['virtualSwitch'] = @{
                "id" = $network[0].id
            }
        }
    }
}else{
    $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig["originalSourceConfig"] = @{
        "networkConfig" = @{
            "detachNetwork" = $false
        }
    }
    if($detachNetwork){
        $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.originalSourceConfig.networkConfig.detachNetwork = $True
    }
}

if($poweron){
    $restoreParams.hypervParams.recoverVmParams.hypervTargetParams.powerOnVms = $True
}

if($prefix -ne ''){
    $restoreParams.hypervParams.recoverVmParams.hypervTargetParams["renameRecoveredVmsParams"] = @{
        "prefix" = $([string]$prefix + '-')
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

# get list of VM backups
foreach($vm in $vmNames){
    if($null -ne $vm -and $vm -ne ''){
        $vms = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverVMs,RecoverVApps,RecoverVAppTemplates&searchString=$vm&environments=kHyperV"
        $exactVMs = $vms.objects | Where-Object name -eq $vm
        $latestsnapshot = ($exactVMs | Sort-Object -Property @{Expression={$_.latestSnapshotsInfo[0].protectionRunStartTimeUsecs}; Ascending = $False})[0]
    
        if($recoverDate){
            $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))
        
            $snapshots = api get -v2 "data-protect/objects/$($latestsnapshot.id)/snapshots?protectionGroupIds=$($latestsnapshot.latestSnapshotsInfo.protectionGroupId)"
            $snapshots = $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending | Where-Object runStartTimeUsecs -lt $recoverDateUsecs
            if($snapshots -and $snapshots.Count -gt 0){
                $snapshot = $snapshots[0]
                $snapshotId = $snapshot.id
            }else{
                Write-Host "No snapshots available for $vm"
            }
        }else{
            $snapshot = $latestsnapshot.latestSnapshotsInfo[0].localSnapshotInfo
            $snapshotId = $snapshot.snapshotId
        }
    
        if($snapshotId){
            write-host "restoring $vm"
            if($snapshotId -notin $restores){
                $restores += $snapshotId
                $restoreParams.hypervParams.objects += @{
                    "snapshotId" = $snapshotId
                }
            }
        }else{
            write-host "skipping $vm no snapshot available"
        }
    }
}

if($dbg){
    $restoreParams | ConvertTo-Json -Depth 99 | Out-file 'debug-recoverVMsV2.json'
}

if($restoreParams.hypervParams.objects.Count -gt 0){
    $recovery = api post -v2 data-protect/recoveries $restoreParams
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
        Start-Sleep 10
        $recoveryTask = api get -v2 data-protect/recoveries/$($recovery.id)?includeTenants=true
        $status = $recoveryTask.status

    } until ($status -in $finishedStates)
    write-host "Restore task finished with status: $status"
}
