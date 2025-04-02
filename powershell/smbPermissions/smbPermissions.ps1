### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter(Mandatory = $True)][string]$shareName,
    [Parameter()][array]$superUser,  # list of users to grant super user
    [Parameter()][array]$removeSuperUser,  # list of users to grant super user
    [Parameter()][array]$fullControl,  # list of users to grant full control
    [Parameter()][array]$readWrite,  # list of users to grant read/write
    [Parameter()][array]$readOnly,  # list of users to grant read-only
    [Parameter()][array]$modify,  # list of users to grant modify
    [Parameter()][array]$remove,  # list of users to remove
    [Parameter()][switch]$reset  # reset permissions to everyone full control
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

### get AD info
$ads = api get activeDirectory
$sids = @{}
$cluster = api get cluster

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

function newPermission($user, $perms, $shareName, $isView){
    $domain, $domainuser = $user.split('\')
    if($perms -eq 'remove'){
        Write-Host "Removing '$user' from '$shareName'"
    }else{
        Write-Host "Granting '$user' $($perms.subString(1)) for '$shareName'"
    }
    if($user -eq 'everyone'){
        $principal = @{'sid' = 'S-1-1-0'}
    }else{
        $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
    }
    $type = 'kAllow'
    if($isView){
        $type = 'Allow'
        $perms = $perms.subString(1)
    }
    if($principal){
        $permission = @{
            "sid" = $principal.sid;
            "type" = $type;
            "access" = $perms;
            "mode" = "FolderSubFoldersAndFiles"
        }
        return $permission
    }else{
        Write-Warning "User $user not found"
        exit 1
    }    
}

$shares = (api get shares).sharesList

$share = $shares | Where-Object shareName -eq $shareName

if(!$share){
    Write-Host "Share $shareName not found" -ForegroundColor Yellow
    exit
}

$isView = $false
if($share.shareName -eq $share.viewName){
    $isView = $True
    $share = (api get -v2 "file-services/views?viewNames=$($share.viewName)").views[0]
    if(!$share.PSObject.Properties['sharePermissions']){
        if($cluster.clusterSoftwareVersion -ge '6.6'){
            setApiProperty -object $share -name 'sharePermissions' -value @{"permissions" = @()}
        }else{
            setApiProperty -object $share -name 'sharePermissions' -value @()
        }
    }
}else{
    setApiProperty -object $share -name 'aliasName' -value $share.shareName
    if(!$share.PSObject.Properties['sharePermissions']){
        setApiProperty -object $share -name 'sharePermissions' -value @()        
    }
}

if($share.sharePermissions.PSObject.Properties['permissions']){
    $sharePermissions = $share.sharePermissions.permissions
}else{
    $sharePermissions = $share.sharePermissions
}

if($reset){
    $sharePermissions = @()
}

$permsAdded = 0

foreach($user in $readWrite){
    $permission = newPermission $user 'kReadWrite' $shareName $isView
    $sharePermissions = @($sharePermissions | Where-Object {$_.sid -ne $permission.sid})
    $sharePermissions = @($sharePermissions + $permission)
    $permsAdded += 1
}

foreach($user in $fullControl){
    $permission = newPermission $user 'kFullControl' $shareName $isView
    $sharePermissions = @($sharePermissions | Where-Object {$_.sid -ne $permission.sid})
    $sharePermissions = @($sharePermissions + $permission)
    $permsAdded += 1
}

foreach($user in $readOnly){
    $permission = newPermission $user 'kReadOnly' $shareName $isView
    $sharePermissions = @($sharePermissions | Where-Object {$_.sid -ne $permission.sid})
    $sharePermissions = @($sharePermissions + $permission)
    $permsAdded += 1
}

foreach($user in $modify){
    $permission = newPermission $user 'kModify' $shareName $isView
    $sharePermissions = @($sharePermissions | Where-Object {$_.sid -ne $permission.sid})
    $sharePermissions = @($sharePermissions + $permission)
    $permsAdded += 1
}

foreach($user in $remove){
    $permission = newPermission $user 'remove' $shareName $isView
    $sharePermissions = @($sharePermissions | Where-Object {$_.sid -ne $permission.sid})
}

if($reset -and $permsAdded -eq 0){
    Write-Host "Resetting share permissions for '$shareName'"
    $type = 'kAllow'
    $access = 'kFullControl'
    if($isView){
        $type = 'Allow'
        $access = 'FullControl'
    }
    $sharePermissions = @(
        @{
            "type" = $type;
            "mode" = "FolderSubFoldersAndFiles";
            "access" = $access;
            "sid" = "S-1-1-0"
        }
    )
}

$sharePermissions = @($sharePermissions | Where-Object {$_ -ne $null})

if($share.sharePermissions.PSObject.Properties['permissions']){
    $share.sharePermissions.permissions = $sharePermissions
}else{
    $share.sharePermissions = $sharePermissions
}

if($superUser.Count -gt 0){
    $superUserSids = @()
    foreach($sUser in $superUser){
        $sSid = getSid $sUser
        if($sSid){
            Write-Host "Granting ""$sUser"" Super User for $shareName"
            $superUserSids = @($superUserSids + $sSid)
        }
    }
    if($superUserSids.Count -gt 0){
        if($isView -eq $True){
            if($share.sharePermissions.PSObject.Properties['superUserSids'] -and $share.sharePermissions.superUserSids -ne $null){
                $share.sharePermissions.superUserSids = @($share.sharePermissions.superUserSids + $superUserSids | Sort-Object -Unique)
            }else{
                $share.sharePermissions | setApiProperty -name superUserSids -value @($superUserSids)
            }
        }else{
            if($share.PSObject.Properties['superUserSids'] -and $share.superUserSids -ne $null){
                $share.superUserSids = @($share.superUserSids + $superUserSids | Sort-Object -Unique)
            }else{
                $share | setApiProperty -name superUserSids -value @($superUserSids)
            }
        }
    }
}

if($removeSuperUser.Count -gt 0){
    $superUserSids = @()
    foreach($sUser in $removeSuperUser){
        $sSid = getSid $sUser
        if($sSid){
            Write-Host "Removing ""$sUser"" Super User from $shareName"
            $superUserSids = @($superUserSids + $sSid)
        }
    }
    if($superUserSids.Count -gt 0){
        if($isView -eq $True){
            if($share.sharePermissions.PSObject.Properties['superUserSids'] -and $share.sharePermissions.superUserSids -ne $null){
                $share.sharePermissions.superUserSids = @($share.sharePermissions.superUserSids | Where-Object {$_ -notin $superUserSids})
            }
        }else{
            if($share.PSObject.Properties['superUserSids'] -and $share.superUserSids -ne $null){
                $share.superUserSids = @($share.superUserSids | Where-Object {$_ -notin $superUserSids})
            }
        }
    }
}

if($isView -eq $True){
    $null = api put -v2 "file-services/views/$($share.viewId)" $share 
}else{
    $null = api put viewAliases $share
}
