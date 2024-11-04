# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter()][string]$mailboxName,  # optional names of mailboxes protect
    [Parameter()][int]$pageSize = 1000,
    [Parameter()][string]$pstPassword = '',
    [Parameter()][switch]$promptForPSTPassword,
    [Parameter()][string]$fileName = '.\pst.zip',
    [Parameter()][string]$timestamp,
    [Parameter()][switch]$showTimestamps,
    [Parameter()][int]$sleepTimeSeconds = 30,
    [Parameter()][string]$emailSubject = '*',
    [Parameter()][string]$senderAddress = $null,
    [Parameter()][datetime]$recoverDate,
    [Parameter()][datetime]$receivedStartTime,
    [Parameter()][datetime]$receivedEndTime
)

if($promptForPSTPassword){
    while($True){
        $secureNewPassword = Read-Host -Prompt "  Enter PST password" -AsSecureString
        $secureConfirmPassword = Read-Host -Prompt "Confirm PST password" -AsSecureString
        $pstPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureNewPassword ))
        $confirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureConfirmPassword ))
        if($pstPassword -cne $confirmPassword){
            Write-Host "Passwords do not match" -ForegroundColor Yellow
        }else{
            break
        }
    }
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

# search for mailbox
$search = api get -v2 "data-protect/search/objects?searchString=$mailboxName&regionIds=$regionList&o365ObjectTypes=kO365Exchange,kUser&isProtected=true&environments=kO365&includeTenants=true&count=$pageSize"
$exactMatch = $search.objects | Where-Object name -eq $mailboxName
if(! $exactMatch){
    Write-Host "$mailboxName not found" -ForegroundColor Yellow
}else{
    $x = 0
    foreach($result in $exactMatch | Where-Object {$_.name -eq $mailboxName}){
        
        $x += 1
        foreach($objectProtectionInfo in $result.objectProtectionInfos){
            $objectId = $objectProtectionInfo.objectId
            $objectRegionId = $objectProtectionInfo.regionId

            $dateString = Get-Date -UFormat '%b_%d_%Y_%H-%M%p'

            $recoveryParamList = @{}
            
            # base recovery params
            $recoveryParams = @{
                "name" = "Recover_Mailboxes_$dateString";
                "snapshotEnvironment" = "kO365";
                "office365Params" = @{
                    "recoveryAction" = "ConvertToPst";
                    "recoverMailboxParams" = @{
                        "continueOnError" = $true;
                        "skipRecoverArchiveMailbox" = $false;
                        "skipRecoverRecoverableItems" = $true;
                        "skipRecoverArchiveRecoverableItems" = $true;
                        "objects" = @();
                        "pstParams" = @{
                            "password" = $pstPassword
                        }
                    }
                }
            }

            # item search params
            $searchParams = @{
                "objectType" = "Emails";
                "emailParams" = @{
                    "types" = @(
                        "Email"
                    );
                    "emailSubject" = $emailSubject;
                    "senderAddress" = $null;
                    "receivedStartTimeSecs" = $null;
                    "receivedEndTimeSecs" = $null;
                    "hasAttachment" = $null;
                    "o365Params" = @{
                        "domainIds" = @();
                        "mailboxIds" = @(
                            $objectId
                        )
                    }
                }
            }
            if($senderAddress){
                $searchParams.emailParams.senderAddress = $senderAddress
            }
            if($receivedStartTime){
                $receivedStartTimeSecs = [Int64]((dateToUsecs $receivedStartTime) / 1000000)
                $searchParams.emailParams.receivedStartTimeSecs = $receivedStartTimeSecs
            }
            if($receivedEndTime){
                $receivedEndTimeSecs = [Int64]((dateToUsecs $receivedEndTime) / 1000000)
                $searchParams.emailParams.receivedEndTimeSecs = $receivedEndTimeSecs
            }
            Write-Host "==> Searching for matching items..."
            $itemsFound = 0
            $searchResults = api post -v2 "data-protect/search/indexed-objects" $searchParams -region $objectRegionId
            $snapshotTimes = @()
            foreach($email in $searchResults.emails){
                $itemsFound += 1
                $emailPath = [System.Web.HttpUtility]::UrlEncode($email.Path)
                # find snapshots for item
                $itemSnapshots = (api get -v2 "data-protect/objects/$objectId/indexed-objects/snapshots?indexedObjectName=$emailPath&objectActionKey=kO365Exchange&includeIndexedSnapshotsOnly=true" -region $objectRegionId).snapshots
                if($recoverDate){
                    $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))
                    $itemSnapshots = $itemSnapshots | Sort-Object -Property snapshotTimestampUsecs -Descending | Where-Object snapshotTimestampUsecs -lt $recoverDateUsecs
                }
                if($timestamp){
                    $itemSnapshots = $itemSnapshots | Where-Object {$_.snapshotTimestampUsecs -eq $timestamp}
                }
                if(! $itemSnapshots){
                    continue
                }
                $itemSnapshot = $itemSnapshots[0]
                $snapshotTimes = @($snapshotTimes + $itemSnapshot.snapshotTimestampUsecs)
                if("$($itemSnapshot.snapshotTimestampUsecs)" -notin $recoveryParamList.Keys){
                    $recoveryParamList["$($itemSnapshot.snapshotTimestampUsecs)"] =  @{
                        "name" = "Recover_Mailboxes_$dateString";
                        "snapshotEnvironment" = "kO365";
                        "office365Params" = @{
                            "recoveryAction" = "ConvertToPst";
                            "recoverMailboxParams" = @{
                                "continueOnError" = $true;
                                "skipRecoverArchiveMailbox" = $false;
                                "skipRecoverRecoverableItems" = $true;
                                "skipRecoverArchiveRecoverableItems" = $true;
                                "objects" = @();
                                "pstParams" = @{
                                    "password" = $pstPassword
                                }
                            }
                        }
                    }
                }
                $recoveryParams = $recoveryParamList["$($itemSnapshot.snapshotTimestampUsecs)"]
                # add item to recovery params
                $recoveryObject = $recoveryParams.office365Params.recoverMailboxParams.objects | Where-Object {$_.ownerInfo.snapshotId -eq $itemSnapshot.objectSnapshotid}
                if(! $recoveryObject){
                    $recoveryObject = @{
                        "mailboxParams" = @{
                            "recoverFolders" = @(
                                @{
                                    "key" = $email.parentFolderId;
                                    "recoverEntireFolder" = $false;
                                    "itemIds" = @($email.id)
                                }
                            );
                            "recoverEntireMailbox" = $false
                        };
                        "ownerInfo" = @{
                            "snapshotId" = $itemSnapshot.objectSnapshotid
                        }
                    }
                    $recoveryParams.office365Params.recoverMailboxParams.objects = @($recoveryParams.office365Params.recoverMailboxParams.objects + $recoveryObject)
                }else{
                    $recoveryFolder = $recoveryObject.mailboxParams.recoverFolders | Where-Object {$_.key -eq $email.parentFolderId}
                    if(! $recoveryFolder){
                        $recoveryFolder = @{
                            "key" = $email.parentFolderId;
                            "recoverEntireFolder" = $false;
                            "itemIds" = @($email.id)
                        }
                        $recoveryObject.mailboxParams.recoverFolders = @($recoveryObject.mailboxParams.recoverFolders + $recoveryFolder)
                    }else{
                        $recoveryFolder.itemIds = @($recoveryFolder.itemIds + $email.id)
                    }
                }
            }
            $snapshotTimes = @($snapshotTimes | Sort-Object -Unique -Descending)
            if($showTimestamps){ # if($snapshotTimes.Count -gt 1){
                Write-Host "`nThere are messages from the following snapshot timestamps:`n"
                foreach($snapshotTime in $snapshotTimes){
                    Write-Host "$snapshotTime ($(usecsToDate $snapshotTime))"
                }
                Write-Host ""
                exit
            }
            if($itemsFound -eq 0){
                continue
            }
            Write-Host "==> Recovering $itemsFound items..."
            # perform recoveries
            $recoveries = @()
            foreach($thisTimestamp in $recoveryParamList.Keys){
                $recovery = api post -v2 "data-protect/recoveries" $recoveryParamList["$thisTimestamp"] -region $objectRegionId
                $recoveries = @($recoveries + $recovery)
            }
            
            "==> Waiting for PST conversion to complete..."
            # wait for recovery to complete
            $finishedStates = @('Canceled', 'Succeeded', 'Failed')
            $pass = 0
            $recoveryNum = 0
            Start-Sleep $sleepTimeSeconds
            foreach($recovery in $recoveries){
                $recoveryNum += 1
                do{
                    $recoveryTask = api get -v2 data-protect/recoveries/$($recovery.id)?includeTenants=true
                    $status = $recoveryTask.status
                    if($status -notin $finishedStates){
                        Start-Sleep $sleepTimeSeconds
                    }
                } until ($status -in $finishedStates)
                # download PST files
                $downloadURL = "https://helios.cohesity.com/v2/data-protect/recoveries/$($recovery.id)/downloadFiles?regionId=$objectRegionId&includeTenants=true"
                if($status -eq 'Succeeded'){
                    if($recoveries.Count -gt 1){
                        $thisFilename = "$(($fileName -split '.zip')[0])-$($recoveryNum).zip"
                    }else{
                        $thisFilename = $fileName
                    }
                    Write-Host "==> Downloading zip file $thisFilename"
                    fileDownload -uri $downloadURL -filename "$thisFilename"
                }else{
                    Write-Host "*** PST conversion finished with status: $status ***"
                }
            }
        }
    }
    if($x -eq 0){
        Write-Host "$mailboxName not found" -ForegroundColor Yellow
    }
}
