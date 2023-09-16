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
    [Parameter()][string]$clusterName,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmList = ''
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# gather server names
$servers = @()
foreach($server in $vmName){
    $servers += $server
}
if ('' -ne $vmList){
    if(Test-Path -Path $vmList -PathType Leaf){
        $serversToRemove = Get-Content $vmList
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

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware"

foreach($job in $jobs.protectionGroups){
    $saveJob = $false
    foreach($server in $servers){
        $protectedObjectCount = $job.vmwareParams.objects.Count
        $job.vmwareParams.objects = @($job.vmwareParams.objects | Where-Object {$_.name -ne $server})
        if($job.vmwareParams.objects.Count -lt $protectedObjectCount){
            Write-Host "Removing $server from $($job.name)"
            $serverfound[$server] = $True
            $saveJob = $True
        }
    }
    if($saveJob){
        if($job.vmwareParams.objects.Count -gt 0){
            $null = api put "data-protect/protection-groups/$($job.id)" $job -v2
        }else{
            Write-Host "No objects left in $($job.name). Deleting..."
            $null = api delete "data-protect/protection-groups/$($job.id)" -v2
        }        
    }
}

foreach($server in $servers){
    if($serverfound[$server] -eq $false){
        Write-Host "$server not found in any VM protection group" -ForegroundColor Yellow
    }
}
