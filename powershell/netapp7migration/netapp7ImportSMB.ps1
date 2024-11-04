### usage:
# .\netapp7ImportSMB.ps1 -vip mycluster `
#                        -username myusername `
#                        -domain mydomain.net `
#                        -controllerName mynetapp.mydomain.net `
#                        -shareNames share1, share2 `
#                        -viewPrefix ntap-

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,      # the Cohesity cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username (local or AD)
    [Parameter()][string]$domain = 'local',          # local or AD domain
    [Parameter(Mandatory = $True)][string]$controllerName, # name of the Netapp controller
    [Parameter()][array]$shareNames,                 # names of shares(s) to recover (comma separated)
    [Parameter()][string]$shareList = $null,         # text list of shares to recover (one per line)
    [Parameter()][string]$viewPrefix = '',           # prefix to apply to views
    [Parameter()][string]$sharePrefix = '',          # prefix to apply to child shares
    [Parameter()][switch]$copySharePermissions,      # copy SMB share permissions
    [Parameter()][switch]$hideViews,                 # make views non-browsable with trailing $
    [Parameter()][switch]$allShares                  # recover all protected netapp shares
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Cohesity cluster
apiauth -vip $vip -username $username -domain $domain

# gather list of shares to recover
$shares = @()
foreach($s in $shareNames){
    $shares += [string]$s
}
if ($shareList){
    if(Test-Path -Path $shareList -PathType Leaf){
        $slist = Get-Content $shareList
        foreach($s in $slist){
            $shares += [string]$s
        }
    }else{
        Write-Warning "Share list $shareList not found!"
        exit 1
    }
}

if($shares.count -eq 0 -and !$allShares){
    Write-Host "No shares selected for recovery" -ForegroundColor Yellow
    exit 1
}

# get import files
if(Test-Path -Path "$controllerName-shares.json" -PathType Leaf){
    $netappShares = Get-Content -Path "$controllerName-shares.json" | ConvertFrom-Json
}else{
    Write-Host "Export file $controllerName-shares.json not found!" -ForegroundColor Yellow
    exit 1
}

if(Test-Path -Path "$controllerName-acls.json" -PathType Leaf){
    $netappAcls = Get-Content -Path "$controllerName-acls.json" | ConvertFrom-Json
}else{
    Write-Host "Export file $controllerName-acls.json not found!" -ForegroundColor Yellow
    exit 1
}

function findSnapshot($controllerName, $share){
    $volumeName = "\\$controllerName\$share"
    $encodedVolumeName = [System.Web.HttpUtility]::UrlEncode($volumeName)
    $searchResult = api get "/searchvms?entityTypes=kGenericNas&vmName=$encodedVolumeName"
    $searchResult = $searchResult.vms | Where-Object {$_.vmDocument.objectName -eq $volumeName}
    if(! $searchResult){
        return $null
    }
    $searchResult = ($searchResult | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]
    return $searchResult.vmDocument
}

# get AD and view info from Cohesity
$ads = api get activeDirectory
$sids = @{}
$views = getViews

