# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter()][array]$sourceNames,
    [Parameter()][string]$sourceList,
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][switch]$pause,
    [Parameter()][switch]$dbg,
    [Parameter()][array]$inclusions,
    [Parameter()][string]$inclusionList,
    [Parameter()][array]$exclusions,
    [Parameter()][string]$exclusionList
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

$sourceNames = @(gatherList -Param $sourceNames -FilePath $sourceList -Name 'Source Names' -Required $True)
$inclusions = @(gatherList -Param $inclusions -FilePath $inclusionList -Name 'Include Paths' -Required $false)
$exclusions = @(gatherList -Param $exclusions -FilePath $exclusionList -Name 'Include Paths' -Required $false)

if(@($inclusions).Count -eq 0){
    $inclusions = @('$ALL_LOCAL_DRIVES')
}

# parse startTime
$hour, $minute = $startTime.split(':')
$tempInt = ''
if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
    Write-Host "Please provide a valid start time" -ForegroundColor Yellow
    exit
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

# get Physical sources
$sources = api get -mcmv2 "data-protect/sources?environments=kPhysical"

# find policy
$policy = (api get -mcmv2 data-protect/policies?types=DMaaSPolicy).policies | Where-Object name -eq $policyName
if(!$policy){
    write-host "Policy $policyName not found" -ForegroundColor Yellow
    exit 1
}

foreach($sourceName in $sourceNames){
    # find source
    $source = $sources.sources | Where-Object {$_.name -eq $sourceName}
    if(! $source){
        Write-Host "Physical source $sourceName not found" -ForegroundColor Yellow
        continue
    }
    $sourceInfo = $source.sourceInfoList | Where-Object {$_.regionId -eq $region}
    $sourceId = $sourceInfo.sourceId

    # see if the source is already protected
    $alreadyProtected = $false
    $object = api get -v2 data-protect/objects?ids=$sourceId
    if($object -and $object.objects[0].PSObject.Properties['objectBackupConfiguration']){
        $alreadyProtected = $True
    }

    # define protection params
    $protectionParams = @{
        "policyId" = $policy.id;
        "startTime" = @{
            "hour" = [int64]$hour;
            "minute" = [int64]$minute;
            "timeZone" = $timeZone
        };
        "priority" = "kMedium";
        "sla" = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes" = $fullSlaMinutes
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes" = $incrementalSlaMinutes
            }
        );
        "qosPolicy" = "kBackupSSD";
        "abortInBlackouts" = $false;
        "objects" = @(
            @{
                "environment" = "kPhysical";
                "physicalParams" = @{
                    "objectProtectionType" = "kFile";
                    "fileObjectProtectionTypeParams" = @{
                        "indexingPolicy" = @{
                            "enableIndexing" = $false;
                            "includePaths" = @();
                            "excludePaths" = @()
                        };
                        "objects" = @(
                            @{
                                "id" = $sourceId;
                                "filePaths" = @();
                                "usesPathLevelSkipNestedVolumeSetting" = $true;
                                "nestedVolumeTypesToSkip" = @();
                                "followNasSymlinkTarget" = $false
                            }
                        );
                        "performSourceSideDeduplication" = $false;
                        "quiesce" = $false;
                        "dedupExclusionSourceIds" = @();
                        "globalExcludePaths" = @();
                        "globalExcludeFS" = @()
                    }
                }
            }
        )
    }

    if($alreadyProtected -eq $True){
        $protectionParams = @{
            "policyId" = $policy.id;
            "startTime" = @{
                "hour" = [int64]$hour;
                "minute" = [int64]$minute;
                "timeZone" = $timeZone
            };
            "priority" = "kMedium";
            "sla" = @(
                @{
                    "backupRunType" = "kFull";
                    "slaMinutes" = $fullSlaMinutes
                };
                @{
                    "backupRunType" = "kIncremental";
                    "slaMinutes" = $incrementalSlaMinutes
                }
            );
            "qosPolicy" = "kBackupSSD";
            "abortInBlackouts" = $false;
            "environment" = "kPhysical";
            "physicalParams" = @{
                "objectProtectionType" = "kFile";
                "fileObjectProtectionTypeParams" = @{
                    "indexingPolicy" = @{
                        "enableIndexing" = $false;
                        "includePaths" = @();
                        "excludePaths" = @()
                    };
                    "objects" = @(
                        @{
                            "id" = $sourceId;
                            "filePaths" = @();
                            "usesPathLevelSkipNestedVolumeSetting" = $true;
                            "nestedVolumeTypesToSkip" = @();
                            "followNasSymlinkTarget" = $false
                        }
                    );
                    "performSourceSideDeduplication" = $false;
                    "quiesce" = $false;
                    "dedupExclusionSourceIds" = @();
                    "globalExcludePaths" = @();
                    "globalExcludeFS" = @()
                }
            }
        }
    }


    # apply path inclusions/exclusions
    foreach($inclusion in $inclusions){
        if($inclusion -ne '$ALL_LOCAL_DRIVES'){
            $inclusion = "/$($inclusion.replace(':','').replace('\','/'))".replace('//','/')
        }
        $thisPath = @{
            "includedPath" = $inclusion;
            "excludedPaths" = @();
            "skipNestedVolumes" = $true
        }
        foreach($exclusion in $exclusions){
            $exclusion = "/$($exclusion.replace(':','').replace('\','/'))".replace('//','/')
            if($exclusion -match $inclusion){
                $thisPath.excludedPaths = @($thisPath.excludedPaths + $exclusion)
            }
        }
        if($alreadyProtected -eq $True){
            $protectionParams.physicalParams.fileObjectProtectionTypeParams.objects[0].filePaths = @($protectionParams.physicalParams.fileObjectProtectionTypeParams.objects[0].filePaths + $thisPath)
        }else{
            $protectionParams.objects[0].physicalParams.fileObjectProtectionTypeParams.objects[0].filePaths = @($protectionParams.objects[0].physicalParams.fileObjectProtectionTypeParams.objects[0].filePaths + $thisPath)
        }  
    }         

    # debug display payload
    if($dbg){
        $protectionParams | toJson
        exit
    }

    # post/put protection params
    if($alreadyProtected -eq $True){
        Write-Host "Updating $sourceName..."
        $response = api put -v2 data-protect/protected-objects/$sourceId $protectionParams
    }else{
        Write-Host "Protecting $sourceName..."
        $response = api post -v2 data-protect/protected-objects $protectionParams
    }
}
