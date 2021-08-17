# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$jobname,
    [Parameter()][string]$joblist,
    [Parameter()][switch]$pause,
    [Parameter()][switch]$resume
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# gather job names
$myjobs = @()
if($null -ne $joblist -and (Test-Path $joblist -PathType Leaf)){
    $myjobs += Get-Content $joblist | Where-Object {$_ -ne ''}
}elseif($jobList){
    Write-Warning "File $joblist not found!"
    exit 1
}
if($jobname){
    $myjobs += $jobname
}
if($myjobs.Length -eq 0){
    Write-Host "No jobs selected"
    exit 1
}

# get selected jobs and report missing jobs
$jobs = api get protectionJobs | Where-Object name -in $myjobs | Sort-Object -Property name
$badjobs = $myjobs | Where-Object {$_ -notin $jobs.name}
foreach($badjob in $badjobs | sort){
    Write-Host "The job $badjob was not found" -ForegroundColor Yellow
}

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
        }else{
            "$($job.name) is enabled"
        }
    }
}

