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
    [Parameter()][array]$excludeFolders,
    [Parameter()][int]$autoprotectCount = 0
)

$objectsToAdd = @()
if($csvFile){
    $objectsToAdd = Import-Csv -Path $csvFile # -Encoding utf8
}
if($objectsToAdd.Count -eq 0 -and $autoprotectCount -eq 0){
    Write-Host "No mailboxes specified" -ForegroundColor Yellow
    exit
}

$foldersToExclude = @()
foreach($excludeFolder in $excludeFolders){
    $foldersToExclude = @($foldersToExclude + $excludeFolder)
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

if(! $useMBS){
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
    Write-Host "Finding mailboxes to autoprotect"
    $foundObjects = 0
    $searchCount = $autoprotectCount
    if($searchCount -gt 500){
        $searchCount = 500
    }
    while($foundObjects -lt $autoprotectCount){
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kO365Exchange&regionIds=$region&sourceIds=$rootSourceId&count=$searchCount&isProtected=false&searchString=*"
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
        Write-Host "*** $foundObjects mailboxes to autoprotect"
    }
}

foreach($obj in $objectsToAdd){
    $objName = $obj.name
    $objSMTP = $obj.smtpAddress
    $objId = $null
    if($script:smtpIndex.ContainsKey($objSMTP)){
        $objId = $script:smtpIndex[$objSMTP]
    }else{
        $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kO365Exchange&regionIds=$region&sourceIds=$rootSourceId&count=999&searchString=$objName"
        $search.objects = $search.objects | Where-Object {$_.o365Params.primarySMTPAddress -eq $objSMTP}
        foreach($obj in $search.objects){
            indexObject($obj)
        }
        if(@($search.objects).Count -lt 1 -or $search.objects -eq $null){
            Write-Host "Mailbox $objName not found" -ForegroundColor Yellow
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
                    "environment" = "kO365Exchange";
                    "office365Params" = @{
                        "objectProtectionType"              = "kMailbox";
                        "userMailboxObjectProtectionParams" = @{
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
                            };
                            "excludeFolders" = $foldersToExclude
                        }
                    }
                }
            )
        }
        if($useMBS){
            $protectionParams.objects[0].environment = "kO365ExchangeCSM"
        }else{
            $protectionParams.policyId = $policy.id
        }
        Write-Host "Protecting $objSMTP"
        Start-Sleep 0.1
        $null = api post -v2 "data-protect/protected-objects?regionIds=$region" $protectionParams
    }elseif($objId -and $objId -notin $script:unprotectedIndex){
        Write-Host "Mailbox $objSMTP already protected" -ForegroundColor Magenta
    }else{
        Write-Host "Mailbox $objSMTP not found" -ForegroundColor Yellow
    }
}
