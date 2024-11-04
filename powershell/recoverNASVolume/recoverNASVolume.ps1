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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$sourceVolume,
    [Parameter()][string]$sourceName,
    [Parameter()][string]$targetName,
    [Parameter()][string]$targetVolume,
    [Parameter()][switch]$showVersions,
    [Parameter()][int64]$runId,
    [Parameter()][switch]$overwrite,
    [Parameter()][switch]$wait,
    [Parameter()][int64]$sleepTime=30
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

function getMatchingNodes($thisObject, $matchName){
    $matchNodes = @()
    foreach($node in $nodes){
        if($node.protectionSource.name -eq $matchName){
            $matchNodes = @($matchNodes + $node)
        }
    }
    return $matchNodes
}

$performOverwrite = $false
if($overwrite){
    $performOverwrite = $True
}

# find source volume
$search = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverNasVolume,RecoverSanVolumes&searchString=$sourceVolume&environments=kNetapp,kIsilon,kGenericNas,kFlashBlade,kGPFS,kElastifile,kPure" # ,kIbmFlashSystem" # &filterSnapshotToUsecs=1720497599999000&filterSnapshotFromUsecs=1719892800000000
$objects = $search.objects | Where-Object {$_.name -eq $sourceVolume}
if(!$objects){
    Write-Host "NAS volume $sourceVolume not found" -ForegroundColor Yellow
    exit 1
}
if($sourceName){
    $objects = $objects | Where-Object {$_.sourceInfo.name -eq $sourceName}
}
if(!$objects){
    Write-Host "NAS volume $sourceVolume not found on NAS $sourceName" -ForegroundColor Yellow
    exit 1
}

# find snapshots
$allSnapshots = @()
foreach($object in $objects){
    $snapshots = api get -v2 "data-protect/objects/$($object.id)/snapshots?protectionGroupIds=$($object.latestSnapshotsInfo[0].protectionGroupId)"
    if($null -ne $snapshots){
        $allSnapshots = @($allSnapshots + $snapshots.snapshots)
    }
}
if($allSnapshots.Count -eq 0){
    Write-Host "No snapshots found for $sourceVolume"
    exit 1
}

if($showVersions){
    $allSnapshots | Format-Table -Property @{label='runId'; expression={$_.runInstanceId}}, @{label='runDate'; expression={usecsToDate $_.runStartTimeUsecs}}, snapshotTargetType
    exit
}

# select snapshot
$allSnapshotGroups = $allSnapshots | Group-Object -Property runInstanceId
if($runId){
    $thisSnapshotGroup = @($allSnapshotGroups | Where-Object {$_.name -eq $runId})
    if(! $thisSnapshotGroup){
        Write-Host "No snapshots found for $sourceVolume with runId $runId"
        exit 1
    }
}else{
    $thisSnapshotGroup = $allSnapshotGroups[-1]
}
$thisSnapshot = $thisSnapshotGroup.Group[0]

# recovery params
$paramsName = $thisSnapshot.PSObject.Properties.Name -match 'params'
$targetParamsName = "$($thisSnapshot.environment.subString(1,1).toLower())$($thisSnapshot.environment.subString(2))TargetParams"
$restoreTaskName = "Recover_Storage_Volumes_$(get-date -UFormat '%b_%d_%Y_%H-%M%p')"

$recoveryParams = @{
    "name" = $restoreTaskName;
    "snapshotEnvironment" = $thisSnapshot.environment;
    "$paramsName" = @{
        "objects" = @(
            @{
                "snapshotId" = $thisSnapshot.id
            }
        );
        "recoveryAction" = "RecoverNasVolume";
        "recoverNasVolumeParams" = @{
            "targetEnvironment" = $thisSnapshot.environment;
            "$targetParamsName" = @{
                "recoverToNewSource" = $false;
                "originalSourceConfig" = @{
                    "overwriteExistingFile" = $performOverwrite;
                    "preserveFileAttributes" = $true;
                    "continueOnError" = $true;
                    "encryptionEnabled" = $false
                }
            }
        }
    }
}

