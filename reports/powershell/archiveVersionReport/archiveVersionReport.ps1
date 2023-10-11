# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null
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

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "archiveVersions-$($cluster.name)-$dateString.csv"

# headings
"Job Name,Policy,Targets,Archive Versions" | Out-File -FilePath $outfileName -Encoding utf8

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true"
$policies = api get -v2 "data-protect/policies"
$vaults = api get vaults

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    Write-Host $job.name
    $policy = $policies.policies | Where-Object id -eq $job.policyId
    $caVersions = @()
    $targets = @()
    foreach($archiveTarget in $policy.remoteTargetPolicy.archivalTargets){
        $vault = $vaults | Where-Object id -eq $archiveTarget.targetId
        if($vault.isForeverIncrementalArchiveEnabled -eq $True){
            $targets = @($targets + "$($vault.name)(v2)" | Sort-Object -Unique)
            $caVersions = @($caVersions + 'v2' | Sort-Object -Unique)
        }else{
            $targets = @($targets + "$($vault.name)(v1)" | Sort-Object -Unique)
            $caVersions = @($caVersions + 'v1' | Sort-Object -Unique)
        }
    }
    "{0},{1},{2},{3}" -f $job.name, $policy.name, $($targets -join ' '), $($caVersions -join ' ') | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfilename`n"
