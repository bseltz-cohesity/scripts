# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$ip,
    [Parameter()][string]$ipList,
    [Parameter()][switch]$addEntry,
    [Parameter()][switch]$removeEntry,
    [Parameter()][ValidateSet('Management', 'SNMP', 'S3', 'Data Protection', 'Replication', 'SSH', 'SMB', 'NFS', 'Reporting database', '')][string]$profileName = ''
)

$profileNames = @('Management', 'SNMP', 'S3', 'Data Protection', 'Replication', 'SSH', 'SMB', 'NFS', 'Reporting database')

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}


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


$entries = @(gatherList -Param $ip -FilePath $ipList -Name 'entries' -Required $false)

if($addentry){
    $action = 'add'
}elseif ($removeEntry){
    $action = 'remove'
}else{
    $action = 'list'
}

if($profileName -eq '' -and $action -ne 'list'){
    Write-Host "No profileName specified" -ForegroundColor Yellow
    exit 1
}

if($action -ne 'list' -and $entries.Count -eq 0){
    Write-Host "No entries specified" -ForegroundColor Yellow
    exit 1
}

# get existing firewall rules
$rules = api get /nexus/v1/firewall/list

foreach($cidr in $entries){
    $net, $mask = $cidr -split '/'
    if(! $mask){
        $cidr = "$net/32"
    }
    foreach($attachment in $rules.entry.attachments){
        if($attachment.profile -eq $profileName){
            if($action -ne 'list'){
                if($attachment.subnets -and $attachment.subnets.Count -gt 0){
                    $attachment.subnets = @($attachment.subnets | Where-Object {$_ -ne $cidr})
                }
                if($action -eq 'add'){
                    if(! $attachment.subnets){
                        $attachment.subnets = @()
                    }
                    $attachment.subnets = @($attachment.subnets + $cidr)
                    Write-Host "    $($profileName): adding $cidr"
                }else{
                    Write-Host "    $($profileName): removing $cidr"
                }
                setApiProperty -object $rules -name updateAttachment -value $True
            }
        }
    }
}

if($action -ne 'list'){
    # $rules | ConvertTo-JSON -Depth 99 | Out-file firewallExample.json
    $result = api put /nexus/v1/firewall/update $rules
    if(!$result){
        exit 1
    }
}

foreach($pName in $profileNames | Sort-Object){
    if($profileName -eq '' -or $pname -eq $profileName){
        Write-Host "`n$($pName):"
        foreach($attachment in $rules.entry.attachments){
            if($attachment.profile -eq $pName){
                if(! $attachment.subnets -or $attachment.subnets.Count -eq 0){
                    Write-host "    All IP Addresses(*) ($($attachment.action))"
                }else{
                    foreach($cidr in $attachment.subnets){
                        Write-Host "    $cidr ($($attachment.action))"
                    }
                }
            }
        }
    }
}
Write-Host ""
