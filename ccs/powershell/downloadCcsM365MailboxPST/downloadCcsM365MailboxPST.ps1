# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter()][array]$mailboxName,  # optional names of mailboxes protect
    [Parameter()][string]$mailboxList = '',  # optional textfile of mailboxes to protect
    [Parameter()][datetime]$recoverDate,
    [Parameter()][int]$pageSize = 1000,
    [Parameter()][string]$pstPassword = '',
    [Parameter()][switch]$promptForPSTPassword,
    [Parameter()][string]$outputPath = '.',
    [Parameter()][switch]$useMBS,
    [Parameter()][int]$sleepTimeSeconds = 30,
    [Parameter()][string]$region,
    [Parameter()][string]$sourceName
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


$objectNames = @(gatherList -Param $mailboxName -FilePath $mailboxList -Name 'mailboxes' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

if(!$region){
    $sessionUser = api get sessionUser
    $tenantId = $sessionUser.profiles[0].tenantId
    $regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
    $regionList = $regions.tenantRegionInfoList.regionId -join ','
}else{
    $regionList = $region
}

if($sourceName){
    # find O365 source
    $rootSource = (api get -mcmv2 "data-protect/sources?environments=kO365&regionIds=$regionList").sources | Where-Object name -eq $sourceName
    if(!$rootSource){
        Write-Host "O365 Source $sourceName not found" -ForegroundColor Yellow
        exit
    }
}

$selectedRegion = $null
$selectedRegionObject = $null
$targetMailboxName = $null
$targetMailboxId = $null
$targetParentId = $null

$dateString = Get-Date -UFormat '%b_%d_%Y_%H-%M%p'

$recoveryParams = @{
    "name" = "Recover_Mailboxes_$dateString";
    "snapshotEnvironment" = "kO365";
    "office365Params" = @{
        "recoveryAction" = "ConvertToPst";
        "recoverMailboxParams" = @{
            "continueOnError" = $true;
            "skipRecoverArchiveMailbox" = $true;
            "skipRecoverRecoverableItems" = $true;
            "skipRecoverArchiveRecoverableItems" = $true;
            "skipRecoverPrimaryMailbox" = $false;
            "objects" = @();
            "pstParams" = @{
                "password" = $pstPassword;
                "separateDownloadFiles" = $true
            }
        }
    }
}

foreach($objName in $objectNames){
    if($sourceName){
        $search = api get -v2 "data-protect/search/objects?searchString=$objName&regionIds=$regionList&o365ObjectTypes=kO365Exchange,kUser&isProtected=true&environments=kO365&includeTenants=true&count=$pageSize&sourceUuids=$($rootSource[0].id)"
    }else{
        $search = api get -v2 "data-protect/search/objects?searchString=$objName&regionIds=$regionList&o365ObjectTypes=kO365Exchange,kUser&isProtected=true&environments=kO365&includeTenants=true&count=$pageSize"
    }
    
    $exactMatch = $search.objects | Where-Object name -eq $objName
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
                    

                    $recoveryParams.office365Params.recoverMailboxParams.objects = @($recoveryParams.office365Params.recoverMailboxParams.objects + @{
                        "mailboxParams" = @{
                            "recoverFolders" = $null;
                            "recoverEntireMailbox" = $true
                        };
                        "ownerInfo" = @{
                            "snapshotId" = $snapshotId
                        }
                    })

                    Write-Host "==> Processing $objName"
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

if(@($recoveryParams.office365Params.recoverMailboxParams.objects).Count -gt 0){
    $recovery = api post -v2 "data-protect/recoveries?regionId=$objectRegionId" $recoveryParams
    "==> Waiting for PST conversions to complete..."
    $finishedStates = @('Canceled', 'Succeeded', 'Failed')
    $pass = 0
    do{
        Start-Sleep $sleepTimeSeconds
        $recoveryTask = api get -v2 "data-protect/recoveries/$($recovery.id)?regionId=$objectRegionId"
        $status = $recoveryTask.status
    } until ($status -in $finishedStates)
    $downloadIdParts = $recovery.id -split ':'
    $x = 0
    if($status -eq 'Succeeded'){
        foreach($childTask in $recoveryTask.childTasks){
            $downloadId = "$($downloadIdParts[0]):$($downloadIdParts[1]):$($childTask.taskId)"
            $downloadURL = "https://helios.cohesity.com/v2/data-protect/recoveries/$($downloadId)/downloadFiles?regionId=$($objectRegionId)&includeTenants=true"
            $objInfoName = $recoveryTask.office365Params.objects[$x].objectInfo.name
            $filePart = $objInfoName -replace '\.', '-'
            $fileName = $(Join-Path -Path $outputPath -ChildPath "$($filePart)-pst.zip")
            $x = $x + 1
            Write-Host "==> Downloading $fileName"
            fileDownload -uri $downloadURL -filename $fileName
        }
    }else{
        Write-Host "*** PST conversion finished with status: $status ***"
    }
}else{
    Write-Host "No restores processed"
}
