### usage: ./createShares.ps1 -vip mycluster -username myusername -domain mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

$ignoreShares = @('ADMIN$', 'IPC$', 'print$')

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get views and shares
$views = api get views
$shares = api get shares

### get AD info
$ads = api get activeDirectory
$sids = @{}

# get local smb shares
$smbShares = get-smbshare | Where-Object name -notin $ignoreShares | Where-Object name -notlike '?$'

foreach($smbShare in $smbShares){
    $driveLetter, $viewName, $folderPath = $smbShare.Path.Split('\',3)
    $folderPath = "/$folderPath".replace('\', '/')
    $view = $views.views | Where-Object name -eq $viewName
    $share = $shares.sharesList | Where-Object {$_.sharename -eq $smbShare.name -and $_.viewName -eq $viewName}
    # if view exists
    if($view){
        # is this a view or a viewAlias
        if($viewName -eq $smbShare.name){
            $isView = $True
            $viewParams = $view
            $viewParams.sharePermissions = @()
        }else{
            $isView = $false
            $viewParams = @{
                "viewName"         = $viewName;
                "viewPath"         = $folderPath;
                "aliasName"        = $smbShare.name;
                "sharePermissions" = @()
            }
        }

        # get permissions
        $acls = $smbShare | Get-SmbShareAccess
        foreach($acl in $acls){
            $sid = $null
            if($sids.ContainsKey($acl.AccountName)){
                $sid = $sids[$acl.AccountName]
            }else{
                if($acl.AccountName.contains('\')){
                    $workgroup, $user = $acl.AccountName.split('\')
                    # find domain
                    $adDomain = $ads | Where-Object { $_.workgroup -eq $workgroup }
                    if(!$adDomain){
                        write-host "domain $workgroup not found!" -ForegroundColor Yellow
                    }else{
                        # find domain princlipal/sid
                        $domainName = $adDomain.domainName
                        $principal = api get "activeDirectory/principals?domain=$($domainName)&includeComputers=true&search=$($user)"
                        if(!$principal){
                            write-host "user $($acl.AccountName) not found!" -ForegroundColor Yellow
                        }else{
                            $sid = $principal[0].sid
                            $sids[$acl.AccountName] = $sid
                        }
                    }
                }else{
                    # find local or wellknown sid
                    $principal = api get "activeDirectory/principals?includeComputers=true&search=$($acl.AccountName)"
                    if(!$principal){
                        write-host "user $($acl.AccountName) not found!" -ForegroundColor Yellow
                    }else{
                        $sid = $principal[0].sid
                        $sids[$acl.AccountName] = $sid
                    }
                }
            }
            if($sid){
                $newPermission = @{
                    "type"    = "k$($acl.AccessControlType.ToString())";
                    "access"  = $acl.AccessRight.ToString().replace('Full', 'kFullControl').replace('Read', 'kReadOnly').replace('Change', 'kModify');
                    "sid"     = $sid
                }
                $viewParams.sharePermissions += $newPermission
            }else{
                write-host "$($acl.AccountName) not found" -ForegroundColor Yellow
            }
        }
        # debug parameters
        # $viewParams | ConvertTo-Json -Depth 99
        "$($smbShare.name)"
        if($isView -eq $True){
            # update view
            $null = api put views $viewParams
        }else{
            if($share){
                # update existing viewAlias
                $null = api put viewAliases $viewParams
            }else{
                # create new viewAlias
                $null = api post viewAliases $viewParams
            }
        }
    }else{
        # view must be created first
        write-host "View name $viewName not found" -ForegroundColor Yellow
    }
}
