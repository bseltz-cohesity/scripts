# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$sourceName,  # name of registered O365 source
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter()][int]$pageSize = 1000,
    [Parameter()][ValidateSet('mailbox','onedrive')][string]$objectType = 'mailbox',
    [Parameter()][string]$date,
    [Parameter()][switch]$addHold,
    [Parameter()][switch]$removeHold,
    [Parameter()][switch]$showTrue,
    [Parameter()][switch]$showFalse,
    [Parameter()][string]$startDate,
    [Parameter()][string]$endDate,
    [Parameter()][int]$objectsPerQuery = 20
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if(!$startDate){
    $startDate = dateToUsecs $date
}else{
    $startDate = dateToUsecs $startDate
}

if(! $startDate -or $startDate -eq 0){
    Write-Host "Invalid date specified. Should be in format '2025-07-09'" -ForegroundColor Yellow
    exit 1
}
if(!$endDate){
    $endDate = [int64]$startDate + 86400000000
}else{
    $endDate = dateToUsecs $endDate
}

$objEnvironment = @{
    'mailbox' = @('kO365Exchange', 'kO365ExchangeCSM');
    'onedrive' = @('kO365OneDrive', 'kO365OneDriveCSM')
}

# authenticate
apiauth -username $username

"`nOperating on Object Type: $objectType Date: $(usecsToDate $startDate) to $(usecsToDate $endDate)`n" | Tee-Object -FilePath legalHoldLog.txt

# find O365 source
$rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365&excludeProtectionStats=true&regionIds=$region").sources | Where-Object name -eq $sourceName

if(!$rootSource){
    Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
    exit
}

$rootSourceId = $rootSource[0].sourceInfoList[0].sourceId

$source = api get "protectionSources?id=$($rootSourceId)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false&regionId=$region"
$usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$usersNode){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
}

$trackDupe = @()
$script:objectIds = @()
$script:addHolds = @()
$script:removeHolds = @()

function addhold(){
    $holdParams =  @{
        "targetObjectRuns" = @($script:addHolds);
        "environment" = "kO365";
        "legalHold" = "Enable"
    }
    $result = api put -mcmv2 "data-protect/objects/runs/metadata?regionIds=$($activity.regionId)" $holdParams
    if($result.objectRunList[0].PSObject.Properties['errorMessage']){
        Write-Host "$($result.objectRunList[0].errorMessage)" -ForegroundColor Yellow
    }
    $script:addHolds = @()
}

function removehold(){
    $holdParams =  @{
        "targetObjectRuns" = @($script:removeHolds);
        "environment" = "kO365";
        "legalHold" = "Release"
    }
    $result = api put -mcmv2 "data-protect/objects/runs/metadata?regionIds=$($activity.regionId)" $holdParams
    if($result.objectRunList[0].PSObject.Properties['errorMessage']){
        Write-Host "$($result.objectRunList[0].errorMessage)" -ForegroundColor Yellow
    }
    $script:removeHolds = @()
}

