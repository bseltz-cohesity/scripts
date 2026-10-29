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
    [Parameter()][array]$sourceUserName,
    [Parameter()][string]$sourceUserList,
    [Parameter()][string]$source,
    [Parameter()][string]$jobName,
    [Parameter()][datetime]$recoverDate,
    [Parameter()][string]$targetMailbox,
    [Parameter()][string]$targetSource,
    [Parameter()][string]$folderPrefix = 'restore',
    [Parameter()][switch]$continueOnError,
    [Parameter()][string]$ewsExchangeTarget,
    [Parameter()][string]$smtpAddressOverride,
    [Parameter()][string]$sidOverride,
    [Parameter()][string]$mailboxGuidOverride
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

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
            Write-Host "*** Text file $FilePath not found! ***" -ForegroundColor Yellow
            exit 1
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "*** No $Name specified ***" -ForegroundColor Yellow
        exit 1
    }
    return ($items | Sort-Object -Unique)
}

$sourceUserNames = @(gatherList -Param $sourceUserName -FilePath $sourceUserList -Name 'sourceUserName' -Required $True)

if(@($sourceUserNames).Count -gt 1){
    if($smtpAddressOverride -or $sidOverride -or $mailboxGuidOverride){
        Write-Host "Only one source mailbox can be specified if -smtpAddressOverride, -sidOverride or -mailboxGuidOverride are specified" -ForegroundColor Yellow
        exit 1
    }
}

# resolve target mailbox once (if restoring to an alternate mailbox)
$targetMailboxName = $null
$targetMailboxId = $null
$targetParentId = $null

if($ewsExchangeTarget){
    $ewssources = api get -v2 data-protect/sources/registrations
    $ewssource = $ewssources.registrations | Where-Object {$_.environment -eq 'kEwsExchange' -and $_.sourceInfo.name -eq $ewsExchangeTarget}
    if(!$ewssource){
        Write-Host "EWS Exchange target $ewsExchangeTarget not found" -ForegroundColor Yellow
        exit 1
    }
}

if($targetMailbox){
    $targetSearch = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverMailbox&searchString=$targetMailbox&environments=kO365"
    $targetMatches = $targetSearch.objects | Where-Object {$_.name -eq $targetMailbox -or $_.o365Params.primarySMTPAddress -eq $targetMailbox}
    if($targetSource){
        $targetMatches = $targetMatches | Where-Object {$_.sourceInfo.name -eq $targetSource}
    }
    if(! $targetMatches){
        Write-Host "*** targetMailbox $targetMailbox not found ***" -ForegroundColor Yellow
        exit 1
    }
    $targetParentId = $targetMatches[0].sourceInfo.id
    $targetMailboxId = $targetMatches[0].id
    $targetMailboxName = $targetMatches[0].name
}

foreach($sourceUser in $sourceUserNames){
    $userSearch = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverMailbox&searchString=$sourceUser&environments=kO365"
    $userObjs = $userSearch.objects | Where-Object {$_.name -eq $sourceUser -or $_.o365Params.primarySMTPAddress -eq $sourceUser}
    
    if($source){
        $userObjs = $userObjs | Where-Object {$_.sourceInfo.name -eq $source}
    }
    if(!$userObjs){
        Write-Host "*** Mailbox User $sourceUser not found ***" -ForegroundColor Yellow
        if($continueOnError){
            continue
        }else{
            exit 1
        }
    }

    foreach($userObj in $userObjs){
        $objectId = $userObj.id
        if($jobName){
            $userObj.latestSnapshotsInfo = @($userObj.latestSnapshotsInfo | Where-Object {$_.protectionGroupName -eq $jobName})
            if(@($userObj.latestSnapshotsInfo).Count -lt 1){
                Write-Host "No backups for $sourceUser in $jobName" -ForegroundColor Yellow
                continue
            }
        }
        $protectionGroupId = $userObj.latestSnapshotsInfo[0].protectionGroupId
        $snapshotId = $userObj.latestSnapshotsInfo[0].localSnapshotInfo.snapshotId

        if($recoverDate){
            $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))

            $snapshots = api get -v2 "data-protect/objects/$objectId/snapshots?protectionGroupIds=$($protectionGroupId)"
            $snapshots = $snapshots.snapshots | Sort-Object -Property runStartTimeUsecs -Descending | Where-Object runStartTimeUsecs -lt $recoverDateUsecs
            if($snapshots -and $snapshots.Count -gt 0){
                $snapshot = $snapshots[0]
                $snapshotId = $snapshot.id
            }else{
                Write-Host "*** No snapshots available for $sourceUser from specified date ***" -ForegroundColor Yellow
                if($continueOnError){
                    continue
                }else{
                    exit 1
                }
            }
        }

        $dateString = Get-Date -UFormat '%b_%d_%Y_%H-%M%p'
        $restoreParams = @{
            "name" = "Recover_Mailboxes_$dateString";
            "snapshotEnvironment" = "kO365";
            "office365Params" = @{
                "recoveryAction" = "RecoverMailbox";
                "recoverMailboxParams" = @{
                    "continueOnError" = $false;
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

        if($smtpAddressOverride){
            $restoreParams.office365Params.recoverMailboxParams.objects[0].mailboxParams['smtpAddressOverride'] = $smtpAddressOverride
        }
        if($sidOverride){
            $restoreParams.office365Params.recoverMailboxParams.objects[0].mailboxParams['sidOverride'] = $sidOverride
        }
        if($mailboxGuidOverride){
            $restoreParams.office365Params.recoverMailboxParams.objects[0].mailboxParams['mailboxGuidOverride'] = $mailboxGuidOverride
        }

        if($ewsExchangeTarget){
            $restoreParams.office365Params.recoveryAction = "RecoverO365ToExchangeServer"
            $restoreParams.office365Params.recoverMailboxParams["ewsExchangeTarget"] = @{
                "ewsExchangeServerEntityId" = $ewssource.id
            }
        }

        if($targetMailbox){
            Write-Host "==> Restoring $sourceUser to $targetMailboxName ($($folderPrefix)-$($sourceUser))"
            $restoreParams.office365Params.recoverMailboxParams['targetMailbox'] = @{
                "targetFolderPath" = "$($folderPrefix)-$($sourceUser)";
                "id" = [int64]$targetMailboxId;
                "name" = "$targetMailboxName";
                "parentSourceId" = [int64]$targetParentId
            }
        }else{
            Write-Host "==> Restoring $sourceUser"
        }

        $recovery = api post -v2 data-protect/recoveries $restoreParams
        if($recovery.id){
            Write-Host "    Recovery task ID: $($recovery.id)"
        }else{
            Write-Host "*** Failed to start recovery for $sourceUser ***" -ForegroundColor Yellow
            if(!$continueOnError){
                exit 1
            }
        }
    }
}
