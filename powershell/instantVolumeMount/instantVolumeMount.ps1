# process commandline arguments
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
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$sourceServer,
    [Parameter()][string]$targetServer,
    [Parameter()][string]$hypervisor,
    [Parameter()][ValidateSet('kPhysical','kVMware', 'kHyperV')][string]$environment,
    [Parameter()][int64]$id,
    [Parameter()][int64]$runId,
    [Parameter()][datetime]$date,
    [Parameter()][switch]$wait,
    [Parameter()][switch]$showVersions,
    [Parameter()][switch]$showVolumes,
    [Parameter()][array]$volumes,
    [Parameter()][switch]$useExistingAgent,
    [Parameter()][string]$vmUsername,
    [Parameter()][string]$vmPassword
)


function getObjectId($objectName){
    $global:_object_id = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $global:_object_id = $obj.protectionSource.id
            break
        }
        if($obj.name -eq $objectName){
            $global:_object_id = $obj.id
            break
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object_id){
                    get_nodes $node
                }
            }
        }
    }
    
    foreach($source in $sources){
        if($null -eq $global:_object_id){
            get_nodes $source
        }
    }
    return $global:_object_id
}


$existingAgent = $False
if($useExistingAgent){
    $existingAgent = $True
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

# search for source object
$search = api get -v2 "data-protect/search/protected-objects?snapshotActions=InstantVolumeMount&searchString=$sourceServer&environments=kVMware,kPhysical,kHyperV"
$search.objects = $search.objects | Where-Object name -eq $sourceServer
if($environment){
    $search.objects = $search.objects | Where-Object environment -eq $environment
}else{
    $environment = $search.objects[0].environment
}
if($id){
    $search.objects = $search.objects | Where-Object id -eq $id
}
if($search.objects.Count -eq 0){
    Write-Host "$sourceServer not found" -ForegroundColor Yellow
    exit
}elseif($search.objects.Count -gt 1){
    Write-Host "multiple objects found, use the -environement or -id parameters to narrow the results" -ForegroundColor Yellow
    $search.objects | Format-Table -Property id, name, environment
    exit
}else{
    $objectId = $search.objects[0].id
    $targetSourceId = $search.objects[0].sourceInfo.id
}

# get list of available snapshots
$snapshots = api get -v2 "data-protect/objects/$objectId/snapshots?protectionGroupIds=$($search.objects[0].latestSnapshotsInfo.protectionGroupId -join ',')"
if($runId){
    $snapshots.snapshots = $snapshots.snapshots | Where-Object runInstanceId -eq $runId
}
if($date){
    $dateUsecs = (dateToUsecs $date) + 60000000
    $snapshots.snapshots = $snapshots.snapshots | Where-Object runStartTimeUsecs -le $dateUsecs
}
if($snapshots.snapshots.Count -eq 0){
    Write-Host "no snapshots available" -ForegroundColor Yellow
    exit
}
if($showVersions){
    $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending | Format-Table -Property @{l='RunId'; e={$_.runInstanceId}}, @{l='Date'; e={usecsToDate $_.runStartTimeUsecs -format 'yyyy-MM-dd hh:mm:ss'}}
    exit
}
$snapshot = ($snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending)[0]

# volumes
if($showVolumes -or $volumes.Count -gt 0){
    $snapVolumes = api get -v2 "data-protect/snapshots/$($snapshot.id)/volume?includeSupportedOnly=false"
    if($volumes.Count -gt 0){
        $missingVolumes = $volumes | Where-Object {$_ -notin $snapVolumes.volumes.name}
        if($missingVolumes){
            Write-Host "volumes $($missingVolumes -join ', ') not found" -ForegroundColor Yellow
            exit
        }
        $snapVolumes.volumes = $snapVolumes.volumes | Where-Object name -in $volumes
    }
    if($showVolumes){
        $snapVolumes.volumes | Format-Table
        exit
    }
}

# recovery parameters
$targetName = $sourceServer
if($targetServer){
    $targetName = "$($sourceServer)_to_$($targetServer)"
}

$recoveryParams = @{
    "name" = "Recover_$($targetName)_$(Get-Date -UFormat '%Y-%m-%d_%H:%M:%S')";
    "snapshotEnvironment" = $environment;
}

# vmware params
if($environment -eq 'kVMware'){
    $recoveryParams["vmwareParams"] = @{
        "objects" = @(
            @{
                "snapshotId" = $snapshot.id
            }
        );
        "recoveryAction" = "InstantVolumeMount";
        "mountVolumeParams" = @{
            "targetEnvironment" = $environment;
            "vmwareTargetParams" = @{
                "mountToOriginalTarget" = $True;
                "originalTargetConfig" = @{
                    "bringDisksOnline" = $True;
                    "useExistingAgent" = $existingAgent;
                    "targetVmCredentials" = $null
                };
                "newTargetConfig" = $null;
                "readOnlyMount" = $false;
                "volumeNames" = $null
            }
        }
    }
    $targetParams = $recoveryParams.vmwareParams.mountVolumeParams.vmwareTargetParams
    $targetConfig = $targetParams.originalTargetConfig

    # alternate target params
    if($targetServer -and $targetServer -ne $sourceServer){

        # find vCenter
        if($hypervisor){
            $rootNodes = api get protectionSources/rootNodes?environments=kVMware | Where-Object {$_.protectionSource.name -eq $hypervisor}
            if(! $rootNodes){
                Write-Host "VMware source $hypervisor not found" -ForegroundColor Yellow
                exit
            }else{
                $targetSourceId = $rootNodes[0].protectionSource.id
            }
        }

        # find VM
        $vms = api get protectionSources/virtualMachines?vCenterId=$targetSourceId
        $vm = $vms | Where-Object name -eq $targetServer
        if(! $vm){
            Write-Host "VM target $targetServer not found" -ForegroundColor Yellow
            exit
        }

        $targetParams.mountToOriginalTarget = $false
        $targetParams.originalTargetConfig = $null
        $targetParams.newTargetConfig = @{
            "bringDisksOnline" = $True;
            "useExistingAgent" = $existingAgent;
            "targetVmCredentials" = $null;
            "mountTarget" = @{
                "id" = $vm[0].id
            }
        }
        $targetConfig = $targetParams.newTargetConfig
    }

    # vm credentials for autodeploy agent
    if($existingAgent -eq $False){
        if(!$vmUsername){
            Write-Host "-vmUsername required if not using -useExistingAgent" -ForegroundColor Yellow
            exit
        }
        if(!$vmPassword){
            $secureString = Read-Host -Prompt "Enter password for VM user ($vmUsername)" -AsSecureString
            $vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        }
        $targetConfig.targetVmCredentials = @{
            "username" = $vmUsername;
            "password" = $vmPassword
        }
    }
}

# physical params
if($environment -eq 'kPhysical'){
    $recoveryParams["physicalParams"] = @{
        "objects" = @(
            @{
                "snapshotId" = $snapshot.id
            }
        );
        "recoveryAction" = "InstantVolumeMount";
        "mountVolumeParams" = @{
            "targetEnvironment" = $environment;
            "physicalTargetParams" = @{
                "mountToOriginalTarget" = $True;
                "originalTargetConfig" = @{
                    "serverCredentials" = $null
                };
                "newTargetConfig" = $null;
                "readOnlyMount" = $false;
                "volumeNames" = $null
            }
        }
    }
    $targetParams = $recoveryParams.physicalParams.mountVolumeParams.physicalTargetParams
    $targetConfig = $targetParams.originalTargetConfig

    # alternate target params
    if($targetServer -and $targetServer -ne $sourceServer){
        $rootNodes = (api get protectionSources?environments=kPhysical).nodes | Where-Object {$_.protectionSource.name -eq $targetServer}
        if(! $rootNodes){
            Write-Host "physical target $targetServer not found" -ForegroundColor Yellow
            exit
        }else{
            $targetId = $rootNodes[0].protectionSource.id
        }
        $targetParams.mountToOriginalTarget = $false
        $targetParams.originalTargetConfig = $null
        $targetParams.newTargetConfig = @{
            "serverCredentials" = $null;
            "mountTarget" = @{
                "id" = $targetId
            }
        }
    }
}

# hyperV params
if($environment -eq 'kHyperV'){
    $recoveryParams["hypervParams"] = @{
        "objects" = @(
            @{
                "snapshotId" = $snapshot.id
            }
        );
        "recoveryAction" = "InstantVolumeMount";
        "mountVolumeParams" = @{
            "targetEnvironment" = $environment;
            "hypervTargetParams" = @{
                "mountToOriginalTarget" = $True;
                "originalTargetConfig" = @{
                    "bringDisksOnline" = $True;
                    "targetVmCredentials" = $null
                };
                "newTargetConfig" = $null;
                "readOnlyMount" = $false;
                "volumeNames" = $null
            }
        }
    }
    $targetParams = $recoveryParams.hypervParams.mountVolumeParams.hypervTargetParams
    $targetConfig = $targetParams.originalTargetConfig

    # alternate target params
    if($targetServer -and $targetServer -ne $sourceServer){

        # find vCenter
        if($hypervisor){
            $rootNodes = api get protectionSources/rootNodes?environments=kHyperV | Where-Object {$_.protectionSource.name -eq $hypervisor}
            if(! $rootNodes){
                Write-Host "HyperV source $hypervisor not found" -ForegroundColor Yellow
                exit
            }else{
                $targetSourceId = $rootNodes[0].protectionSource.id
            }
        }

        # find VM
        $sources = api get "protectionSources?id=$targetSourceId"
        $thisVMId = getObjectId $targetServer
        if(! $thisVMId){
            Write-Host "VM target $targetServer not found" -ForegroundColor Yellow
            exit
        }

        $targetParams.mountToOriginalTarget = $false
        $targetParams.originalTargetConfig = $null
        $targetParams.newTargetConfig = @{
            "bringDisksOnline" = $True;
            "targetVmCredentials" = $null;
            "mountTarget" = @{
                "id" = $thisVMId
            }
        }
        $targetConfig = $targetParams.newTargetConfig
    }

    # vm credentials for autodeploy agent
    if(!$vmUsername){
        Write-Host "-vmUsername required for HyperV VMs" -ForegroundColor Yellow
        exit
    }
    if(!$vmPassword){
        $secureString = Read-Host -Prompt "Enter password for VM user ($vmUsername)" -AsSecureString
        $vmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    $targetConfig.targetVmCredentials = @{
        "username" = $vmUsername;
        "password" = $vmPassword
    }
}

# specify volumes to mount
if($volumes.Count -gt 0){
    $targetParams.volumeNames = @($snapVolumes.volumes.name)
}

Write-Host "Performing instant volume mount..."
$recovery = api post -v2 "data-protect/recoveries" $recoveryParams

# wait
if($recovery.PSObject.Properties['id']){
    $v1TaskId = ($recovery.id -split ':')[2]
    Write-Host "Task ID for tearDown is: $v1TaskId" 
    if($wait){
        $finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning')
        while($recovery.status -notin $finishedStates){
            Start-Sleep 10
            $recovery = api get -v2 "data-protect/recoveries/$($recovery.id)"
        }
        Write-Host "Mount operation ended with status: $($recovery.status)"
        if($recovery.status -ne 'Succeeded'){
            exit 1
        }
        if($environment -eq 'kVMware'){
            $mounts = $recovery.vmwareParams.mountVolumeParams.vmwareTargetParams.mountedVolumeMapping
        }elseif($environment -eq 'kPhysical'){
            $mounts = $recovery.physicalParams.mountVolumeParams.physicalTargetParams.mountedVolumeMapping
        }else{
            $mounts = $recovery.hypervParams.mountVolumeParams.hypervTargetParams.mountedVolumeMapping
        }
        foreach($mount in $mounts){
            Write-Host "$($mount.originalVolume) mounted to $($mount.mountedVolume)"
        }
    }
}
exit 0
