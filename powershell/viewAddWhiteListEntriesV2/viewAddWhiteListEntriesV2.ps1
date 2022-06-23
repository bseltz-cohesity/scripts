### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',           # local or AD domain
    [Parameter()][string]$tenantId = $null,           # tenant ID to impersonate
    [Parameter()][array]$viewNames,                   # names of view to modify (comma separated)
    [Parameter()][string]$viewList,                   # optional textfile of views to modify
    [Parameter()][array]$ips,                         # optional cidrs to add (comma separated)
    [Parameter()][string]$ipList,                     # optional textfile of cidrs to add
    [Parameter()][switch]$rootSquash,                 # whether whitelist entries should use root squash
    [Parameter()][switch]$allSquash,                  # whether whitelist entries should use all squash
    [Parameter()][switch]$readOnly                    # grant only read access
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

$ipsToAdd = @(gatherList -Param $ips -FilePath $ipList -Name 'IPs' -Required $True)
$viewsToModify = @(gatherList -Param $viewNames -FilePath $viewList -Name 'views' -Required $True)

$perm = 'kReadWrite'
if($readOnly){
    $perm = 'kReadOnly'
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -tenantId $tenantId

function newWhiteListEntry($cidr, $perm){
    $ip, $netbits = $cidr -split '/'
    if(! $netbits){
        $netbits = '32'
    }

    $whitelistEntry = @{
        "nfsAccess" = $perm;
        "smbAccess" = $perm;
        "s3Access" = $perm;
        "ip"            = $ip;
        "netmaskBits"    = [int]$netbits;
        "description" = ''
    }
    if($allSquash){
        $whitelistEntry['nfsAllSquash'] = $True
    }
    if($rootSquash){
        $whitelistEntry['nfsRootSquash'] = $True
    }
    return $whitelistEntry
}

$views =  (api get -v2 file-services/views).views

foreach($viewName in $viewsToModify){
    $view = $views | Where-Object name -eq $viewName
    if(! $view){
        Write-Host "View $viewName not found" -ForegroundColor Yellow
    }else{
        Write-Host $view.name
    
        if(! $view.PSObject.Properties['subnetWhitelist']){
            setApiProperty -object $view -name 'subnetWhitelist' -value @()
        }
        
        foreach($cidr in $ipsToAdd){
            Write-Host "    $cidr"
            $ip, $netbits = $cidr -split '/'
            $view.subnetWhitelist = @($view.subnetWhiteList | Where-Object ip -ne $ip)
            $view.subnetWhitelist = @($view.subnetWhiteList +(newWhiteListEntry $cidr $perm))
        }
        $view.subnetWhiteList = @($view.subnetWhiteList | Where-Object {$_ -ne $null})
        $null = api put -v2 file-services/views/$($view.viewId) $view
    }
}
