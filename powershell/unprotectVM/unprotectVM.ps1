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
    [Parameter()][string]$vmList = '',
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList = ''
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)
$servers = @(gatherList -Param $vmName -FilePath $vmList -Name 'VMs' -Required $True)

$serverfound = @{}
foreach($server in $servers){
    $serverfound[$server] = $false
}

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found:  $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

foreach($job in $jobs.protectionGroups){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
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
}

foreach($server in $servers){
    if($serverfound[$server] -eq $false){
        Write-Host "$server not found in any specified VM protection group" -ForegroundColor Yellow
    }
}
