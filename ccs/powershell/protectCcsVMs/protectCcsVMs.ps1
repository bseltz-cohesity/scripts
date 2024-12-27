# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][array]$vmNames,
    [Parameter()][string]$vmList = '',
    [Parameter()][array]$excludeVmNames,
    [Parameter()][string]$excludeVmList = '',
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][switch]$autoProtectSource,
    [Parameter()][switch]$listEntities,
    [Parameter()][switch]$pause,
    [Parameter()][switch]$dbg
)

$isPaused = $false
if($pause){
    $isPaused = $True
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
    return ($items | Sort-Object -Unique)
}

$vmNamesToAdd = @(gatherList -Param $vmNames -FilePath $vmList -Name 'Include VMs' -Required $false)
$vmNamesToExclude = @(gatherList -Param $excludeVmNames -FilePath $excludeVmList -Name 'Exclude VMs' -Required $false)

if($vmNamesToAdd.Count -eq 0 -and ! $autoProtectSource){
    Write-Host "No VMs specified" -ForegroundColor Yellow
    exit
}

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
}

# index the vCenter hierarchy
$script:vmHierarchy = @{}

function indexSource($sourceName, $source, $parents = @(), $parent = ''){
    if($sourceName -notin $script:vmHierarchy.keys){
        $script:vmHierarchy[$sourceName] = @()
    }
    if($source.protectionSource.vmWareProtectionSource.PSObject.Properties['tagAttributes']){
        $parents = @($parents + $source.protectionSource.vmWareProtectionSource.tagAttributes.id)
    }
    $thisNode = @{'id' = $source.protectionSource.id; 
                    'name' = $source.protectionSource.name; 
                    'type' = $source.protectionSource.vmWareProtectionSource.type;
                    'isSaasConnector' = $false
                    'tags' = @()
                    'parents' = $parents;
                    'canonical' = ("$parent/$($source.protectionSource.name)" -replace '/Datacenters/','/' -replace '/root/ha-datacenter/','/' -replace '/vm/','/' -replace '/host/','/' -replace "$sourceName/",'/' -replace '/Resources/','/' -replace '//', '/' -replace '^//','' -replace '^/','' -replace '^VMs/','')}
    if($source.protectionSource.vmWareProtectionSource.PSObject.Properties['isSaasConnector'] -and $source.protectionSource.vmWareProtectionSource.isSaasConnector -eq $True){
        $thisNode.isSaasConnector = $True
    }
    if($source.protectionSource.vmWareProtectionSource.PSObject.Properties['tagAttributes']){
        $thisNode.tags = @($source.protectionSource.vmWareProtectionSource.tagAttributes.id)
    }
    $script:vmHierarchy[$sourceName] = @($script:vmHierarchy[$sourceName] + $thisNode) 
    $thisNode.parents = @($thisNode.parents + $parents | Sort-Object -Unique)
    if($source.PSObject.Properties['nodes']){
        $parents = @($thisNode.parents + $source.protectionSource.id | Sort-Object -Unique)
        foreach($node in $source.nodes){
            indexSource $sourceName $node $parents "$parent/$($source.protectionSource.name)"
        }
    }
}

