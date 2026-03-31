# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][string]$policyName = '',  # protection policy name
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter()][string]$csvFile,
    [Parameter()][string]$startTime = '20:00',  # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 1440,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 1440,  # full SLA minutes
    [Parameter()][switch]$useMBS,
    [Parameter()][switch]$dbg,
    [Parameter()][int]$autoprotectCount = 0,
    [Parameter()][switch]$pause,
    [Parameter()][switch]$resume
)

$objectsToAdd = @()
if($csvFile){
    $objectsToAdd = Import-Csv -Path $csvFile # -Encoding utf8
}
if($objectsToAdd.Count -eq 0 -and $autoprotectCount -eq 0){
    Write-Host "No OneDrives specified" -ForegroundColor Yellow
    exit
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

if($dbg){
    enableCohesityAPIDebugger
}

# authenticate
apiauth -username $username

if(! $useMBS -and ! $pause -and ! $resume){
    if($policyName -eq ''){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit
    }
    Write-Host "Finding Policy"
    $policy = (api get -mcmv2 "data-protect/policies?types=DMaaSPolicy&regionIds=$region").policies | Where-Object name -eq $policyName
    if(!$policy){
        write-host "Policy $policyName not found" -ForegroundColor Yellow
        exit
    }
}

# find O365 source
Write-Host "Finding M365 Protection Source"
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365&excludeProtectionStats=true&regionIds=$region").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$script:nameIndex = @{}
$script:smtpIndex = @{}
$script:idIndex = @{}
$script:unprotectedIndex = @()
$script:protectedCount = 0

function indexObject($obj){
    foreach($objectProtectionInfo in $obj.objectProtectionInfos | Where-Object {$_.regionId -eq $region -and $_.sourceId -eq $rootSourceId}){
        $script:nameIndex[$obj.name] = $objectProtectionInfo.objectId
        $script:idIndex["$($objectProtectionInfo.objectId)"] = $obj.name
        $script:smtpIndex[$obj.o365Params.primarySMTPAddress] = $objectProtectionInfo.objectId
        if($objectProtectionInfo.objectBackupConfiguration -and $objectProtectionInfo.objectBackupConfiguration -ne $null){
            $script:protectedCount += 1
        }else{
            $script:unprotectedIndex = @($script:unprotectedIndex + $objectProtectionInfo.objectId)
        }
    }
}

if(!$csvFile -and $autoprotectCount -gt 0){
    Write-Host "Finding OneDrives to autoprotect"
    $foundObjects = 0
    $searchCount = $autoprotectCount
    if($searchCount -gt 500){
        $searchCount = 500
    }
    while($foundObjects -lt $autoprotectCount){
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kO365OneDrive&regionIds=$region&sourceIds=$rootSourceId&count=$searchCount&isProtected=false&searchString=*"
        foreach($obj in $search.objects){
            $foundObjects += 1
            $objectsToAdd = @($objectsToAdd + @{'name' = $obj.name; 'smtpAddress' = $obj.o365Params.primarySMTPAddress})
            indexObject($obj)
        }
        if(@($search.objects).Count -lt $searchCount){
            break
        }
    }   
    if($foundObjects -lt $autoprotectCount){
        Write-Host "*** $foundObjects OneDrives to autoprotect"
    }
}

foreach($obj in $objectsToAdd){
    $objName = $obj.name
    $objSMTP = $obj.smtpAddress
    $objId = $null
    if($script:smtpIndex.ContainsKey($objSMTP)){
        $objId = $script:smtpIndex[$objSMTP]
    }else{
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kO365OneDrive&regionIds=$region&sourceIds=$rootSourceId&count=999&searchString=$objName"
        $search.objects = $search.objects | Where-Object {$_.o365Params.primarySMTPAddress -eq $objSMTP}
        foreach($obj in $search.objects){
            indexObject($obj)
        }
        if(@($search.objects).Count -lt 1 -or $search.objects -eq $null){
            Write-Host "OneDrive $objName not found" -ForegroundColor Yellow
            continue
        }else{
            $objId = $script:smtpIndex[$objSMTP]
        }
    }
    if($objId -and $objId -in $script:unprotectedIndex){
        $protectionParams = @{
            "policyId"         = "";
            "startTime"        = @{
                "hour"     = [int64]$hour;
                "minute"   = [int64]$minute;
                "timeZone" = $timeZone
            };
            "priority"         = "kMedium";
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
            "qosPolicy"        = "kBackupSSD";
            "abortInBlackouts" = $false;
            "objects"          = @(
                @{
                    "environment" = "kO365OneDrive";
                    "office365Params" = @{
                        "objectProtectionType"              = "kOneDrive";
                        "userOneDriveObjectProtectionParams" = @{
                            "objects"        = @(
                                @{
                                    "id" = $objId
                                }
                            );
                            "indexingPolicy" = @{
                                "enableIndexing" = $true;
                                "includePaths"   = @(
                                    "/"
                                );
                                "excludePaths"   = @()
                            }
                        }
                    }
                }
            )
        }
        if($useMBS){
            $protectionParams.objects[0].environment = "kO365OneDriveCSM"
        }else{
            $protectionParams.policyId = $policy.id
        }
        Write-Host "Protecting $objSMTP"
        $null = api post -v2 "data-protect/protected-objects?regionIds=$region" $protectionParams
    }elseif($objId -and $objId -notin $script:unprotectedIndex){
        if($pause){
            $action = @{
                "action" = "Pause";
                "objectActionKey" = "kO365OneDrive";
                "pauseParams" = @{
                    "objects" = @(
                        @{
                            "id" = $objId
                        }
                    )
                }
            }
            Write-Host "Pausing $objSMTP"
            $null = api post -v2 "data-protect/protected-objects/actions?regionIds=$region" $action
        }elseif($resume){
            $action = @{
                "action" = "Resume";
                "objectActionKey" = "kO365OneDrive";
                "resumeParams" = @{
                    "objects" = @(
                        @{
                            "id" = $objId
                        }
                    )
                }
            }
            Write-Host "Resuming $objSMTP"
            $null = api post -v2 "data-protect/protected-objects/actions?regionIds=$region" $action
        }else{
            Write-Host "OneDrive $objSMTP already protected" -ForegroundColor Magenta
        }
        
    }else{
        Write-Host "OneDrive $objSMTP not found" -ForegroundColor Yellow
    }
}
