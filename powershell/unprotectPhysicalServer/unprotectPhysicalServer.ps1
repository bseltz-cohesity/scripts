# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$servername,
    [Parameter()][string]$serverlist
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# gather server names
$serversToRemove = @()
foreach($server in $servername){
    $serversToRemove += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $servers = Get-Content $serverList
        foreach($server in $servers){
            $serversToRemove += [string]$server
        }
    }else{
        Write-Warning "Server list $serverList not found!"
        exit
    }
}
if($serversToRemove.Length -eq 0){
    Write-Host "No servers to unprotect" -ForegroundColor Yellow
    exit
}

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=true&environments=kPhysical"
$paramPaths = @{'kFile' = 'fileProtectionTypeParams'; 'kVolume' = 'volumeProtectionTypeParams'}

foreach($job in $jobs.protectionGroups){
    $saveJob = $false
    foreach($server in $serversToRemove){
        $paramPath = $paramPaths[$job.physicalParams.protectionType]
        $protectedObjectCount = $job.physicalParams.$paramPath.objects.Count
        $job.physicalParams.$paramPath.objects = @($job.physicalParams.$paramPath.objects | Where-Object {$_.name -ne $server})
        if($job.physicalParams.$paramPath.objects.Count -lt $protectedObjectCount){
            Write-Host "Removing $server from $($job.name)"
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
