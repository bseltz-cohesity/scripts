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
    [Parameter()][array]$jobname,
    [Parameter()][string]$joblist = '',
    [Parameter()][switch]$pause,
    [Parameter()][switch]$resume,
    [Parameter()][switch]$showAll
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

# gather job names
$myjobs = @()
if($joblist -ne '' -and (Test-Path $joblist -PathType Leaf)){
    $myjobs += Get-Content $joblist | Where-Object {$_ -ne ''}
}elseif($jobList){
    Write-Warning "File $joblist not found!"
    exit 1
}
if($jobname){
    $myjobs += $jobname
}
if($pause -or $resume){
    if($myjobs.Length -eq 0){
        Write-Host "No jobs selected"
        exit 1
    }
}
if($myjobs.Length -gt 0 -and !$showAll){
    # get selected jobs and report missing jobs
    $jobs = api get protectionJobs | Where-Object name -in $myjobs | Sort-Object -Property name
    $badjobs = $myjobs | Where-Object {$_ -notin $jobs.name}
    foreach($badjob in $badjobs | sort){
        Write-Host "The job $badjob was not found" -ForegroundColor Yellow
    }
    $jobs = $jobs | Where-Object {$_.isActive -ne $false}
}else{
    $jobs = api get protectionJobs | Sort-Object -Property name
}

$x = 0

# pause, resume or display job state
foreach($job in $jobs){
    if($pause){
        "Pausing job $($job.name)"
        $null = api post protectionJobState/$($job.id) @{ "pause" = $true; "pauseReason" = 0 }
    }elseif($resume){
        "Resuming job $($job.name)"
        $null = api post protectionJobState/$($job.id) @{ "pause" = $false; "pauseReason" = 0 }
    }else{
        if($job.isPaused){
            "$($job.name) is paused"
            $x += 1 
        }else{
            if($showAll -or $job.name -in $myjobs){
                "$($job.name) is enabled"
            }
        }
    }
}
if($x -eq 0 -and !$pause -and !$resume -and $myjobs.Length -eq 0){
    "No jobs are paused"
}
