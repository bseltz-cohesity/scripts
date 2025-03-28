# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][string]$viewName,
    [Parameter()][array]$fullControl,
    [Parameter()][array]$readWrite,
    [Parameter()][array]$readOnly,
    [Parameter()][array]$modify,
    [Parameter()][array]$ips,
    [Parameter()][string]$ipList,
    [Parameter()][switch]$rootSquash,
    [Parameter()][switch]$allSquash,
    [Parameter()][switch]$ipsReadOnly,
    [Parameter()][switch]$showVersions,
    [Parameter()][int64]$runId,
    [Parameter()][switch]$wait,
    [Parameter()][int64]$sleepTime=5,
    [Parameter()][switch]$migrateSMBPermissions,
    [Parameter()][switch]$migrateChildShares
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

### get AD info
$ads = api get activeDirectory
$sids = @{}

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

$ipsToAdd = @(gatherList -Param $ips -FilePath $ipList -Name 'IPs' -Required $False)

function getSid($user){
    if($user -eq 'Everyone'){
        $sid = 'S-1-1-0'
    }elseif($user.contains('\')){
        $workgroup, $user = $user.split('\')
        # find domain
        $adDomain = $ads | Where-Object { $_.workgroup -eq $workgroup -or $_.domainName -eq $workgroup}
        if(!$adDomain){
            write-host "domain $workgroup not found!" -ForegroundColor Yellow
            exit 1
        }else{
            # find domain princlipal/sid
            $domainName = $adDomain.domainName
            $principal = api get "activeDirectory/principals?domain=$($domainName)&includeComputers=true&search=$($user)"
            if(!$principal){
                write-host "Principal ""$($workgroup)\$($user)"" not found!" -ForegroundColor Yellow
            }else{
                $sid = $principal[0].sid
                $sids[$user] = $sid
            }
        }
    }else{
        # find local or wellknown sid
        $principal = api get "activeDirectory/principals?includeComputers=true&search=$($user)"
        if(!$principal){
            write-host "Principal ""$($user)"" not found!" -ForegroundColor Yellow
        }else{
            $sid = $principal[0].sid
            $sids[$user] = $sid
        }
    }
    if($sid){
        return $sid
    }else{
        return $null
    }
}

function addPermission($user, $perms){
    $sid = getSid $user
    if($null -ne $sid){
        $permission = @{       
            "sid" = $sid;
            "type" = "Allow";
            "mode" = "FolderSubFoldersAndFiles"
            "access" = $perms
        }
        return $permission
    }else{
        return $null
    }
}

function addAliasPermission($user, $acl){
    $sid = getSid $user
    if($null -ne $sid){
        $newPermission = @{
            "type"    = "k$($acl.AccessControlType.ToString())";
            "access"  = $acl.AccessRight.ToString().replace('Full', 'kFullControl').replace('Read', 'kReadOnly').replace('Change', 'kModify');
            "sid"     = $sid
        }
        return $newPermission
    }else{
        retun $null
    }
}

function newWhiteListEntry($cidr, $perm){
    $ip, $netbits = $cidr -split '/'
    if(! $netbits){
        $netbits = '32'
    }

    $whitelistEntry = @{
        "nfsAccess" = $perm;
        "smbAccess" = $perm;
        "s3Access" = $perm;
        "ip"            = $ip;
        "netmaskBits"    = [int]$netbits;
        "description" = ''
    }
    if($allSquash){
        $whitelistEntry['nfsAllSquash'] = $True
    }
    if($rootSquash){
        $whitelistEntry['nfsRootSquash'] = $True
    }
    return $whitelistEntry
}

function applyViewSettings(){
    $updateView = $False
    $newView = (api get -v2 "file-services/views?viewNames=$viewName").views | Where-Object { $_.name -eq $viewName }
    $newView | setApiProperty -name category -value 'FileServices'
    delApiProperty -object $newView -name nfsMountPaths
    $newView | setApiProperty -name enableSmbViewDiscovery -value $True
    delApiProperty -object $newView -name versioning
    $newView.protocolAccess = @(
        @{
            "type" = "SMB";
            "mode" = "ReadWrite"
        }
    )
    $newView.sharePermissions | setApiProperty -name permissions -value $sharePermissions
    if($ipsToAdd.Count -gt 0){
        setApiProperty -object $newView -name 'subnetWhitelist' -value @()
        $perm = 'kReadWrite'
        if($readOnly){
            $perm = 'kReadOnly'
        }
        foreach($cidr in $ipsToAdd){
            $ip, $netbits = $cidr -split '/'
            $newView.subnetWhitelist = @($newView.subnetWhiteList | Where-Object ip -ne $ip)
            $newView.subnetWhitelist = @($newView.subnetWhiteList +(newWhiteListEntry $cidr $perm))
        }
        $newView.subnetWhiteList = @($newView.subnetWhiteList | Where-Object {$_ -ne $null})
    }
    $null = api put -v2 file-services/views/$($newView.viewId) $newView
    # migrate SMB Permissions
    $smbShare = $null
    if($migrateSMBPermissions){
        $sharePermissions = @()
        $shareName = ($sourceName -split '\\')[-1]
        $smbShares = Get-SMBShare
        $smbShare = $smbShares | Where-Object name -eq $shareName
        if(!$smbShare){
            Write-Host "Can't find share $shareName on this Windows server" -ForegroundColor Yellow
            exit 1
        }
        # get permissions
        Write-Host "Migrating SMB Permissions"
        $acls = $smbShare | Get-SmbShareAccess
        foreach($acl in $acls){
            $perm = $acl.AccessRight.ToString().replace('Full', 'FullControl').replace('Read', 'ReadOnly').replace('Change', 'Modify')
            $user = $acl.AccountName
            $newPermission = addPermission $user $perm
            if($null -ne $newPermission){
                $sharePermissions += addPermission $user $perm
            }
        }
        $newView.sharePermissions.permissions = $sharePermissions
        $null = api put -v2 file-services/views/$($newView.viewId) $newView
    }
    # migrate child shares
    if($migrateChildShares){
        if($null -eq $smbShare){
            $shareName = ($sourceName -split '\\')[-1]
            $smbShares = Get-SMBShare
            $smbShare = $smbShares | Where-Object name -eq $shareName
            if(!$smbShare){
                Write-Host "Can't find share $shareName on this Windows server" -ForegroundColor Yellow
                exit 1
            }
        }
        $smbSharePath = $smbShare.Path.Replace('\','/').Replace(':','')
        $childShares = $smbShares | Where-Object {"$($_.Path.Replace('\','/').replace(':',''))" -match $smbSharePath -and $_.Name -ne $shareName}
        foreach($childShare in $childShares){
            Write-Host "Creating child share $($childShare.Name)"
            $childSharePath = $childShare.Path.Replace('\','/').replace(':','')
            $relativePath = $childSharePath.Replace($smbSharePath,'')
            $aliasParams = @{
                "viewName"         = $newView.name;
                "viewPath"         = "$($relativePath)/";
                "aliasName"        = $childShare.Name;
                "sharePermissions" = @()
            }
            $acls = $childShare | Get-SmbShareAccess
            foreach($acl in $acls){
                $user = $acl.AccountName
                $newPermission = addAliasPermission $user $acl
                if($null -ne $newPermission){
                    $aliasParams.sharePermissions += $newPermission
                }
            }
            $null = api post viewAliases $aliasParams
        }        
    }
}

# find source volume
$search = api get -v2 "data-protect/search/protected-objects?snapshotActions=RecoverNasVolume,RecoverSanVolumes&searchString=$sourceName&environments=kNetapp,kIsilon,kGenericNas,kFlashBlade,kGPFS,kElastifile,kPure" # ,kIbmFlashSystem" # &filterSnapshotToUsecs=1720497599999000&filterSnapshotFromUsecs=1719892800000000
$objects = $search.objects | Where-Object {$_.name -eq $sourceName}
if(!$objects){
    Write-Host "NAS volume $sourceName not found" -ForegroundColor Yellow
    exit 1
}

# find snapshots
$allSnapshots = @()
foreach($object in $objects){
    $snapshots = api get -v2 "data-protect/objects/$($object.id)/snapshots?protectionGroupIds=$($object.latestSnapshotsInfo[0].protectionGroupId)"
    if($null -ne $snapshots){
        $allSnapshots = @($allSnapshots + $snapshots.snapshots)
    }
}
if($allSnapshots.Count -eq 0){
    Write-Host "No snapshots found for $sourceName"
    exit 1
}

if($showVersions){
    $allSnapshots | Format-Table -Property @{label='runId'; expression={$_.runInstanceId}}, @{label='runDate'; expression={usecsToDate $_.runStartTimeUsecs}}, snapshotTargetType
    exit
}

# select snapshot
$allSnapshotGroups = $allSnapshots | Group-Object -Property runInstanceId
if($runId){
    $thisSnapshotGroup = @($allSnapshotGroups | Where-Object {$_.name -eq $runId})
    if(! $thisSnapshotGroup){
        Write-Host "No snapshots found for $sourceName with runId $runId"
        exit 1
    }
}else{
    $thisSnapshotGroup = $allSnapshotGroups[-1]
}
$thisSnapshot = $thisSnapshotGroup.Group[0]
$restoreTaskName = "Recover_Storage_Volumes_$(get-date -UFormat '%b_%d_%Y_%H-%M%p')"

# recover as view
$sharePermissionsApplied = $False
$sharePermissions = @()

$wait = $True
$ads = api get activeDirectory
$sids = @{}
foreach($user in $readWrite){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'ReadWrite'
}
foreach($user in $fullControl){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'FullControl'
}
foreach($user in $readOnly){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'ReadOnly'
}
foreach($user in $modify){
    $sharePermissionsApplied = $True
    $sharePermissions += addPermission $user 'Modify'
}
if($sharePermissionsApplied -eq $False){
    $sharePermissions += addPermission "Everyone" 'FullControl'
}

if(!$viewName){
    $viewName = (($sourceName -split '\\')[-1] -split '/')[-1]
}
$recoveryParams = @{
    "name" = $restoreTaskName;
    "snapshotEnvironment" = $thisSnapshot.environment;
    "genericNasParams" = @{
        "objects" = @(
            @{
                "snapshotId" = $thisSnapshot.id
            }
        );
        "recoveryAction" = "RecoverNasVolume";
        "recoverNasVolumeParams" = @{
            "targetEnvironment" = "kView";
            "viewTargetParams" = @{
                "viewName" = $viewName;
                "qosPolicy" = @{
                    "id" = 6;
                    "name" = "TestAndDev High";
                    "priority" = "kHigh";
                    "weight" = 320;
                    "workLoadType" = "TestAndDev";
                    "minRequests" = 10;
                    "seqWriteSsdPct" = 100;
                    "seqWriteHydraPct" = 100
                }
            }
        }
    }
}

Write-Host "Recovering $sourceName"
$recovery = api post -v2 data-protect/recoveries $recoveryParams

# wait for restores to complete
$finishedStates = @('Canceled', 'Succeeded', 'Failed', 'SucceededWithWarning')
if(! $recovery.PSObject.Properties['id']){
    exit 1
}

if($wait){
    Write-Host "Waiting for recovery to complete..."
    do{
        Start-Sleep $sleepTime
        $recoveryTask = api get -v2 data-protect/recoveries/$($recovery.id)?includeTenants=true
        $status = $recoveryTask.status

    } until ($status -in $finishedStates)
    write-host "Recovery task finished with status: $status"
    if($status -in @('Failed', 'SucceededWithWarning')){
        if($recoveryTask.PSObject.Properties['messages'] -and $recoveryTask.messages.Count -gt 0){
            Write-Host "$($recoveryTask.messages[0])" -ForegroundColor Yellow
        }
    }
    if($status -eq 'Succeeded'){
        applyViewSettings
        exit 0
    }else{
        exit 1
    }
}
exit 0
