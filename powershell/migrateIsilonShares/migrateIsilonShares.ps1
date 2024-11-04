
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$isilon,
    [Parameter(Mandatory = $True)][string]$isilonUsername,
    [Parameter()][string]$isilonPassword = $null,
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(Mandatory = $True)][string]$sourcePath = '/ifs'
)

function isilonAPI($method, $uri, $data=$null){
    $uri = $baseurl + $uri
    $result = $null
    try{
        if($data){
            $BODY = ConvertTo-Json $data -Depth 99
            if($PSVersionTable.PSEdition -eq 'Core'){
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $BODY -SkipCertificateCheck
            }else{
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $BODY
            }
        }else{
            if($PSVersionTable.PSEdition -eq 'Core'){
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -SkipCertificateCheck
            }else{
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers
            }
        }
    }catch{
        if($_.ToString().contains('"errors" :')){
            Write-Host (ConvertFrom-Json $_.ToString()).errors[0].message -foregroundcolor Yellow
        }else{
            Write-Host $_.ToString() -foregroundcolor yellow
        }
    }
    return $result
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$views = api get views
$view = $views.views | Where-Object name -eq $viewName
if(!$view){
    Write-Host "View $viewName not found" -foregroundcolor Yellow
    exit
}

$baseurl = 'https://' + $isilon +":8080"

# authentication
if(!$isilonPassword){
    $secureString = Read-Host -Prompt "Enter your password" -AsSecureString
    $isilonPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}
$EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($isilonUsername + ':' + $isilonPassword)
$EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)
$headers = @{"Authorization"="Basic $($EncodedPassword)"}

$shares = @()
$zones = isilonAPI get /platform/1/zones-summary

foreach($zoneName in $zones.summary.list){
    $isilonShares = isilonAPI get /platform/3/protocols/smb/shares?zone=$zoneName
    foreach($isilonShare in $isilonShares.shares){
        $folderPath = $isilonShare.path
        $shares = @( $shares + @{'name' = $isilonShare.name; 'folderPath' = $folderPath; 'permissions' = @($isilonShare.permissions) })
    }
}
### get AD info
$ads = api get activeDirectory
$sids = @{}

### create shares
foreach($share in $shares){
    if($share.folderPath -like "$($sourcePath)*"){
        $relativePath = $share.folderPath.substring($sourcePath.length)
        if($relativePath -notlike "/*"){
            $relativePath = "/$relativePath"
        }
        
        $viewParams = @{
            "viewName"         = $viewName;
            "viewPath"         = $relativePath;
            "aliasName"        = $share.name;
            "sharePermissions" = @()
        }
        foreach($permission in $share.permissions){
            $sid = $null
            # already have this sid in the cache
            if($sids.ContainsKey($permission.trustee.name)){
                $sid = $sids[$permission.trustee.name]
            }else{
                if($permission.trustee.name.contains('\')){
                    $workgroup, $user = $permission.trustee.name.split('\')
                    # find domain
                    $adDomain = $ads | Where-Object { $_.workgroup -eq $workgroup }
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
                            $sids[$permission.trustee.name] = $sid
                        }
                    }
                }else{
                    # find local or wellknown sid
                    $principal = api get "activeDirectory/principals?includeComputers=true&search=$($permission.trustee.name)"
                    if(!$principal){
                        write-host "user $($permission.trustee.name) not found!" -ForegroundColor Yellow
                    }else{
                        $sid = $principal[0].sid
                        $sids[$permission.trustee.name] = $sid
                    }
                }
            }
            # add permission
            if($sid){
                $newPermission = @{
                    "visible" = $true;
                    "type"    = "kAllow";
                    "access"  = $permission.permission.replace('full', 'kFullControl').replace('read', 'kReadOnly').replace('change', 'kModify');
                    "sid"     = $sid
                }
                $viewParams.sharePermissions = @($viewParams.sharePermissions + $newPermission)
            }
        }
        if($relativePath -eq '/'){
            # update view share params
            write-host "Updating view share permissions"
            $view.sharePermissions = @($viewParams.sharePermissions)
            $null = api put views/$($view.name) $view
        }else{
            # create share
            write-host "Creating $($share.name) ($relativePath)"
            $null = api post viewAliases $viewParams
        }
    }
}
