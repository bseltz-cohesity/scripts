# process commandline arguments
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
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter()][switch]$nfsOnly,
    [Parameter()][switch]$smbOnly,
    [Parameter()][switch]$enable,
    [Parameter()][switch]$disable,
    [Parameter()][array]$allow,
    [Parameter()][array]$deny
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

$viewNames = @(gatherList -Param $viewNames -FilePath $viewList -Name 'views' -Required $false)

if($smbOnly){
    $views = api get -v2 "file-services/views?viewProtectionTypes=Local&useCachedData=false&protocolAccesses=SMB"
}elseif($nfsOnly){
    $views = api get -v2 "file-services/views?viewProtectionTypes=Local&useCachedData=false&protocolAccesses=NFS,NFS4"
}else{
    $views = api get -v2 "file-services/views?viewProtectionTypes=Local&useCachedData=false&protocolAccesses=NFS,NFS4,SMB"
}

if($viewNames.Count -gt 0){
    $notfoundViews = $viewNames | Where-Object {$_ -notin $views.views.name}
    if($notfoundViews){
        Write-Host "Views not found $($notfoundViews -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

if($views.count -eq 0){
    Write-Host "No applicable views found"
    exit
}

### get AD info
$ads = api get activeDirectory

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
            }
        }
    }else{
        # find local or wellknown sid
        $principal = api get "activeDirectory/principals?includeComputers=true&search=$($user)"
        if(!$principal){
            write-host "Principal ""$($user)"" not found!" -ForegroundColor Yellow
        }else{
            $sid = $principal[0].sid
        }
    }
    if($sid){
        return $sid
    }else{
        return $null
    }
}

$allowSids = @()
$denySids = @()
if($allow){
    foreach($user in $allow){
        $sid = getSid $user
        if($sid){
            $allowSids = @($allowSids + $sid)
        }
    }
}else{
    $allowSids = @("S-1-1-0")
}
if($deny){
    foreach($user in $deny){
        $sid = getSid $user
        if($sid){
            $denySids = @($denySids + $sid)
        }
    }
}

foreach($view in $views.views | Sort-Object -Property name){
    if($viewNames.Count -eq 0 -or $view.name -in $viewNames){
        Write-Host $view.name
        if($enable){
            $view.selfServiceSnapshotConfig.nfsAccessEnabled = $True
            $view.selfServiceSnapshotConfig.smbAccessEnabled = $True
            $view.selfServiceSnapshotConfig.previousVersionsEnabled = $True
            if($view.selfServiceSnapshotConfig.snapshotDirectoryName -eq ''){
                $view.selfServiceSnapshotConfig.snapshotDirectoryName = '.snapshot'
            }
            if($view.selfServiceSnapshotConfig.alternateSnapshotDirectoryName -eq ''){
                $view.selfServiceSnapshotConfig.alternateSnapshotDirectoryName = '~snapshot'
            }
            if($allow){
                setApiProperty -object $view.selfServiceSnapshotConfig -name allowAccessSids -value @($allowSids)
            }
            if($deny){
                setApiProperty -object $view.selfServiceSnapshotConfig -name denyAccessSids -value @($denySids)
            }
            Write-Host "    enabling self service..."
            $null = api put -v2 file-services/views/$($view.viewId) $view
        }elseif($disable){
            $view.selfServiceSnapshotConfig.nfsAccessEnabled = $False
            $view.selfServiceSnapshotConfig.smbAccessEnabled = $False
            $view.selfServiceSnapshotConfig.previousVersionsEnabled = $False
            Write-Host "    disabling self service..."
            $null = api put -v2 file-services/views/$($view.viewId) $view
        }else{
            Write-Host "    NFS access enabled: $($view.selfServiceSnapshotConfig.nfsAccessEnabled)"
            Write-Host "    SMB access enabled: $($view.selfServiceSnapshotConfig.smbAccessEnabled)"
            Write-Host "     Previous versions: $($view.selfServiceSnapshotConfig.previousVersionsEnabled)"
            Write-Host ""
        }
    }
}