# find target volume
if($targetVolume){
    $targets = api get "protectionSources/rootNodes?environments=kNetapp,kIsilon,kGenericNas,kFlashBlade,kGPFS,kElastifile,kPure" # ,kIbmFlashSystem"
    if($targetName){
        $targets = $targets | Where-Object {$_.protectionSource.name -eq $targetName}
    }
    $foundVolumes = @()
    foreach($target in $targets){
        $sources = api get "protectionSources?useCachedData=false&id=$($target.protectionSource.id)&allUnderHierarchy=false"
        foreach($source in $sources){
            foreach($node in $source.nodes){
                if($node.PSObject.Properties['nodes']){
                    foreach($sourceNode in $node.nodes){
                        if($sourceNode.protectionSource.name -eq $targetVolume){
                            $foundVolumes = @($foundVolumes + $sourceNode)
                        }
                    }
                }elseif($node.protectionSource.name -eq $targetVolume){
                    $foundVolumes = @($foundVolumes + $node)
                }
            }
        }
    }
    if($foundVolumes.Count -eq 0){
        Write-Host "Target volume $targetVolume not found" -ForegroundColor Yellow
        exit
    }elseif($foundVolumes.Count -gt 1){
        Write-Host "More than one target volume found. Please specify -targetName" -ForegroundColor Yellow
        exit
    }
    $targetParamsName = "$($foundVolumes[0].protectionSource.environment.subString(1,1).toLower())$($foundVolumes[0].protectionSource.environment.subString(2))TargetParams"

    # alternate target recovery params
    $recoveryParams."$paramsName".recoverNasVolumeParams.targetEnvironment = $foundVolumes[0].protectionSource.environment

    if($foundVolumes[0].protectionSource.environment -eq 'kGenericNas'){
        $recoveryParams."$paramsName".recoverNasVolumeParams = @{
            "targetEnvironment" = $foundVolumes[0].protectionSource.environment;
            "$targetParamsName" = @{
                "volume" = @{
                    "id" = $foundVolumes[0].protectionSource.id
                };
                "overwriteExistingFile" = $performOverwrite;
                "preserveFileAttributes" = $true;
                "continueOnError" = $true;
                "encryptionEnabled" = $false
            }
        }
    }else{
        $recoveryParams."$paramsName".recoverNasVolumeParams = @{
            "targetEnvironment" = $foundVolumes[0].protectionSource.environment;
            "$targetParamsName" = @{
                "recoverToNewSource" = $true;
                "newSourceConfig" = @{
                    "volume" = @{
                        "id" = $foundVolumes[0].protectionSource.id
                    };
                    "overwriteExistingFile" = $performOverwrite;
                    "preserveFileAttributes" = $true;
                    "continueOnError" = $true;
                    "encryptionEnabled" = $false
                }
            }
        }
    }
}

Write-Host "Recovering $sourceVolume"
$recovery = api post -v2 data-protect/recoveries $recoveryParams

# wait for restores to complete
$finishedStates = @('Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning')
if(! $recovery.PSObject.Properties['id']){
    exit 1
}

if($wait){
    Write-Host "Waiting for recovery to complete..."
    do{
        Start-Sleep $sleepTime
        $recoveryTask = api get -v2 data-protect/recoveries/$($recovery.id)?includeTenants=true
        $status = $recoveryTask.status

    } until ($status -in $finishedStates)
    write-host "Recovery task finished with status: $status"
    if($status -in @('Failed', 'SucceededWithWarning')){
        if($recoveryTask.PSObject.Properties['messages'] -and $recoveryTask.messages.Count -gt 0){
            Write-Host "$($recoveryTask.messages[0])" -ForegroundColor Yellow
        }
    }
    if($status -eq 'Succeeded'){
        exit 0
    }else{
        exit 1
    }
}
exit 0
