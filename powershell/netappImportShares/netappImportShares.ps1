### usage:
# .\netappImportShares.ps1 -vip mycluster `
#                          -username myusername `
#                          -domain mydomain.net `
#                          -importFile .\netappShares.json `
#                          -netappSource mynetapp `
#                          -volumeName vol1, vol2 `
#                          -viewPrefix ntap- `
#                          -restrictVolumeSharePermissions 'mydomain.net\domain admins', 'mydomain.net\storage admins'

### process commandline arguments
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
    [Parameter(Mandatory = $True)][string]$importFile, # path to Netapp import file
    [Parameter(Mandatory = $True)][string]$netappSource, # name of the Netapp protection source
    [Parameter()][array]$volumeName, # name(s) of volumes(s) to recover
    [Parameter()][array]$restrictVolumeSharePermissions, # list of full control groups for root volumes
    [Parameter()][string]$volumeList = $null, # file list of volumes to recover
    [Parameter()][string]$viewPrefix = '', # prefix to apply to volume-level views
    [Parameter()][string]$sharePrefix = '', # prefix to apply to shares within views
    [Parameter()][array]$exclude, # skip creating shares that match these substrings
    [Parameter()][switch]$copySharePermissions,
    [Parameter()][switch]$smbOnly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Cohesity cluster
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

function addPermission($user, $perms){
    $sid = getSid $user
    #"visible" = $True;
    if($sid){
        $permission = @{       
            "sid" = $sid;
            "type" = "Allow";
            "mode" = "FolderOnly"
            "access" = $perms
        }
        return $permission
    }else{
        Write-Warning "User $user not found"
        exit 1
    }
}

$cluster = api get cluster

# gather list of volumes to recover
$volumes = @()
foreach($v in $volumeName){
    $volumes += $v
}
if ($volumeList){
    if(Test-Path -Path $volumeList -PathType Leaf){
        $vlist = Get-Content $volumeList
        foreach($v in $vlist){
            $volumes += $v
        }
    }else{
        Write-Warning "Volume list $volumeList not found!"
        exit 1
    }
}

$volumesToRecover = @()
$recoveredVolumes = @()

# get import file
if($importFile -and (Test-Path -Path $importFile -PathType Leaf)){
    $netappShares = Get-Content -Path $importFile | ConvertFrom-Json
}else{
    Write-Host "Import file $importFile not found!" -ForegroundColor Yellow
    exit
}

# enumerate netappVolumes
foreach($netappShare in $netappShares | Where-Object Path -ne '/'){
    
    $volumeName = $netappShare.Path.Split('/')[1]
    $altVolumeName = $netappShare.Path.Split('/')[2]
    if(($volumeName -in $volumes -or $volumes.Length -eq 0) -and $volumeName -ne "vol"){
        $volumesToRecover += $volumeName
    }
    if($volumeName -eq "vol" -and ($altVolumeName -in $volumes -or $volumes.Length -eq 0)){
       $volumesToRecover += $altVolumeName
    }
}
$volumesToRecover = $volumesToRecover | Sort-Object -Unique

# get AD and view info from Cohesity
$ads = api get activeDirectory
$sids = @{}
$views = api get views
$users = api get users?domain=LOCAL
$groups = api get groups?domain=LOCAL

