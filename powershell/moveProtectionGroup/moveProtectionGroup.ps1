# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][switch]$deleteOldJob,
    [Parameter(Mandatory = $True)][string]$newStorageDomainName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][switch]$pauseNewJob,
    [Parameter()][switch]$pauseOldJob
)


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


if($prefix -eq '' -and $suffix -eq '' -and !$deleteOldJob){
    Write-Host "You must use either -prefix or -suffix or -deleteOldJob" -foregroundcolor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

if(! $AUTHORIZED -and ! $cohesity_api.authorized){
    Write-Host "Failed to connect to Cohesity cluster" -foregroundcolor Yellow
    exit
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $True)

$jobs = api get -v2 'data-protect/protection-groups?isActive=true'
$newStorageDomain = api get viewBoxes | Where-Object name -eq $newStorageDomainName
if($newPolicyName){
    $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $newPolicyName
    if(!$newPolicy){
        Write-Host "Policy $newPolicyName not found" -ForegroundColor Yellow
        exit
    }
}

if(!$newStorageDomain){
    Write-Host "Storage Domain $newStorageDomainName not found" -ForegroundColor Yellow
    exit
}

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit
    }
}

foreach($thisJobName in $jobNames){
    $job = $jobs.protectionGroups | Where-Object name -eq $thisJobName
    if($job.Count -gt 1){
        Write-Host "There is more than one job with the name $thisJobName, please rename one of them" -foregroundcolor Yellow
        exit
    }
}

foreach($thisJobName in $jobNames){
    $job = $jobs.protectionGroups | Where-Object name -eq $thisJobName
    if($pauseOldJob -and !$deleteOldJob){
        $job.isPaused = $True
        $updateJob = api put -v2 data-protect/protection-groups/$($job.id) $job
    }

    $job.storageDomainId = $newStorageDomain.id

    if($newPolicyName){
        $job.policyId = $newPolicy.id
    }

    "Moving protection group $($job.name) to $newStorageDomainName..."

    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    if($prefix -ne ''){
        $job.name = "$($prefix)-$($job.name)"
    }

    if($suffix -ne ''){
        $job.name = "$($job.name)-$($suffix)"
    }

    if($deleteOldJob){
        $deljob = api delete -v2 data-protect/protection-groups/$($job.id)
    }

    $newjob = api post -v2 data-protect/protection-groups $job
}
