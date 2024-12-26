# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$region,  # CCS region
    [Parameter(Mandatory = $True)][string]$policyName,  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered AWS source
    [Parameter()][array]$vmNames,  # optional names of VMs protect
    [Parameter()][string]$vmList = '',  # optional textfile of VMs to protect
    [Parameter()][array]$excludeVmNames,  # optional names of VMs protect
    [Parameter()][string]$excludeVmList = '',  # optional textfile of VMs to protect
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes,
    [Parameter()][switch]$autoProtectSource,
    [Parameter()][switch]$pause
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

function getObject($objectName, $source){
    $script:_object = $null

    function get_nodes($obj){
        if($obj.protectionSource.name -eq $objectName){
            $script:_object = $obj
            break
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                if($null -eq $script:_object){
                    get_nodes $node
                }
            }
        }
    }
    get_nodes $source
    return $script:_object
}

function getSaaSConnctors($source){
    $script:_saasConnectors = @()
    function get_snodes($obj){
        if($obj.protectionSource.vmWareProtectionSource.PSObject.Properties['isSaasConnector'] -and $obj.protectionSource.vmWareProtectionSource.isSaasConnector -eq $True){
            if($obj.protectionSource.id -notin $script:_saasConnectors){
                $script:_saasConnectors = @($script:_saasConnectors + $obj.protectionSource.id)
                Write-Host "Skipping $($obj.protectionSource.name) (SaaS Connector)" -ForegroundColor Yellow
            }
        }
        if($obj.PSObject.Properties['nodes']){
            foreach($node in $obj.nodes){
                get_snodes $node
            }
        }
    }
    get_snodes $source
    return $script:_saasConnectors
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
$source = api get "protectionSources?id=$sourceId&environments=kVMware"

if(!$source){
    Write-Host "VMware source $sourceName not found" -ForegroundColor Yellow
    exit
}

$vmsToAdd = @()
$vmsToExclude = @()
if($autoProtectSource){
    $vmsToAdd = @($vmsToAdd + $sourceId)
    $vmsToExclude = @($vmsToExclude + (getSaaSConnctors $source))
}else{
    if($vmNamesToAdd.Count -gt 0){
        foreach($vmName in $vmNamesToAdd){
            $vm = getObject $vmName $source
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
        $vm = getObject $vmName $source
        if($vm){
            $vmsToExclude = @($vmsToExclude + $vm.protectionSource.id)
        }
    }
}


if($vmsToAdd.Count -eq 0){
    Write-Host "No VMs found" -ForegroundColor Yellow
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
        if($vm.protectionSource.vmWareProtectionSource.PSObject.Properties['isSaasConnector'] -and $vm.protectionSource.vmWareProtectionSource.isSaasConnector -eq $True){
            Write-Host "Skipping $($vm.protectionSource.name) (SaaS Connector)" -ForegroundColor Yellow
        }else{
            Write-Host "Protecting $($vm.protectionSource.name)"
        }
        $protectionParams.objects[0].vmwareParams.objects = @($protectionParams.objects[0].vmwareParams.objects + @{
            "id" = $vm.protectionSource.id;
            "isAutoprotected" = $false
        })
    }
}

$response = api post -v2 data-protect/protected-objects $protectionParams
