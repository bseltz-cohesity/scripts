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
    [Parameter(Mandatory = $True)][string]$vip, # the Cohesity cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$importFile, # path to Netapp import file
    [Parameter(Mandatory = $True)][string]$netappSource, # name of the Netapp protection source
    [Parameter()][array]$volumeName, # name(s) of volumes(s) to recover
    [Parameter()][array]$restrictVolumeSharePermissions, # list of full control groups for root volumes
    [Parameter()][string]$volumeList = $null, # file list of volumes to recover
    [Parameter()][string]$viewPrefix = '', # prefix to apply to volume-level views
    [Parameter()][string]$sharePrefix = '' # prefix to apply to shares within views
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Cohesity cluster
apiauth -vip $vip -username $username -domain $domain

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

# enumerate netappVolumes
foreach($netappShare in $netappShares | Where-Object Path -ne '/'){
    $volumeName = $netappShare.Path.Split('/')[1]
    if($volumeName -in $volumes -or $volumes.Length -eq 0){
        $volumesToRecover += $volumeName
    }
}
$volumesToRecover = $volumesToRecover | Sort-Object -Unique

# get AD and view info from Cohesity
$ads = api get activeDirectory
$sids = @{}
$views = api get views

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

# recover netapp volumes as views
foreach($volumeName in $volumesToRecover){
    $newViewName = "$viewPrefix$volumeName"
    $existingView = $views.views | Where-Object name -eq $newViewName
    if(!$existingView){
        # migrate the netapp volume
        $searchResult = api get "/searchvms?entityTypes=kNetapp&vmName=$volumeName"
        $viewResult = $searchResult.vms | Where-Object {$_.vmDocument.objectName -eq $volumeName -and $_.vmDocument.registeredSource.displayName -eq $netappSource}
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

Start-Sleep -Seconds 2

# set properties of migrated volume views
$views = api get views
foreach($volumeName in $recoveredVolumes){
    $newViewName = "$viewPrefix$volumeName"
    $view = $views.views | Where-Object name -eq $newViewName
    if($view){
        $view.protocolAccess = 'kSMBOnly'
        $view.enableSmbViewDiscovery = $True
        if($restrictVolumeSharePermissions.Length -ne 0){
            $view.sharePermissions = @()
            foreach($principalName in $restrictVolumeSharePermissions){
                $sid = getSid $principalName
                if($sid){
                    $view.sharePermissions += @{
                        "visible" = $true;
                        "sid"    = $sid;
                        "access" = "kFullControl";
                        "type"   = "kAllow"
                    }
                }
            }
        }
        $null = api put views $view
    }    
}

# create shares
$shares = api get shares

foreach($netappShare in $netappShares | Where-Object {$_.ShareName -ne "/$($_.Path)" -and $_.Path -ne '/'}){
    $shareName = "$sharePrefix$($netappShare.shareName)"
    $volumeName = $netappShare.Path.Split('/')[1]
    $newViewName = "$viewPrefix$volumeName"
    $relativePath = "/$($netappShare.Path.split('/',3)[2])"

    if($relativePath -and $shareName -ne $volumeName -and $shareName -notin $shares.sharesList.shareName){
        $shareParams = @{
            "viewName"         = $newViewName;
            "viewPath"         = "$relativePath";
            "aliasName"        = "$shareName";
            "sharePermissions" = @()
        }
        $acl = $netappShare.Acl
        foreach($ace in $acl){
            $principalName, $permission = $ace.split('/')
            $principalName = $principalName.Trim()
            $permission = $permission.Trim()
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
        "Sharing {0}{1} as {2}" -f $newViewName, $relativePath, $shareName
        $null = api post viewAliases $shareParams
    }
}
