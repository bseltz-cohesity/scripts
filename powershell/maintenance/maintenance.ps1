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

$sources = api get "protectionSources/registrationInfo?useCachedData=false&includeExternalMetadata=true&includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false"

foreach($sourceName in $sourceNames){
    $source = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $sourceName}
    if(!$source){
        Write-Host "Source $sourceName not found" -ForegroundColor Yellow
        exit 1
    }else{
        foreach($thisSource in $source){
            $metaUpdate = $False
            if($startMaintenance -eq $True){
                Write-Host "Scheduling maintenance on $($thisSource.rootNode.name)"
                $maintenanceParams = @{
                    "sourceId" = $thisSource.rootNode.id;
                    "entityList" = @(
                        @{
                            "entityId" = $thisSource.rootNode.id;
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
                Write-Host "Ending maintenance on $($thisSource.rootNode.name)"
                $maintenanceParams = @{
                    "sourceId" = $thisSource.rootNode.id;
                    "entityList" = @(
                        @{
                            "entityId" = $thisSource.rootNode.id;
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
    }
}
