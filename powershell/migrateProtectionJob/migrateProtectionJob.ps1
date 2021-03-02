# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$newStorageDomain,
    [Parameter()][array]$jobname,
    [Parameter()][string]$joblist,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][switch]$pauseNewJob,
    [Parameter()][switch]$pauseOldJob,
    [Parameter()][switch]$deleteOldJob,
    [Parameter()][switch]$deleteOldSnapshots
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get target storage domain
$storageDomains = api get viewBoxes
$storageDomain = $storageDomains | Where-Object name -eq $newStorageDomain
if(! $storageDomain){
    Write-Host "Storage domain $newStorageDomain not found" -ForegroundColor Yellow
    exit 1
}

# gather job names
$myjobs = @()
if(Test-Path $joblist -PathType Leaf){
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

# clone jobs
foreach($job in $jobs){

    if($job.viewBoxId -eq $storageDomain.id){
        "Job $($job.name) is already on storage domain $newStorageDomain"
    }else{

        # set new job name
        $renaming = $True
        $newJobName = "{0}{1}{2}" -f $prefix, $job.name, $suffix
        if($newJobName -eq $job.name){
            $renaming = $false
        }
    
        # must rename old job if we're not renaming new job or deleting old job
        if($false -eq $renaming -and (! $deleteOldJob) -and (! $deleteOldSnapshots)){
            "Renaming job $($job.name) to Old-$($job.name)"
            $job.name = "Old-{0}" -f $job.name
            $job.name
            $null = api put "protectionJobs/$($job.id)" $job
        }
    
        if($deleteOldSnapshots -or $deleteOldJob){
            # save backup of job
            $job | ConvertTo-Json -Depth 99 | Out-File -FilePath "$($job.name).json"
    
            # delete old job
            if($deleteOldSnapshots){
                "Deleting job $($job.name) and existing snapshots"
                $null = api delete "protectionJobs/$($job.id)" @{'deleteSnapshots'= $True}
            }else{
                "Deleting job $($job.name)"
                $null = api delete "protectionJobs/$($job.id)" @{'deleteSnapshots'= $false}
            }
        }else{
            # pause old job
            if($pauseOldJob){
                "Pausing job $($job.name)"
                $null = api post protectionJobState/$($job.id) @{ "pause" = $true; "pauseReason" = 0 }
            }
        }
    
        # Create new job
        "Creating new job $newJobName"
        $job.name = $newJobName
        $job.viewBoxId = $storageDomain.id
        $newJob = api post protectionJobs $job
    
        # Pause new job
        if($pauseNewJob){
            $null = api post "protectionJobState/$($newJob.id)" @{'pause' = $True}
        }   
    }
}