# resolve sid function
function getSid($principalName){
    $sid = $null
    # already have this sid in the cache
    if($sids.ContainsKey($principalName)){
        $sid = $sids[$principalName]
    }else{
        if($principalName -eq 'Everyone'){
            $sid = 'S-1-1-0'
            $sids[$principalName] = $sid
        }elseif($principalName.contains('\')){
            $workgroup, $user = $principalName.split('\')
            if($workgroup -eq 'BUILTIN'){
                if($user -in @($groups.name)){
                    $sid = ($groups | Where-Object {$_.name -eq $user}).sid
                    $sids[$principalName] = $sid
                }elseif($user -in @($users.username)){
                    $sid = ($users | Where-Object {$_.username -eq $user}).sid
                    $sids[$principalName] = $sid
                }
            }else{
                # find domain
                $adDomain = $ads | Where-Object { $_.workgroup -eq $workgroup -or $_.domainName -eq $workgroup}
                if(!$adDomain){
                    write-host "domain $workgroup not found!" -ForegroundColor Yellow
                }else{
                    # find domain princlipal/sid
                    $domainName = $adDomain.domainName
                    $principal = api get "activeDirectory/principals?domain=$($domainName)&includeComputers=true&search=$($user)"
                    if(!$principal){
                        write-host "user $($permission.account) not found!" -ForegroundColor Yellow
                    }else{
                        $sid = $principal[0].sid
                        $sids[$principalName] = $sid
                    }
                }
            }
        }else{
            # find local or wellknown sid
            $principal = api get "activeDirectory/principals?domain=$($ads[0].domainName)&includeComputers=true&search=$principalName"
            if(!$principal){
                # write-host "user $($principalName) not found!" -ForegroundColor Yellow
                $sids[$principalName] = $null
            }else{
                $sid = $principal[0].sid
                $sids[$principalName] = $sid
            }
        }
    }
    if($principalName -notin $sids.Keys -or $sids[$principalName] -eq $null){
        Write-Host "User $($principalName) not found!" -ForegroundColor Yellow
        return $null
    }
    return  $sids[$principalName]
}

# recover netapp volumes as views
foreach($volumeName in $volumesToRecover){

    $newViewName = "$viewPrefix$volumeName$"
    $existingView = $views.views | Where-Object name -eq $newViewName
    if(! $existingView){
        # migrate the netapp volume
        $searchResult = api get "/searchvms?entityTypes=kNetapp&vmName=$volumeName"
        $viewResult = $searchResult.vms | Where-Object {$_.vmDocument.objectName -eq $volumeName -and $_.vmDocument.registeredSource.displayName -eq $netappSource}
        $viewResult = $viewResult | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False}
        if($viewResult){
            $v = $viewResult[0].vmDocument
            $restoreParams = @{
                "name"                  = "Recover-NetApp_$newViewName";
                "objects"               = @(
                    @{
                        "jobId"              = $v.objectId.jobId;
                        "jobUid"             = @{
                            "clusterId"            = $v.objectId.jobUid.clusterId;
                            "clusterIncarnationId" = $v.objectId.jobUid.clusterIncarnationId;
                            "id"                   = $v.objectId.jobUid.objectId
                        };
                        "jobRunId"           = $v.versions[0].instanceId.jobInstanceId;
                        "startedTimeUsecs"   = $v.versions[0].instanceId.jobStartTimeUsecs;
                        "protectionSourceId" = $v.objectId.entity.id
                    }
                );
                "type"                  = "kMountFileVolume";
                "viewName"              = $newViewName;
                "restoreViewParameters" = @{
                    "qos" = @{
                        "principalName" = "TestAndDev High"
                    }
                }
            }
            write-host "Migrating $netappSource/$volumeName to $newViewName"
            $null = api post restore/recover $restoreParams
            $recoveredVolumes += $volumeName
        }else{
            # we're not protecting this volume
            write-host "Volume $volumeName not found" -ForegroundColor Yellow
        }
    }else{
        # already migrated this volume
        write-host "View $newViewName already migrated"
        $recoveredVolumes += $volumeName
    }
}

Start-Sleep -Seconds 5

# set properties of migrated volume views
$views = api get -v2 file-services/views
foreach($volumeName in $recoveredVolumes){
    $newViewName = "$viewPrefix$volumeName$"
    $view = $views.views | Where-Object name -eq $newViewName
    if($view){
        $view | setApiProperty -name category -value 'FileServices'
        delApiProperty -object $view -name nfsMountPaths
        $view | setApiProperty -name enableSmbViewDiscovery -value $True
        delApiProperty -object $view -name versioning
        if($smbOnly){
            $view.protocolAccess = @(
                @{
                    "type" = "SMB";
                    "mode" = "ReadWrite"
                }
            )
        }
        if($restrictVolumeSharePermissions.Length -ne 0){
            $sharePermissions = @()
            foreach($principalName in $restrictVolumeSharePermissions){
                $sharePermissions += addPermission $principalName
            }
            if($cluster.clusterSoftwareVersion -gt '6.6'){
                $view.sharePermissions | setApiProperty -name permissions -value $sharePermissions
            }else{
                $view | setApiProperty -name sharePermissions -value @($sharePermissions)
            }
        }
        $null = api put -v2 file-services/views/$($view.viewId) $view
    }
}

# create shares
$shares = api get shares

foreach($netappShare in $netappShares | Where-Object {$_.ShareName -ne "/$($_.Path)" -and $_.Path -ne '/'}){
    $shareName = "$sharePrefix$($netappShare.shareName)"
    # skip if shareName matches excludes
    $skip = $false
    foreach($ex in $exclude){
        if($netappShare.shareName -match $ex){
            $skip = $True
        }
    }

    $volumeName = $netappShare.Path.Split('/')[1]
    # skip if volume was not migrated
    if($volumeName -in $recoveredVolumes){
        if($skip){
            "** Skipping share $($netappShare.shareName)..."
        }else{
            $newViewName = "$viewPrefix$volumeName$"
            $relativePath = "/$($netappShare.Path.split('/',3)[2])"
            
            if($relativePath -and $shareName -ne $newViewName -and $shareName -notin $shares.sharesList.shareName){
                $shareParams = @{
                    "viewName"         = $newViewName;
                    "viewPath"         = "$relativePath";
                    "aliasName"        = "$shareName"
                }
        
                if($copySharePermissions){
                    $shareParams["sharePermissions"] = @()
                    $acl = $netappShare.Acl
                    foreach($ace in $acl){
                        $principalName, $permission = $ace.split('/')
                        $principalName = $principalName.Trim()
                        $permission = $permission.Trim()
                        $sid = getSid $principalName
                        # Write-Host "    $principalName ($sid)"
                        if($sid){
                            $shareParams["sharePermissions"] += @{
                                "visible" = $true;
                                "sid"    = $sid;
                                "access" = $permission.replace('Full Control', 'kFullControl').replace('Read', 'kReadOnly').replace('Change', 'kModify');
                                "type"   = "kAllow";
                                "mode" = "kFolderSubFoldersAndFiles"
                            }
                        }
                    }
                }
        
                "Sharing {0}{1} as {2}" -f $newViewName, $relativePath, $shareName
                $null = api post viewAliases $shareParams
            }
        }
    }
}