function getObject($objectName){
    $thisObject = $script:vmHierarchy[$sourceName] | Where-Object {$_.name -eq $objectName -or $_.canonical -eq $objectName}
    if(! $thisObject){
        Write-Host "$objectName not found" -ForegroundColor Yellow
        return $null
    }
    $thisObject = $thisObject | ConvertTo-Json -Depth 99 | ConvertFrom-Json
    if('kComputeResource' -in $thisObject.type){
        $thisObject = $thisObject | Where-Object {$_.type -eq 'kComputeResource'}
    }
    $thisObjectIds = $thisObject.id | Sort-Object -Unique
    if($thisObjectIds.Count -gt 1){
        Write-Host "Multiple matches for $objectName (use canonical name to specify)" -ForegroundColor Yellow
        foreach($obj in $thisObject){
            Write-Host "  $($obj.canonical) ($($obj.type))"
        }
        exit
    }else{
        if($thisObject.Count -gt 1){
            return $thisObject[0]
        }else{
            return $thisObject
        }        
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to CCS ===========================================
Write-Host "Connecting to Cohesity Cloud..."
apiauth -username $username -passwd $password -regionid $region
# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# ===============================================================

Write-Host "Finding protection policy"

$policy = (api get -mcmv2 data-protect/policies?types=DMaaSPolicy).policies | Where-Object name -eq $policyName
if(!$policy){
    write-host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}

# find VMware source
Write-host "Finding registered VMware source"
$sources = api get -mcmv2 "data-protect/sources?environments=kVMware"
$source = $sources.sources | Where-Object {$_.name -eq $sourceName}
if(! $source){
    Write-Host "VMware source $sourceName not found" -ForegroundColor Yellow
    exit
}
if($autoProtectSource -and $source.type -ne 'kStandaloneHost'){
    Write-Host "-autoProtectSource is only for sources of type Standalone Host" -ForegroundColor Yellow
    exit
}
$sourceInfo = $source.sourceInfoList | Where-Object {$_.regionId -eq $region}
$sourceId = $sourceInfo.sourceId
$source = api get "protectionSources?id=$sourceId&environments=kVMware&includeVMFolders=true&pruneNonCriticalInfo=true&pruneAggregationInfo=true"

if(!$source){
    Write-Host "VMware source $sourceName not found" -ForegroundColor Yellow
    exit
}

indexSource $sourceName $source
$index = $script:vmHierarchy[$sourceName]

# list entities
if($listEntities){
    foreach ($entity in $index | Sort-Object -Property canonical){
        Write-Host "$($entity.canonical) ($($entity.type))"
    }
    exit
}

# configure protection parameters
$protectionParams = @{
    "policyId" = $policy.id;
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
            "environment" = "kVMware";
            "vmwareParams" = @{
                "objects" = @();
                "vmTagIds" = @();
                "excludeVmTagIds" = @();
                "appConsistentSnapshot" = $false;
                "fallbackToCrashConsistentSnapshot" = $true;
                "skipPhysicalRDMDisks" = $false;
                "globalExcludeDisks" = @()
            }
        }
    );
    "isPaused" = $isPaused;
    "pausedNote" = ""
}

# process VM selections
$vmsToAdd = @()
$vmsToExclude = @()
if($autoProtectSource){
    $vmsToAdd = @($vmsToAdd + $sourceId)
    $saasConnectors = $index | Where-Object {$_.isSaasConnector -eq $True}
    if($saasConnectors){
        $saasConnectorIds = $saasConnectors.id | Sort-Object -Unique
        $vmsToExclude = @($vmsToExclude + $saasConnectorIds)
    } 
}else{
    if($vmNamesToAdd.Count -gt 0){
        foreach($vmName in $vmNamesToAdd){
            $vm = getObject $vmName
            if($vm){
                $vmsToAdd = @($vmsToAdd + $vm)
            }else{
                Write-Host "VM $vmName not found" -ForegroundColor Yellow
            }
        }
    }
}

if($autoProtectSource -and $vmNamesToExclude.Count -gt 0){
    foreach($vmName in $vmNamesToExclude){
        $vm = getObject $vmName
        if($vm){
            $vmsToExclude = @($vmsToExclude + $vm.id)
        }
    }
}

if($vmsToAdd.Count -eq 0){
    Write-Host "No VMs found" -ForegroundColor Yellow
    exit
}

if($autoProtectSource){
    Write-Host "Auto-protecting $sourceName"
    $protectionParams.objects[0].vmwareParams.objects = @(
        @{
            "id" = $sourceId;
            "isAutoprotected" = $false;
        }
    )
    if($vmsToExclude.Count -gt 0){
        $protectionParams.objects[0].vmwareParams.objects[0]['excludeObjectIds'] = @($vmsToExclude | Sort-Object -Unique)
    }
}else{
    foreach($vm in $vmsToAdd){
        if($vm.isSaasConnector -eq $True){
            Write-Host "Skipping $($vm.name) (SaaS Connector)" -ForegroundColor Yellow
        }else{
            Write-Host "Protecting $($vm.name)"
            $newObject = @{
                "id" = $vm.id;
                "isAutoprotected" = $false
            }
            if($vm.type -ne 'kVirtualMachine'){
                if($vm.type -eq 'kTag'){
                    $children = $index | Where-Object {$vm.id -in $_.tags}
                }else{
                    $children = $index | Where-Object {$vm.id -in $_.parents}
                }
                foreach($child in $children){
                    if($child.isSaasConnector -eq $True -or $child.name -in $vmNamesToExclude){
                        if(! $excludesStarted){
                            $newObject['excludeObjectIds'] = @()
                            $excludesStarted = $True
                        }
                        $newObject['excludeObjectIds'] = @($newObject['excludeObjectIds'] + $child.id | Sort-Object -Unique)
                    }
                }
            }
            $protectionParams.objects[0].vmwareParams.objects = @($protectionParams.objects[0].vmwareParams.objects + $newObject)            
        }
    }
}
if($dbg){
    $protectionParams | toJson
    exit
}
$response = api post -v2 data-protect/protected-objects $protectionParams
