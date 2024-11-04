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
    [Parameter()][switch]$overwrite,                  # overwrite hostnames for existing IP (default is to add hostnames)
    [Parameter()][switch]$delete,                     # delete IP from list
    [Parameter()][switch]$quiet
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -quiet

### get host mappings
$hosts = api get /nexus/cluster/get_hosts_file

if(! $hosts){
    $hosts = @{'hosts' = @(); 'version' = 1}
}
if(! $hosts.hosts){
    $hosts.hosts = @()
}

if($backup){
    $backupFile = "hosts-backup-$(get-date -UFormat %Y-%m-%d-%H-%M-%S).csv"
    $hosts.hosts | ForEach-Object{ 
        "{0},{1}" -f $_.ip, ($_.domainName -join ',') 
    } | Out-File -FilePath $backupFile
    Write-Host "Hosts backed up to $backupFile"
}

function addEntry($ip, $hostNames){
    $newentry = New-Object pscustomobject -Property @{ip = $ip; domainName = @($hostNames)}
    if($hosts.hosts.Count -eq 0){
        $newhosts = ,$newentry
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

$changesMade = $false

# process single entry
if($ip -and $hostNames){
   $hosts.hosts = @(addEntry $ip $hostNames)
   $changesMade = $True
}elseif($ip){
    if(! $delete){
        Write-Host "-hostNames required" -ForegroundColor Yellow
    }
}elseif($hostNames){
    Write-Host "-ip required" -ForegroundColor Yellow
}

# process input file
if($ip){ 
    $deleteIPs = @($ip)
}else{
    $deleteIPs = @()
}

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
            if($delete){
                $deleteIPs += $ip
            }else{
                $hostNames = $hostNames.split(',')
                if($ip -and $hostNames){
                    $hosts.hosts = addEntry $ip $hostNames
                    $changesMade = $True
                }else{
                    Write-Host "Skipping invalid Record: $record" -ForegroundColor Yellow
                }
            }
        }
    }
}

# process deletes
if($delete){
    foreach($deleteIP in $deleteIPs){
        "Deleting $deleteIP"
        $hosts.hosts = $hosts.hosts | Where-Object ip -ne $deleteIP
        $changesMade = $True
    }
}

# show new list
if(!$quiet){
    $hosts.hosts | Sort-Object -Property ip
}

$hosts | setApiProperty 'validate' $True

if($changesMade){
    if($hosts.PSObject.Properties['version']){
        $hosts.version += 1
    }else{
        setApiProperty -object $hosts -name version -value 2
    }
    $result = api put /nexus/cluster/upload_hosts_file $hosts
    if(!$quiet){
        write-host $result.message -ForegroundColor Green
    }
}else{
    if(!$quiet){
        Write-Host "No changes made"
    }
    
}
if(!$quiet){
    Write-Host "`n"
}

