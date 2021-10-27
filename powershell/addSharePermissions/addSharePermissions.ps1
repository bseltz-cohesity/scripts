### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter(Mandatory = $True)][string]$shareName,
   [Parameter()][array]$fullControl,                 # list of users to grant full control
   [Parameter()][array]$readWrite,                   # list of users to grant read/write
   [Parameter()][array]$readOnly,                    # list of users to grant read-only
   [Parameter()][array]$modify                       # list of users to grant modify
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

function newPermission($user, $perms, $shareName){
    $domain, $domainuser = $user.split('\')
    Write-Host "Granting '$user' $($perms.subString(1)) to '$shareName'"
    $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
    if($principal){
        $permission = @{
            "sid" = $principal.sid;
            "type" = "kAllow";
            "access" = $perms
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
    $thisView = api get views/$($share.viewName)
    if(!$thisView.Properties['sharePermissions']){
        setApiProperty -object $thisView -name 'permissions' -value @()
    }
}else{
    setApiProperty -object $share -name 'aliasName' -value $share.shareName
    if(!$share.PSObject.Properties['sharePermissions']){
        setApiProperty -object $share -name 'sharePermissions' -value @()        
    }
}

foreach($user in $readWrite){
    $permission = newPermission $user 'kReadWrite' $shareName
    $new = $True
    if($isView -eq $True){
        foreach($perm in $view.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $thisView.sharePermissions = @($thisView.sharePermissions + $permission)
        }
    }else{
        foreach($perm in $share.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $share.sharePermissions = @($share.sharePermissions + $permission)
        }
    }
}

foreach($user in $fullControl){
    $permission = newPermission $user 'kFullControl' $shareName
    $new = $True
    if($isView -eq $True){
        foreach($perm in $view.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $thisView.sharePermissions = @($thisView.sharePermissions + $permission)
        }     
    }else{
        foreach($perm in $share.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $share.sharePermissions = @($share.sharePermissions + $permission)
        }
    }
}

foreach($user in $readOnly){
    $permission = newPermission $user 'kReadOnly' $shareName
    $new = $True
    if($isView -eq $True){
        foreach($perm in $view.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $thisView.sharePermissions = @($thisView.sharePermissions + $permission)
        }
    }else{
        foreach($perm in $share.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $share.sharePermissions = @($share.sharePermissions + $permission)
        }
    }
}

foreach($user in $modify){
    $permission = newPermission $user 'kModify' $shareName
    $new = $True
    if($isView -eq $True){
        foreach($perm in $view.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $thisView.sharePermissions = @($thisView.sharePermissions + $permission)
        }
    }else{
        foreach($perm in $share.sharePermissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.access -eq $permission.access){
                   $new = $false
            }
        }
        if($new -eq $True){
            $share.sharePermissions = @($share.sharePermissions + $permission)
        }
    }
}

if($isView -eq $True){
    $null = api put views/$shareName $thisView 
}else{
    $null = api put viewAliases $share
}

