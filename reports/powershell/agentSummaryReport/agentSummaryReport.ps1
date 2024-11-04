# version: 2024-07-03

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][array]$clusterName = $null,
    [Parameter()][string]$outfileName
)

$scriptversion = '2024-08-09'

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$dateString = (get-date).ToString('yyyy-MM-dd-HH-mm')
if(!$outfileName){
    $outfileName = "agentSummaryReport-$dateString.csv"
}

# headings
"""Cluster Name"",""Host"",""OS Type"",""Health"",""Cluster Version"",""Agent Version"",""Upgradability"",""Last Upgrade Status"",""Certificate Issuer"",""Certificate Status"",""Certificate Expiry""" | Out-File -FilePath $outfileName

function getReport(){
    $cluster = api get cluster
    Write-Host "`n$($cluster.name)"
    $report = api get reports/agents
    foreach($agent in $report | Sort-Object -Property hostIp){
        Write-Host "    $($agent.hostIp)"
        """$($cluster.name.toUpper())"",""$($agent.hostIp)"",""$($agent.hostOsType)"",""$($agent.healthStatus)"",""$($cluster.clusterSoftwareVersion)"",""$($agent.version)"",""$($agent.upgradability)"",""$($agent.lastUpgradeStatus)"",""$($agent.certificateIssuer)"",""$($agent.certificateStatus)"",""$(usecsToDate $agent.certificateExpiryTimeUsecs)""" | Out-File -FilePath $outfileName -Append
    }
}

# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "`n$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            getReport
        }
    }else{
        getReport
    }
}

Write-Host "`nOutput saved to: $outfileName`n"
