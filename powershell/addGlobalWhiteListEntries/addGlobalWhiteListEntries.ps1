### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',           # local or AD domain
    [Parameter()][array]$ips,                         # optional cidrs to add (comma separated)
    [Parameter()][string]$ipList = '',                # optional textfile of cidrs to add
    [Parameter()][switch]$rootSquash,                 # whether whitelist entries should use root squash
    [Parameter()][switch]$allSquash,                  # whether whitelist entries should use all squash
    [Parameter()][switch]$readOnly                    # grant only read access
)

# gather list of cidrs to add to whitelist
$ipsToAdd = @()
foreach($ip in $ips){
    $ipsToAdd += $ip
}
if ('' -ne $ipList){
    if(Test-Path -Path $ipList -PathType Leaf){
        $ips = Get-Content $ipList
        foreach($ip in $ips){
            $ipsToAdd += [string]$ip
        }
    }else{
        Write-Warning "IP list $ipList not found!"
        exit
    }
}
if($ipsToAdd.Count -eq 0){
    Write-Host "No IPs specified" -ForegroundColor Yellow
    exit
}

$perm = 'kReadWrite'
if($readOnly){
    $perm = 'kReadOnly'
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

function netbitsToDDN($netBits){
    $maskBits = '1' * $netBits + '0' * (32 - $netBits)
    $octet1 = [convert]::ToInt32($maskBits.Substring(0,8),2)
    $octet2 = [convert]::ToInt32($maskBits.Substring(8,8),2)
    $octet3 = [convert]::ToInt32($maskBits.Substring(16,8),2)
    $octet4 = [convert]::ToInt32($maskBits.Substring(24,8),2)
    return "$octet1.$octet2.$octet3.$octet4"
}

function newWhiteListEntry($cidr, $perm){
    $ip, $netbits = $cidr -split '/'
    if(! $netbits){
        $netbits = '32'
    }
    $maskDDN = netbitsToDDN $netbits
    $whitelistEntry = @{
        "nfsAccess" = $perm;
        "smbAccess" = $perm;
        "s3Access" = $perm;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    if($allSquash){
        $whitelistEntry['nfsAllSquash'] = $True
    }
    if($rootSquash){
        $whitelistEntry['nfsRootSquash'] = $True
    }
    return $whitelistEntry
}

$whiteList = api get externalClientSubnets
if(!$whiteList.PSObject.Properties['clientSubnets']){
    setApiProperty -object $whiteList -name 'clientSubnets' -value @()
}

foreach($cidr in $ipsToAdd){
    Write-Host "    $cidr"
    $ip, $netbits = $cidr -split '/'
    $whitelist.clientSubnets = @($whitelist.clientSubnets | Where-Object ip -ne $ip)
    $whitelist.clientSubnets = @($whitelist.clientSubnets +(newWhiteListEntry $cidr $perm))
}

$null = api put externalClientSubnets $whiteList
