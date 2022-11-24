# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][array]$clusterName = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

if($USING_HELIOS){
    if($clusterName.Count -gt 0){
        $selectedClusters = (heliosClusters | Where-Object {$_.name -in $clusterName}).name
    }else{
        $selectedClusters = (heliosClusters).name
    }
}else{
    $selectedClusters = $vip
}

foreach($thisClusterName in $selectedClusters){
    if($USING_HELIOS){
        heliosCluster $thisClusterName
    }
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"
    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        Write-Host "    Updating $($job.name)"
        $job.description = "{0} - updated: {1}" -f ($job.description -split '- updated: ')[0], (Get-Date -UFormat '%Y-%m-%d_%H-%M-%S')
        $null = api put -v2 data-protect/protection-groups/$($job.id) $job
    }
}


