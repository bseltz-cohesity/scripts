# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][int]$maxCount = 1000,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB'
)

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

# outfile
$cluster = api get cluster
$outfileName = "shareList-$($cluster.name).csv"
$smbPermissions = "smbPermissions-$($cluster.name).txt"

# headings
$headings = "View Name
Share Name
Is Child Share
Relative Path
SMB Path
NFS Path
S3 Path
Logical Size ($unit)"

$headings = $headings -split "`n" -join ""","""
$headings = """$headings"""
$headings | Out-File -FilePath $outfileName -Encoding utf8
'' | Out-File -FilePath $smbPermissions -Encoding utf8

# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

$allViews = @()
$allShares = @()

$views = api get "views?allUnderHierarchy=true&maxCount=$maxCount"
while($True){
    $allViews = @($allViews + $views.views)
    if($views.lastResult -eq $True){
        break
    }
    $views = api get "views?allUnderHierarchy=true&maxCount=$maxCount&maxViewId=$($views.views[-1].viewId)"
}

$shares = api get "shares?maxCount=$maxCount"
while($True){
    $allShares = @($allShares + $shares.sharesList)
    if($shares.PSObject.Properties['paginationCookie']){
        $shares = api get "shares?maxCount=$maxCount&paginationCookie=$($shares.paginationCookie)"
    }else{
        break
    }
}

foreach($view in $allViews | Sort-Object -Property name){
    $smbPath = ''
    $nfsPath = ''
    $s3Path = ''
    if($view.PSObject.Properties['smbMountPath']){
        $smbPath = $view.smbMountPath
    }
    if($view.PSObject.Properties['nfsMountPath']){
        $nfsPath = $view.nfsMountPath
    }
    if($view.PSObject.Properties['s3AccessPath']){
        $s3Path = $view.s3AccessPath
    }
    $logicalSize = toUnits $view.logicalUsageBytes
    """$($view.name)"",""$($view.name)"",""False"",""/"",""$smbPath"",""$nfsPath"",""$s3Path"",""$logicalSize""" | Out-File -FilePath $outfileName -Append
    if($view.PSObject.Properties['sharePermissions']){
        "`n====================`n$($view.name)`n====================`n" | Out-File -FilePath $smbPermissions -Append
        foreach($permission in $view.sharePermissions){
            $thisPrincipal = principalName $permission.sid
            "$($permission.access): $($thisPrincipal) ($($permission.type))" | Out-File -FilePath $smbPermissions -Append
        }
    }
    $theseShares = $allShares | Where-Object {$_.viewName -eq $view.name -and $_.shareName -ne $_.viewName}
    foreach($share in $theseShares | Sort-Object -Property shareName){
        $smbPath = ''
        $nfsPath = ''
        $s3Path = ''
        if($share.PSObject.Properties['smbMountPath']){
            $smbPath = $share.smbMountPath
        }
        if($share.PSObject.Properties['nfsMountPath']){
            $nfsPath = $share.nfsMountPath
        }
        if($share.PSObject.Properties['s3AccessPath']){
            $s3Path = $share.s3AccessPath
        }
        """$($share.viewName)"",""$($share.shareName)"",""True"",""$($share.path)"",""$smbPath"",""$nfsPath"",""$s3Path"",""""" | Out-File -FilePath $outfileName -Append
        if($share.PSObject.Properties['sharePermissions']){
            "`n====================`n$($share.shareName)`n====================`n" | Out-File -FilePath $smbPermissions -Append
            foreach($permission in $share.sharePermissions){
                $thisPrincipal = principalName $permission.sid
                "$($permission.access): $($thisPrincipal) ($($permission.type))" | Out-File -FilePath $smbPermissions -Append
            }
        }
    }
}

"`nOutput saved to $outfilename"
"SMB Permissions saved to $smbPermissions`n"