# resolve sid function
function getSid($principalName){
    $sid = $null
    # already have this sid in the cache
    if($sids.ContainsKey($principalName)){
        $sid = $sids[$principalName]
    }else{
        if($principalName.contains('\')){
            $workgroup, $user = $principalName.split('\')
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
        }else{
            # find local or wellknown sid
            $principal = api get "activeDirectory/principals?includeComputers=true&search=$principalName"
            if(!$principal){
                write-host "user $($principalName) not found!" -ForegroundColor Yellow
                $sids[$principalName] = $null
            }else{
                $sid = $principal[0].sid
                $sids[$principalName] = $sid
            }
        }
    }
    return  $sids[$principalName]
}

$recoveredVolumes = @()

# gather mounts to recover as views
$netappShares = $netappShares | Where-Object {$_.MountPoint -match '/vol'} | Sort-Object -Property {$_.MountPoint.length} -Descending:$true

"Recovering Protected (Parent) Shares..."

foreach($netappShare in $netappShares){
    # if share is selected for recovery
    if($netappShare.shareName -in $shares -or $allShares){
        # get snapshot
        $snapshot = findSnapshot $controllerName $netappShare.shareName
        if($snapshot){
            # assemble new view name
            $newViewName = "$viewPrefix$($netappShare.shareName)"
            if($hideViews){
                $newViewName = "$newViewName`$"
            }
            $existingView = $views | Where-Object name -eq $newViewName
            # if new view doesn't already exist, create the view
            if(! $existingView){
                $restoreParams = @{
                    "name"                  = "Recover-NetApp_$newViewName";
                    "objects"               = @(
                        @{
                            "jobId"              = $snapshot.objectId.jobId;
                            "jobUid"             = @{
                                "clusterId"            = $snapshot.objectId.jobUid.clusterId;
                                "clusterIncarnationId" = $snapshot.objectId.jobUid.clusterIncarnationId;
                                "id"                   = $snapshot.objectId.jobUid.objectId
                            };
                            "jobRunId"           = $snapshot.versions[0].instanceId.jobInstanceId;
                            "startedTimeUsecs"   = $snapshot.versions[0].instanceId.jobStartTimeUsecs;
                            "protectionSourceId" = $snapshot.objectId.entity.id
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
                write-host "    Migrating $controllerName/$($netappShare.shareName) to $newViewName" -ForegroundColor Green
                $null = api post restore/recover $restoreParams
            }else{
                # view already exists
                write-host "    $controllerName/$($netappShare.shareName) already migrated" -ForegroundColor Cyan
            }
            $recoveredVolumes += @{'viewName' = $newViewName; 'mountPoint' = $netappShare.MountPoint; 'shareName' = $netappShare.shareName}
        }else{
            # mount not backed up
            write-host "    $controllerName/$($netappShare.shareName) not backed up" -ForegroundColor Magenta
        }
    }
}

Start-Sleep -Seconds 2

# set properties of migrated views
$views = getViews
foreach($recoveredVolume in $recoveredVolumes){
    $newViewName = $recoveredVolume.viewName
    $view = $views | Where-Object name -eq $newViewName
    if($view){
        # set smb browsable
        $view.protocolAccess = 'kSMBOnly'
        if($view.PSObject.properties['enableSmbViewDiscovery']){
            $view.enableSmbViewDiscovery = $True
        }else{
            setApiProperty -obj $view -name 'enableSmbViewDiscovery' -value $True
        }
        # set share-level permissions
        $acl = $netappAcls | Where-Object ShareName -eq $recoveredVolume.shareName
        if($copySharePermissions){
            $view.sharePermissions = @()
            foreach($ace in $acl.UserAclInfo){
                $principalName = $ace.UserName
                $permission = $ace.AccessRights
                $sid = getSid $principalName
                if($sid){
                    $view.sharePermissions += @{
                        "visible" = $true;
                        "sid"    = $sid;
                        "access" = $permission.replace('Full Control', 'kFullControl').replace('Read', 'kReadOnly').replace('Change', 'kModify');
                        "type"   = "kAllow"
                    }
                }
            }
        }
        $null = api put views $view
    }    
}

"Recovering Child Shares..."

# create child shares
$shares = api get shares
$recoveredShares = @()

foreach($netappShare in $netappShares){
    # skip parent shares
    if($netappShare.MountPoint -notin $recoveredVolumes.mountPoint){
        # choose closest ancestor
        foreach($recoveredVolume in $recoveredVolumes | Sort-Object -Property {$_.mountPoint.length} -Descending){
            $recoveredMountPoint = $recoveredVolume.mountPoint
            $newViewName = $recoveredVolume.viewName
            # is this share a decendent of the ancestor
            if($netappShare.MountPoint -match $recoveredMountPoint -and $netappShare.shareName -notin $recoveredShares){
                $shareName = "$sharePrefix$($netappShare.shareName)"
                if($shareName -notin $shares.sharesList.shareName){
                    # create share
                    $relativePath = ($netappShare.MountPoint -split $recoveredMountPoint)[1]
                    $shareParams = @{
                        "viewName"         = $newViewName;
                        "viewPath"         = "$relativePath";
                        "aliasName"        = "$shareName"
                    }
                    # set share-level permissions
                    if($copySharePermissions){
                        $shareParams["sharePermissions"] = @()
                        $acl = $netappAcls | Where-Object ShareName -eq $netappShare.shareName
                        foreach($ace in $acl.UserAclInfo){
                            $principalName = $ace.UserName
                            $permission = $ace.AccessRights
                            $sid = getSid $principalName
                            if($sid){
                                $shareParams.sharePermissions += @{
                                    "visible" = $true;
                                    "sid"    = $sid;
                                    "access" = $permission.replace('Full Control', 'kFullControl').replace('Read', 'kReadOnly').replace('Change', 'kModify');
                                    "type"   = "kAllow"
                                }
                            }
                        }
                    }
                    write-host ("    Sharing {0}{1} as {2}" -f $newViewName, $relativePath, $shareName) -ForegroundColor Green
                    $null = api post viewAliases $shareParams
                }else{
                    Write-Host "    Share $shareName already exists" -ForegroundColor Cyan
                }
                $recoveredShares += $netappShare.shareName
            }
        }
    }
}
