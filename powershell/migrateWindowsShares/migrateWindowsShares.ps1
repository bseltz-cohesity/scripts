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
    [Parameter()][array]$shareName,
    [Parameter()][string]$shareList
)

# gather list from command line params and file
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

$shareNames = @(gatherList -Param $shareName -FilePath $shareList -Name 'shares' -Required $True)

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

### get views and shares
$views = api get views
$shares = api get shares

### get AD info
$ads = api get activeDirectory
$sids = @{}

# get local smb shares
$smbShares = get-smbshare | Where-Object name -notin $ignoreShares | Where-Object name -notlike '?$'

foreach($thisShareName in $shareNames){
    $newAlias = $False
    $share = $shares.sharesList | Where-Object shareName -eq $thisShareName
    if(!$share){
        $smbShare = $smbShares | Where-Object name -eq $thisShareName
        if(!$smbShare){
            Write-Host "SMB share $thisShareName not found on Windows server" -ForegroundColor Yellow
            continue
        }
        $smbSharePath = $smbShare.Path.Replace('\','/').Replace(':','')
        $parentShares = $smbShares | Where-Object {$smbSharePath -match "$($_.Path.Replace('\','/').replace(':',''))" -and $_.Name -ne $thisShareName} | Sort-Object -Property {$_.Path.Length} -Descending
        $parentView = $null
        $thisParentShare = $null
        if($parentShares){
            foreach($parentShare in $parentShares){
                $view = $views.views | Where-Object name -eq $parentShare.Name
                if($view){
                    $parentView = $view
                    $thisParentShare = $parentShare
                    break
                }
            }
        }
        if($null -ne $parentView){
            $newAlias = $True
            $relativePath = $smbSharePath.Replace("$($thisParentShare.Path.Replace('\','/').replace(':',''))/",'')
            $viewParams = @{
                "viewName"         = $parentView.name;
                "viewPath"         = "$($relativePath)/";
                "aliasName"        = $smbShare.Name;
                "sharePermissions" = @()
            }
        }else{
            Write-Host "View/Share name $thisShareName not found on Cohesity cluster" -ForegroundColor Yellow
            continue
        }
    }
    if($share.viewName -eq $thisShareName){
        # this is a view
        $isView = $True
        $view = $views.views | Where-Object name -eq $thisShareName
        if(!$view){
            Write-Host "View name $thisShareName not found" -ForegroundColor Yellow
            continue
        }
        $isView = $True
        $viewParams = $view
        $viewParams.sharePermissions = @()
    }else{
        # this is a view alias
        $isView = $false
        if($newAlias -ne $True){
            $viewParams = @{
                "viewName"         = $share.viewName;
                "viewPath"         = $share.path;
                "aliasName"        = $share.shareName;
                "sharePermissions" = @()
            }
        }
    }
    # find matching share on Windows
    $smbShare = $smbShares | Where-Object name -eq $thisShareName
    if(!$smbShare){
        Write-Host "SMB share $thisShareName not found on Windows server" -ForegroundColor Yellow
        continue
    }else{
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
                    if($acl.AccountName -eq 'Everyone'){
                        $principal = @(@{"sid" = "S-1-1-0"})
                    }else{
                        $principal = api get "activeDirectory/principals?includeComputers=true&search=$($acl.AccountName)"
                    }
                    
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
        Write-Host "Updating $thisShareName"
        if($isView -eq $True){
            $null = api put views $viewParams
        }else{
            if($newAlias){
                $null = api post viewAliases $viewParams
            }else{
                $null = api put viewAliases $viewParams
            }
        }
    }
}
