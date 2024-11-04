# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,  # DMaaS region
    [Parameter(Mandatory = $True)][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered AWS source
    [Parameter()][array]$vmNames,  # optional names of VMs protect
    [Parameter()][string]$vmList = '',  # optional textfile of VMs to protect
    [Parameter()][array]$tagNames, # optional names of tags to protect
    [Parameter()][ValidateSet('All', 'CohesitySnapshot', 'AWSSnapshot')][string]$protectionType = 'CohesitySnapshot',
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes,
    [Parameter()][switch]$bootDiskOnly,
    [Parameter()][array]$excludeDisks
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
    return ($items | Sort-Object -Unique)
}

$vmNamesToAdd = @(gatherList -Param $vmNames -FilePath $vmList -Name 'VMs' -Required $false)
$tagNamesToAdd = @(gatherList -Param $tagNames -Name 'tags' -Required $false)

if($vmNamesToAdd.Count -eq 0 -and $tagNamesToAdd.Count -eq 0){
    Write-Host "No VMs or tags specified" -ForegroundColor Yellow
    exit
}

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
}

function getObject($objectName, $source){
    $global:_object = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $global:_object = $obj
            break
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $global:_object){
                    get_nodes $node
                }
            }
        }
    }
    get_nodes $source
    return $global:_object
}

function getObjectsByTag($tagName, $source){
    $global:_objects = @()

    function get_nodes($obj){
        if($obj.protectionSource.awsProtectionSource.type -eq 'kEC2Instance' -and $tagName -cin $obj.protectionSource.awsProtectionSource.tagAttributes.name){
            $global:_objects = @($global:_objects + $obj)
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                get_nodes $node
            }
        }
    }
    get_nodes $source
    return $global:_objects
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

Write-Host "Connecting to DMaaS"

# authenticate
apiauth -username $username -regionid $region

Write-Host "Finding protection policy"

$policy = (api get -mcmv2 data-protect/policies?types=DMaaSPolicy).policies | Where-Object name -eq $policyName
if(!$policy){
    write-host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}

Write-host "Finding registered AWS source"
# find AWS source
$source = (api get protectionSources?environments=kAWS) | Where-Object {$_.protectionSource.name -eq $sourceName}
if(!$source){
    Write-Host "AWS Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$vmsToAdd = @()

if($tagNamesToAdd.Count -gt 0){
    foreach($tagName in $tagNamesToAdd){
        Write-Host "Enumerating Tag: $tagName"
        $taggedVMs = getObjectsByTag $tagName $source
        if($taggedVMs){
            $vmsToAdd = @($vmsToAdd + $taggedVMs)
        }else{
            Write-Host "No VMs with Tag $tagName found" -ForegroundColor Yellow
        }
    }
}

if($vmNamesToAdd.Count -gt 0){
    foreach($vmName in $vmNamesToAdd){
        Write-Host "Finding VM $vmName"
        $vm = getObject $vmName $source
        if($vm){
            $vmsToAdd = @($vmsToAdd + $vm)
        }else{
            Write-Host "VM $vmName not found" -ForegroundColor Yellow
        }
    }
}

if($vmsToAdd.Count -eq 0){
    Write-Host "No VMs found" -ForegroundColor Yellow
    exit
}

# configure protection parameters
$protectionParams = @{
    "policyConfig" = @{
        "policies" = @()
    };
    "startTime"        = @{
        "hour"     = [int64]$hour;
        "minute"   = [int64]$minute;
        "timeZone" = $timeZone
    };
    "priority" = "kMedium";
    "sla"              = @(
        @{
            "backupRunType" = "kFull";
            "slaMinutes"    = $fullSlaMinutes
        };
        @{
            "backupRunType" = "kIncremental";
            "slaMinutes"    = $incrementalSlaMinutes
        }
    );
    "qosPolicy" = "kBackupSSD";
    "abortInBlackouts" = $false;
    "objects" = @(
        @{
            "environment" = "kAWS";
            "awsParams" = @{
                "protectionType" = "kSnapshotManager";
                "snapshotManagerProtectionTypeParams" = @{
                    "createAmi" = $false;
                    "objects" = @();
                    "excludeVmTagIds" = @();
                    "indexingPolicy" = @{
                        "enableIndexing" = $false;
                        "includePaths" = @();
                        "excludePaths" = @()
                    };
                    "cloudMigration" = $false
                };
                "nativeProtectionTypeParams" = @{
                    "createAmi" = $false;
                    "objects" = @();
                    "excludeVmTagIds" = @();
                    "indexingPolicy" = @{
                        "enableIndexing" = $false;
                        "includePaths" = @();
                        "excludePaths" = @()
                    };
                    "cloudMigration" = $false
                }
            }
        }
    )
}

if($protectionType -eq 'All' -or $protectionType -eq 'CohesitySnapshot'){
    $protectionParams.policyConfig.policies = @($protectionParams.policyConfig.policies + @{
        "id" = $policy.id;
        "protectionType" = "kNative"
    })
}

if($protectionType -eq 'All' -or $protectionType -eq 'AWSSnapshot'){
    $protectionParams.policyConfig.policies = @($protectionParams.policyConfig.policies + @{
        "id" = $policy.id;
        "protectionType" = "kSnapshotManager"
    })
}

# find VMs
foreach($vm in $vmsToAdd){

    $volumeExclusionParams = $null
    $excludedVolumeIds = @()
    if($bootDiskOnly -or $excludeDisks.Count -gt 0){
        foreach($volume in $vm.protectionSource.awsProtectionSource.volumes){
            if($bootDiskOnly -and $volume.isRootDevice -eq $false){
                $excludedVolumeIds = @($excludedVolumeIds + $volume.id)
            }elseif($excludeDisks.Count -gt 0 -and $volume.deviceName -in $excludeDisks){
                $excludedVolumeIds = @($excludedVolumeIds + $volume.id)
            }
        }
    }
    if($excludedVolumeIds.Count -gt 0){
        $volumeExclusionParams = @{
            "volumeIds" = @($excludedVolumeIds)
        }
    }

    $protectionParams.objects.awsParams.snapshotManagerProtectionTypeParams.objects = @(
        @{
            "id" = $vm.protectionSource.id;
            "volumeExclusionParams" = $volumeExclusionParams;
            "excludeObjectIds" = @()
        }
    )
    $protectionParams.objects.awsParams.nativeProtectionTypeParams.objects = @(
        @{
            "id" = $vm.protectionSource.id;
            "volumeExclusionParams" = $volumeExclusionParams;
            "excludeObjectIds" = @()
        }
    )
    Write-Host "Protecting $($vm.protectionSource.name)"
    $response = api post -v2 data-protect/protected-objects $protectionParams
}
