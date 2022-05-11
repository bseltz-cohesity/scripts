# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter(Mandatory = $True)][string]$newStorageDomainName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain


if(! $AUTHORIZED -and ! $cohesity_api.authorized){
    Write-Host "Failed to connect to Cohesity cluster" -foregroundcolor Yellow
    exit
}

$job = (api get -v2 'data-protect/protection-groups?environments=kVMware&isActive=true').protectionGroups | Where-Object name -eq $jobName

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
    $deljob = api delete -v2 data-protect/protection-groups/$($job.id)
    $newjob = api post -v2 data-protect/protection-groups $job

}else{
    Write-Host "VMware Job $jobName not found" -ForegroundColor Yellow
}
