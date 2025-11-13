# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter()][array]$mailboxName,  # optional names of mailboxes protect
    [Parameter()][string]$mailboxList = '',  # optional textfile of mailboxes to protect
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$targetSource,
    [Parameter()][string]$source,
    [Parameter()][string]$targetMailbox,
    [Parameter()][string]$folderPrefix = 'restore',
    [Parameter()][int]$pageSize = 1000,
    [Parameter()][switch]$useMBS
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


$objectNames = @(gatherList -Param $mailboxName -FilePath $mailboxList -Name 'mailboxes' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','
$selectedRegion = $null
$selectedRegionObject = $null
$targetMailboxName = $null
$targetMailboxId = $null
$targetParentId = $null

foreach($objName in $objectNames){
    $search = api get -v2 "data-protect/search/objects?searchString=$objName&regionIds=$regionList&o365ObjectTypes=kO365Exchange,kUser&isProtected=true&environments=kO365&includeTenants=true&count=$pageSize"
    $exactMatch = $search.objects | Where-Object name -eq $objName
    if($source){
        $exactMatch = $exactMatch | Where-Object {$_.sourceInfo.name -eq $source}
    }
    if(! $exactMatch){
        Write-Host "$objName not found" -ForegroundColor Yellow
    }else{
        $x = 0
        foreach($result in $exactMatch | Where-Object {$_.name -eq $objName}){
            $x += 1
            foreach($objectProtectionInfo in $result.objectProtectionInfos){
                
                $objectId = $objectProtectionInfo.objectId
                $objectRegionId = $objectProtectionInfo.regionId
                if($selectedRegion -eq $null){
                    $selectedRegion = $objectRegionId
                    $selectedRegionObject = $objName
                    if($targetSource -and !$targetMailboxId){
                        if(!$targetMailbox){
                            Write-Host "-targetMailbox is required" -ForegroundColor Yellow
                            exit
                        }
                        $rootSource = api get "protectionSources/rootNodes?environments=kO365" -region $objectRegionId | Where-Object {$_.protectionSource.name -eq $targetSource}
                        if(!$rootSource){
                            Write-Host "$targetSource not found" -ForegroundColor Yellow
                            exit
                        }
                        $targetParentId = $rootSource[0].protectionSource.id
                        $tsource = api get "protectionSources?id=$($rootSource[0].protectionSource.id)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kTeam,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false" -region $objectRegionId
                        $usersNode = $tsource.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
                        $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false" -region $objectRegionId
                        while(1){
                            foreach($node in $users.nodes){
                                if($node.protectionSource.name -eq $targetMailbox){
                                    $targetMailboxName = $node.protectionSource.name
                                    $targetMailboxId = $node.protectionSource.id
                                    break
                                }
                            }
                            $cursor = $users.nodes[-1].protectionSource.id
                            $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false&afterCursorEntityId=$cursor" -region $objectRegionId
                            if(!$users.PSObject.Properties['nodes'] -or $users.nodes.Count -eq 1){
                                break
                            }
                        }
                        if(!$targetMailboxId){
                            Write-Host "$targetMailbox not found" -ForegroundColor Yellow
                            exit
                        }
                    }
                }else{
                    if($objectRegionId -ne $selectedRegion){
                        Write-Host "$objName is in a different region than $selectedRegionObject and must be restored separately" -ForegroundColor Yellow
                        continue
                    }
                }
                if($useMBS){
                    $snapshots = api get -v2 "data-protect/objects/$objectId/snapshots?snapshotActions=RecoverMailboxCSM&objectActionKeys=kO365ExchangeCSM&regionId=$objectRegionId"
                }else{
                    $snapshots = api get -v2 "data-protect/objects/$objectId/snapshots?objectActionKeys=kO365Exchange&regionId=$objectRegionId"
                }
                
                $snapshots = $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending
                if($snapshots -and $snapshots.Count -gt 0){
                    if($recoverDate){
                        $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))
                    
                        $snapshots = $snapshots | Where-Object runStartTimeUsecs -lt $recoverDateUsecs
                        if($snapshots -and $snapshots.Count -gt 0){
                            $snapshot = $snapshots[0]
                            $snapshotId = $snapshot.id
                        }else{
                            Write-Host "No snapshots available for $objName"
                        }
                    }else{
                        $snapshot = $snapshots[0]
                        $snapshotId = $snapshot.id
                    }
                    $dateString = Get-Date -UFormat '%b_%d_%Y_%H-%M%p'
                    $restoreParams = @{
                        "name" = "Recover_Mailboxes_$dateString";
                        "snapshotEnvironment" = "kO365";
                        "office365Params" = @{
                            "recoveryAction" = "RecoverMailbox";
                            "recoverMailboxParams" = @{
                                "continueOnError" = $true;
                                "objects" = @(
                                    @{
                                        "mailboxParams" = @{
                                            "recoverFolders" = $null;
                                            "recoverEntireMailbox" = $true
                                        };
                                        "ownerInfo" = @{
                                            "snapshotId" = $snapshotId
                                        }
                                    }
                                )
                            }
                        }
                    }
                    if($useMBS){
                        $restoreParams.office365Params.recoveryAction = "RecoverMailboxCSM"
                    }
                    if($targetSource){
                        Write-Host "Restoring $objName to $targetMailboxName ($($folderPrefix)-$($objName))"
                        $restoreParams.office365Params.recoverMailboxParams['targetMailbox'] = @{
                            "targetFolderPath" = "$($folderPrefix)-$($objName)";
                            "id" = [int64]$targetMailboxId;
                            "name" = "$targetMailboxName";
                            "parentSourceId" = [int64]$targetParentId
                        }
                    }else{
                        Write-Host "Restoring $objName"
                    }
                    $null = api post -v2 "data-protect/recoveries?regionId=$objectRegionId" $restoreParams
                }else{
                    Write-Host "No snapshots available for $objName"
                }
            }
        }
        if($x -eq 0){
            Write-Host "$objName not found" -ForegroundColor Yellow
        }
    }
}
