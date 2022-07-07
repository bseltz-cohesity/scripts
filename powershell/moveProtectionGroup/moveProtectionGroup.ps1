# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][switch]$deleteOldJob,
    [Parameter(Mandatory = $True)][string]$newStorageDomainName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][switch]$pauseNewJob,
    [Parameter()][switch]$pauseOldJob
)

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

$job = (api get -v2 'data-protect/protection-groups?isActive=true').protectionGroups | Where-Object name -eq $jobName

if($job){
    if($job.Count -gt 1){
        Write-Host "There is more than one job with the same name, please rename one of them" -foregroundcolor Yellow
        exit
    }

    if($pauseOldJob -and !$deleteOldJob){
        $job.isPaused = $True
        $updateJob = api put -v2 data-protect/protection-groups/$($job.id) $job
    }

    $newStorageDomain = api get viewBoxes | Where-Object name -eq $newStorageDomainName
    if(!$newStorageDomain){
        Write-Host "Storage Domain $newStorageDomainName not found" -ForegroundColor Yellow
        exit
    }else{
        $job.storageDomainId = $newStorageDomain.id
    }

    if($newPolicyName){
        $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $newPolicyName
        if(!$newPolicy){
            Write-Host "Policy $newPolicyName not found" -ForegroundColor Yellow
            exit
        }else{
            $job.policyId = $newPolicy.id
        }
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

}else{
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
}
