
### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$shareDataFilename = './shares.csv',
    [Parameter()][string]$sourcePathPrefix = '/ifs/myisilon/'
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get AD info
$ads = api get activeDirectory
$sids = @{}

### read shares file
$shareDataFile = get-content $shareDataFilename
$shareCount = -1
$shares = @()

foreach($shareData in $shareDataFile){
    $shareItems = $shareData.split(',')
    # share line item
    if($shareItems[1].Contains('/')){
        $shareCount += 1
        $folderPath = $shareItems[1].replace($sourcePathPrefix, '')
        $viewName = $folderPath.split('/')[0]
        $folderPath = $folderPath.split($viewName)[1]
        $shares += @{'viewName' = $viewName; 'name' = $shareItems[0]; 'folderPath' = $folderPath; 'permissions' = @() }
        # permission line item    
    }elseif($shareItems[1] -ne 'Account Type'){
        if($shareItems[0].substring(0, 4) -ne 'SID:'){
            $shares[$shareCount]['permissions'] += @{
                'account'        = $shareItems[0];
                'accountType'    = $shareItems[1];
                'permissionType' = $shareItems[3];
                'permission'     = $shareItems[4]
            }
        }
    }
}

### create shares
foreach($share in $shares){
    write-host "Creating share $($share.name) ($($share.folderPath))"

    $viewParams = @{
        "viewName"         = $share.viewName;
        "viewPath"         = $share.folderPath;
        "aliasName"        = $share.name;
        "sharePermissions" = @()
    }
    
    foreach($permission in $share.permissions){
        $sid = $null
        # already have this sid in the cache
        if($sids.ContainsKey($permission.account)){
            $sid = $sids[$permission.account]
        }else{
            if($permission.account.contains('\')){
                $workgroup, $user = $permission.account.split('\')
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
                        $sids[$permission.account] = $sid
                    }
                }
            }else{
                # find local or wellknown sid
                $principal = api get "activeDirectory/principals?includeComputers=true&search=$($permission.account)"
                if(!$principal){
                    write-host "user $($permission.account) not found!" -ForegroundColor Yellow
                }else{
                    $sid = $principal[0].sid
                    $sids[$permission.account] = $sid
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
            $viewParams.sharePermissions += $newPermission
        }
    }
    # create share
    $null = api post viewAliases $viewParams
}