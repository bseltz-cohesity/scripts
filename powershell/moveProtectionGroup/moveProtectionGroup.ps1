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
    [Parameter(Mandatory = $True)][string]$newStorageDomainName
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

    $newStorageDomain = api get viewBoxes | Where-Object name -eq $newStorageDomainName
    if(!$newStorageDomain){
        Write-Host "Storage Domain $newStorageDomainName not found" -ForegroundColor Yellow
        exit
    }else{
        $job.storageDomainId = $newStorageDomain.id
    }

    "Moving protection group $($job.name) to $newStorageDomainName..."
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
