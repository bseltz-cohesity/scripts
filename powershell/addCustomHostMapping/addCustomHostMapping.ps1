### usage: ./addCustomHostMapping.ps1 -vip mycluster -username admin [ -domain local ] -ip ipaddress -hostNames myserver, myserver.mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,       # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',           # local or AD domain
    [Parameter()][string]$ip,                         # ip address of host mapping
    [Parameter()][string[]]$hostNames,                # one or more host names (comma separated)
    [Parameter()][string]$inputFile,                  # name of file containing entries to add
    [Parameter()][switch]$backup,                     # backup existing hosts before making changes
    [Parameter()][switch]$overwrite                   # overwrite hostnames for existing IP (default is to add hostnames)
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get host mappings
$hosts = api get /nexus/cluster/get_hosts_file

if($backup){
    $hosts.hosts | ForEach-Object{ 
        "{0},{1}" -f $_.ip, ($_.domainName -join ',') 
    } | Out-File -FilePath "hosts-backup-$(get-date -UFormat %Y-%m-%d-%H-%M-%S).csv"
}

function addEntry($ip, $hostNames){
    $newentry = New-Object pscustomobject -Property @{ip = $ip; domainName = @($hostNames)}
    if($null -eq $hosts.hosts){
        $newhosts = @($newentry)
    }else{
        $duplicate = $false
        $newhosts = @($hosts.hosts) | ForEach-Object{
            if($_.ip -eq $ip){
                $duplicate = $True
                if($overwrite){
                    $_.domainName = @($hostNames)
                }else{
                    $_.domainName = @(@($_.domainName) + $hostNames | Sort-Object -Unique)
                }
                $_
            }else{
                $_
            }
        }
        if(! $duplicate){
            $newhosts = @($newhosts) + $newentry
        }
    }
    return @($newhosts | Sort-Object -Property ip)
}


# process single entry
if($ip -and $hostNames){
   $hosts.hosts = addEntry $ip $hostNames
}elseif($ip){
    Write-Host "-hostNames required" -ForegroundColor Yellow
}elseif($hostNames){
    Write-Host "-ip required" -ForegroundColor Yellow
}

# process input file
if($inputFile){
    if(! (Test-Path -Path $inputFile -PathType Leaf)){
        Write-Host "$inputFile not found!" -ForegroundColor Yellow
        exit 1
    }
    $newentries = Get-Content -Path $inputFile
    $newentries | ForEach-Object{
        if($_ -ne ''){
            $ip = $hostNames = $null
            $record = [string]$_
            $ip, $hostNames = $record.replace(' ','').split(',',2)
            $hostNames = $hostNames.split(',')
            if($ip -and $hostNames){
                $hosts.hosts = addEntry $ip $hostNames
            }else{
                Write-Host "Skipping invalid Record: $record" -ForegroundColor Yellow
            }
        }
    }
}

# show new list
$hosts.hosts | Sort-Object -Property ip

$hosts | setApiProperty 'validate' $True
$result = api put /nexus/cluster/upload_hosts_file $hosts
write-host $result.message -ForegroundColor Green