function query(){

    $queryParams = @{
        "statsParams" = @{
            "attributes" = @(
                "Status";
                "ActivityType"
            )
        };
        "fromTimeUsecs" = [Int64]$startDate;
        "toTimeUsecs" = [Int64]$endDate;
        "environments" = @(
            "kO365"
        );
        "archivalRunParams" = @{
            "protectionEnvironmentTypes" = $objEnvironment[$objectType]
        };
        "backupRunParams" = @{
            "protectionEnvironmentTypes" = $objEnvironment[$objectType]
        };
        "activityTypes" = @(
            "ArchivalRun";
            "BackupRun"
        );
        "excludeStats" = $True;
        "objectIdentifiers" = @()
    }

    foreach($objectId in $script:objectIds){
        $queryParams.objectIdentifiers = @($queryParams.objectIdentifiers + @{ 
            "objectId" = $objectId;
            "clusterId" = $null;
            "regionId" = $region
        })
    }
    if($showTrue){
        $queryParams['statuses'] = @('LegalHold')
    }
    while($True){
        $activities = api post -mcmv2 "data-protect/objects/activity?regionIds=$region" $queryParams
        $activities.activity = @($activities.activity | Where-Object {$_.id -notin $trackDupe})
        if($dbg){
            $activities | toJson | Out-File -FilePath 'debug-legalHoldCCS.txt' -Append
        }
        if($activities.activity -ne $null){
            foreach($activity in $activities.activity | Where-Object {$_.archivalRunParams.status -ne 'Failed'}){
                $totalCount += 1
                $objectId = $activity.object.id
                $trackDupe = @($trackDupe + $activity.id)
                $startTimeUsecs = $activity.archivalRunParams.runStartTimeUsecs
                if($addHold -and $activity.archivalRunParams.onLegalHold -eq $False){
                    $script:addHolds = @($script.runs + @{
                        "id" = "$objectId";
                        "runStartTimeUsecs" = $startTimeUsecs
                    })
                    "Adding legal hold to $($activity.object.name) ($(usecsToDate $startTimeUsecs))" | Tee-Object -FilePath legalHoldLog.txt -Append
                    if(@($script:addHolds).Count -ge $objectsPerQuery){
                        addhold
                        $script:addHolds = @()
                    }
                }elseif($removeHold -and $activity.archivalRunParams.onLegalHold -eq $True){
                    $script:removeHolds = @($script:removeHolds + @{
                        "id" = "$objectId";
                        "runStartTimeUsecs" = $startTimeUsecs
                    })
                    "Removing legal hold from $($activity.object.name) ($(usecsToDate $startTimeUsecs))" | Tee-Object -FilePath legalHoldLog.txt -Append
                    if(@($script:removeHolds).Count -ge $objectsPerQuery){
                        removehold
                        $script:removeHolds = @()
                    }
                }elseif($showTrue -or $showFalse){
                    $showMe = $True
                    if($showFalse -and $activity.archivalRunParams.onLegalHold -eq $True){
                        $showMe = $False
                    }
                    if($showTrue -and $activity.archivalRunParams.onLegalHold -eq $False){
                        $showMe = $False
                    }
                    if($showMe -eq $True){
                        "$($activity.object.name) ($(usecsToDate $startTimeUsecs)) on hold = $($activity.archivalRunParams.onLegalHold)" | Tee-Object -FilePath legalHoldLog.txt -Append
                    }       
                }
            }
            if(@($script:addHolds).Count -gt 0){
                addhold
            }
            if(@($script:removeHolds).Count -gt 0){
                removehold
            }
        }

        if(@($activities.activity).Count -gt 0 -and $queryParams.fromTimeUsecs -gt $startDate){
            $queryParams.fromTimeUsecs = $queryParams.fromTimeUsecs - ($range * 86400000000)
            if($queryParams.fromTimeUsecs -lt $startDate){
                $queryParams.fromTimeUsecs = [int64]$startDate
            }
            if($activities.activity -ne $null){
                $queryParams.toTimeUsecs = $activities.activity[-1].timeStampUsecs
            } 
        }else{
            if(@($activities.activity).Count -lt 1000){
                break
            }else{
                $queryParams.toTimeUsecs = $activities.activity[-1].timeStampUsecs
            }
        }
    }
}

$users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false&regionId=$region"

while(1){
    foreach($node in $users.nodes){
        $objId = $node.protectionSource.id
        # $smtp = $node.protectionSource.office365ProtectionSource.primarySMTPAddress
        if(($node.protectedSourcesSummary | Where-Object {$_.environment -in $objEnvironment[$objectType]}).leavesCount -eq 1){
            $script:objectIds = @($script:objectIds + $objId)
        }
        if(@($script:objectIds).Count -ge $objectsPerQuery){
            query
            $script:objectIds = @()
        }
    }
    $cursor = $users.nodes[-1].protectionSource.id
    $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false&afterCursorEntityId=$cursor&regionId=$region"
    if(!$users.PSObject.Properties['nodes'] -or $users.nodes.Count -eq 1){
        if(@($script:objectIds).Count -gt 0){
            query
        }
        break
    }
}  
