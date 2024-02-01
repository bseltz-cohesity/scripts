### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter(Mandatory = $True)][string]$viewName,
   [Parameter()][array]$fullControl,  # list of users to grant full control
   [Parameter()][array]$readWrite,    # list of users to grant read/write
   [Parameter()][array]$readOnly,     # list of users to grant read-only
   [Parameter()][array]$modify        # list of users to grant modify
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

function newPermission($user, $perms, $view){
    $domain, $domainuser = $user.split('\')
    Write-Host "Granting '$user' $($perms.subString(1)) to '$($view.name)'"
    $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
    if($principal){
        $permission = @{
            "sid" = $principal.sid;
            "type" = "kAllow";
            "mode" = "kFolderSubFoldersAndFiles";
            "access" = $perms
        }
        $new = $True
        foreach($perm in $view.smbPermissionsInfo.permissions){
            if($perm.sid -eq $permission.sid -and
               $perm.type -eq $permission.type -and
               $perm.mode -eq $permission.mode -and
               $perm.access -eq $permission.access){
                   $new = $false
               }
        }
        if($new -eq $True){
            return $permission
        }else{
            return $null
        }
        
    }else{
        Write-Warning "User $user not found"
        exit 1
    }    
}

$principals = @{'S-1-1-0' = 'Everyone'}
function principalName($sid){
    if($principals[$sid]){
        $principalName = $principals[$sid]
    }else{
        $principal = api get principals/searchPrincipals?sids=$($sid)
        $principalName = $principal.principalName
        if($principal.PSObject.Properties['domain']){
            $principalName = "$($principal.domain)\$principalName"
        }
        if(!$principalName){
            $principalName = $sid
        }
        $principals[$sid] = $principalName
    }
    return $principalName
}

$thisView = api get views/$viewName

if($thisView){

    if(!$thisView.PSObject.Properties['smbPermissionsInfo']){
        setApiProperty -object $thisView -name 'smbPermissionsInfo' -value  @{"ownerSid" = "S-1-5-32-544"}        
    }

    if(!$thisView.smbPermissionsInfo.PSObject.Properties['permissions']){
        setApiProperty -object $thisView.smbPermissionsInfo -name 'permissions' -value @()
    }

    foreach($user in $readWrite){
        $permission = newPermission $user 'kReadWrite' $thisView
        if($permission){
            $thisView.smbPermissionsInfo.permissions = @($thisView.smbPermissionsInfo.permissions + $permission)
        }
    }
    
    foreach($user in $fullControl){
        $permission = newPermission $user 'kFullControl' $thisView
        if($permission){
            $thisView.smbPermissionsInfo.permissions = @($thisView.smbPermissionsInfo.permissions + $permission)
        }
    }
    
    foreach($user in $readOnly){
        $permission = newPermission $user 'kReadOnly' $thisView
        if($permission){
            $thisView.smbPermissionsInfo.permissions = @($thisView.smbPermissionsInfo.permissions + $permission)
        }
    }
    
    foreach($user in $modify){
        $permission = newPermission $user 'kModify' $thisView
        if($permission){
            $thisView.smbPermissionsInfo.permissions = @($thisView.smbPermissionsInfo.permissions + $permission)
        }
    }
    
    $null = api put views/$($view.name) $thisView

    $thisView.smbPermissionsInfo.permissions | Format-Table -Property type, mode, access, @{label='principal'; expression={principalName $_.sid}}
}
