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
    [Parameter()][switch]$useMBS,
    [Parameter(Mandatory=$True)][string]$region
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

$targetMailboxName = $null
$targetMailboxId = $null
$targetParentId = $null

foreach($objName in $objectNames){
    $search = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverMailbox&searchString=$objName&environments=kO365&regionIds=$region"
    $objMatches = $search.objects | Where-Object {$_.name -eq $objName -or $_.o365Params.primarySMTPAddress -eq $objName}
    if($source){
        $objMatches = $objMatches | Where-Object {$_.sourceInfo.name -eq $source}
    }
    if(! $objMatches){
        Write-Host "$objName not found" -ForegroundColor Yellow
    }else{
        $x = 0
        foreach($obj in $objMatches){
            $x += 1
            $objectId = $obj.id
            # find target mailbox
            if($targetMailbox -and !$targetMailboxId){
                $targetSearch = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverMailbox&searchString=$targetMailbox&environments=kO365&regionIds=$region"
                $targetMatches = $targetSearch.objects | Where-Object {$_.name -eq $targetMailbox -or $_.o365Params.primarySMTPAddress -eq $targetMailbox}
                if($targetSource){
                    $targetMatches = $targetMatches | Where-Object {$_.sourceInfo.name -eq $targetSource}
                }
                if(! $targetMatches){
                    Write-Host "targetMailbox $targetMailbox not found" -ForegroundColor Yellow
                    exit 1
                }else{
                    $targetParentId = $targetMatches[0].sourceInfo.id
                    $targetMailboxId = $targetMatches[0].id
                    $targetMailboxName = $targetMatches[0].name
                }
            }

            # find snapshots
            if($useMBS){
                $snapshots = api get -v2 "data-protect/objects/$objectId/snapshots?snapshotActions=RecoverMailboxCSM&objectActionKeys=kO365ExchangeCSM&regionId=$region"
            }else{
                $snapshots = api get -v2 "data-protect/objects/$objectId/snapshots?objectActionKeys=kO365Exchange&regionId=$region"
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
                if($targetMailbox){
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
                $null = api post -v2 "data-protect/recoveries?regionId=$region" $restoreParams
            }else{
                Write-Host "No snapshots available for $objName"
            }
        }
        if($x -eq 0){
            Write-Host "$objName not found" -ForegroundColor Yellow
        }
    }
}
