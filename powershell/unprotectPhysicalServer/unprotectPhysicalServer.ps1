# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][array]$servername,
    [Parameter()][string]$serverlist = ''
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# gather server names
$servers = @()
foreach($server in $servername){
    $servers += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $serversToRemove = Get-Content $serverList
        foreach($server in $serversToRemove){
            $servers += [string]$server
        }
    }else{
        Write-Warning "Server list $serverList not found!"
        exit
    }
}
if($servers.Length -eq 0){
    Write-Host "No servers to unprotect" -ForegroundColor Yellow
    exit
}

$serverfound = @{}
foreach($server in $servers){
    $serverfound[$server] = $false
}

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kPhysical"
$paramPaths = @{'kFile' = 'fileProtectionTypeParams'; 'kVolume' = 'volumeProtectionTypeParams'}

foreach($job in $jobs.protectionGroups){
    $saveJob = $false
    foreach($server in $servers){
        $paramPath = $paramPaths[$job.physicalParams.protectionType]
        $protectedObjectCount = $job.physicalParams.$paramPath.objects.Count
        $job.physicalParams.$paramPath.objects = @($job.physicalParams.$paramPath.objects | Where-Object {$_.name -ne $server})
        if($job.physicalParams.$paramPath.objects.Count -lt $protectedObjectCount){
            Write-Host "Removing $server from $($job.name)"
            $serverfound[$server] = $True
            $saveJob = $True
        }
    }
    if($saveJob){
        if($job.physicalParams.$paramPath.objects.Count -gt 0){
            $null = api put "data-protect/protection-groups/$($job.id)" $job -v2
        }else{
            Write-Host "No objects left in $($job.name). Deleting..."
            $null = api delete "data-protect/protection-groups/$($job.id)" -v2
        }        
    }
}

foreach($server in $servers){
    if($serverfound[$server] -eq $false){
        Write-Host "$server not found in any physical protection group" -ForegroundColor Yellow
    }
}
