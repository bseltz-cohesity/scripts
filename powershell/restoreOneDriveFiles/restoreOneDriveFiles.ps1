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
    [Parameter()][array]$fileName,
    [Parameter()][string]$fileList,
    [Parameter(Mandatory=$True)][string]$sourceUser,
    [Parameter()][string]$targetUser,
    [Parameter()][string]$targetFolder,
    [Parameter()][switch]$localOnly,
    [Parameter()][switch]$archiveOnly
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


$filePaths = @(gatherList -Param $fileName -FilePath $fileList -Name 'files' -Required $True)

$userSearch = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverOneDrive&searchString=$sourceUser&objectActionKey=kO365OneDrive&environments=kO365"
$userObj = $userSearch.objects | Where-Object name -eq $sourceUser
if(!$userObj){
    Write-Host "One Drive User $sourceUser not found" -ForegroundColor Yellow
    exit
}

if($targetUser){
    $targetUserSearch = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverOneDrive&searchString=$targetUser&objectActionKey=kO365OneDrive&environments=kO365"
    $targetUserObj = $targetUserSearch.objects | Where-Object name -eq $targetUser
    if(!$targetUserObj){
        Write-Host "One Drive User $targetUser not found" -ForegroundColor Yellow
        exit
    }
}else{
    $targetUserObj = $userObj
}

foreach($filePath in $filePaths){
    $searchParams = @{
        "objectType" = "OneDriveObjects";
        "oneDriveParams" = @{
            "searchString" = "$filePath";
            "creationStartTimeSecs" = $null;
            "creationEndTimeSecs" = $null;
            "includeFiles" = $true;
            "includeFolders" = $true;
            "o365Params" = @{
                "userIds" = @(
                    $userObj.id
                )
            }
        }
    }
    $searchResults = api post -v2 "data-protect/search/indexed-objects" $searchParams
    $searchResult = $searchResults.oneDriveItems | Where-Object path -eq $filePath
    if(! $searchResult){
        Write-Host "No backups found for $filePath" -ForegroundColor Yellow
        continue
    }
    $isFile = $false
    if($searchResult.fileType -eq 'File'){
        $isFile = $True
    }
    $snaps = api get -v2 "data-protect/objects/$($userObj.id)/protection-groups/$($searchResult.protectionGroupId)/indexed-objects/snapshots?indexedObjectName=$($filePath)&useCachedData=false&includeIndexedSnapshotsOnly=true"
    $snaps = $snaps.snapshots | Where-Object indexedObjectName -eq $filePath
    if(! $snaps){
        Write-Host "No backups found for $filePath" -ForegroundColor Yellow
        continue
    }

    
    $localSnaps = $snaps | Where-Object {! $_.PSObject.Properties['externalTargetInfo']}
    $archiveSnaps = $snaps | Where-Object {$_.snapshotTimestampUsecs -notin $localSnaps.snapshotTimestampUsecs}
    if($localOnly){
        if(! $localSnaps){
            Write-Host "Skipping $filePath - no local backup" -ForegroundColor Yellow
            continue
        }
        $snap = ($localSnaps | Sort-Object -Property {$_.snapshotTimestampUsecs})[-1]
    }elseif($archiveOnly){
        if(! $archiveSnaps){
            Write-Host "Skipping $filePath - no archive backup" -ForegroundColor Yellow
            continue
        }
        $snap = ($archiveSnaps | Sort-Object -Property {$_.snapshotTimestampUsecs})[-1]
    }else{
        $latestSnap = ($snaps | Sort-Object -Property {$_.snapshotTimestampUsecs})[-1]
        $latestSnaps = $snaps | Where-Object {$_.snapshotTimestampUsecs -eq $latestSnap.snapshotTimestampUsecs}
        $localSnap = $latestSnaps | Where-Object {! $_.PSObject.Properties['externalTargetInfo']}
        if($localSnap){
            $snap = $localSnap
        }else{
            $snap = $latestSnap
        }
    }

    $taskName = $filePath -replace '/', '-'
    $recoveryParams = $myObject = @{
        "name" = "Recover_OneDrive$($taskName)";
        "snapshotEnvironment" = "kO365";
        "office365Params" = @{
            "recoveryAction" = "RecoverOneDrive";
            "recoverOneDriveParams" = @{
                "continueOnError" = $true;
                "objects" = @(
                    @{
                        "oneDriveParams" = @(
                            @{
                                "name" = $userObj.name;
                                "recoverEntireDrive" = $false;
                                "recoverItems" = @(
                                    @{
                                        "isFile" = $isFile;
                                        "itemPath" = "$filePath"
                                    }
                                )
                            }
                        );
                        "ownerInfo" = @{
                            "snapshotId" = $snap.objectSnapshotid
                        }
                    }
                )
            }
        }
    }
    if($targetFolder -or $targetUser){
        $recoveryParams.office365Params.recoverOneDriveParams['targetDrive'] = @{
            "targetFolderPath" = "/";
            "id" = $targetUserObj.id;
            "name" = $targetUseObj.name;
            "parentSourceId" = $targetUserObj.sourceId
        }
        if($targetFolder){
            $recoveryParams.office365Params.recoverOneDriveParams.targetDrive.targetFolderPath = $targetFolder
        }
    }
    Write-Host "Recovering $filePath"
    $recovery = api post -v2 "data-protect/recoveries" $recoveryParams
}
