# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$sourceName,
    [Parameter()][string]$sourceList,
    [Parameter()][dateTime]$startTime,
    [Parameter()][dateTime]$endTime,
    [Parameter()][switch]$startNow,
    [Parameter()][switch]$endNow
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

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

$sourceNames = @(gatherList -Param $sourceName -FilePath $sourceList -Name 'sources' -Required $True)

$startMaintenance = $False
$endMaintenance = $False

if($startNow){
    $startMaintenance = $True
}
$startTimeUsecs = dateToUsecs
if($startTime){
    $startMaintenance = $True
    $startTimeUsecs = dateToUsecs $startTime
}
$endTimeUsecs = -1
if($endTime){
    $startMaintenance = $True
    $endTimeUsecs = dateToUsecs $endTime
}
if($endNow){
    $endMaintenance = $True
}

if(! $endMaintenance -and ! $startMaintenance){
    Write-Host "No action specified" -ForegroundColor Yellow
    exit
}

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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

function updateMeta($thisObjName, $thisObjId){
    $metaUpdate = $False
    if($startMaintenance -eq $True){
        Write-Host "Scheduling maintenance on $thisObjName"
        $maintenanceParams = @{
            "sourceId" = $thisObjId;
            "entityList" = @(
                @{
                    "entityId" = $thisObjId;
                    "maintenanceModeConfig" = @{
                        "userMessage" = "test";
                        "workflowInterventionSpecList" = @(
                            @{
                                "workflowType" = "BackupRun";
                                "intervention" = "Cancel"
                            }
                        );
                        "activationTimeIntervals" = @(
                            @{
                                "startTimeUsecs" = $startTimeUsecs;
                                "endTimeUsecs" = $endTimeUsecs
                            }
                        )
                    }
                }
            )
        }
        $metaUpdate = $True
    }elseif($endMaintenance -eq $True){
        Write-Host "Ending maintenance on $thisObjName"
        $maintenanceParams = @{
            "sourceId" = $thisObjId;
            "entityList" = @(
                @{
                    "entityId" = $thisObjId;
                    "maintenanceModeConfig" = @{}
                }
            )
        }
        $metaUpdate = $True
    }
    if($metaUpdate -eq $True){
        $null = api put -v2 data-protect/objects/metadata $maintenanceParams
    }
}

$sources = api get "protectionSources/registrationInfo?useCachedData=false&includeExternalMetadata=true&includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false"

foreach($sourceName in $sourceNames){
    $thisSourceName, $thisObjectName = $sourceName -split '/',2
    
    $source = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $thisSourceName}
    if(!$source){
        Write-Host "Source $sourceName not found" -ForegroundColor Yellow
        exit 1
    }else{
        foreach($thisSource in $source){
            if($thisObjectName -and 'kSQL' -notin @($thisSource.registrationInfo.environments)){
                Write-Host "Object-level maintenance only supported for MSSQL sources" -ForegroundColor Yellow
                Write-Host "Skipping $sourceName" -ForegroundColor Yellow
                continue
            }
            if($thisObjectName -and 'kSQL' -in @($thisSource.registrationInfo.environments)){
                $foundObject = $false
                $thisSourceObj = api get protectionSources?id=$($thisSource.rootNode.id)
                foreach($instance in @($thisSourceObj.applicationNodes + $thisSourceObj.nodes)){
                    if($instance.protectionSource.name -eq $thisObjectName){
                        updateMeta $sourceName $instance.protectionSource.id
                        $foundObject = $True
                    }else{
                        foreach($db in $instance.nodes){
                            if($db.protectionSource.name -eq $thisObjectName){
                                updateMeta $sourceName $db.protectionSource.id
                                $foundObject = $True
                            }
                        }
                    }
                }
                if($foundObject -eq $False){
                    Write-Host "$sourceName not found" -ForegroundColor Yellow
                }
            }else{
                updateMeta $sourceName $thisSource.rootNode.id
            }
        }
    }
}
