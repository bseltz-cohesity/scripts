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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "agentStatus-$($cluster.name)-$dateString.csv"

# headings
"""Source Name"",""Agent Version"",""Upgrade Status"",""Health Status"",""Last Refresh""" | Out-File -FilePath $outfileName -Encoding utf8

$sources = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kPhysical"

foreach($source in $sources.rootNodes | Sort-Object -Property {$_.rootNode.name}){
    $sourceName = $source.rootNode.name
    $agentVersion = $source.rootNode.physicalProtectionSource.agents[0].version
    $upgradeStatus = $source.rootNode.physicalProtectionSource.agents[0].upgradability.subString(1)
    $agentStatus = $source.rootNode.physicalProtectionSource.agents[0].status.subString(1)
    $lastRefresh = usecsToDate $source.registrationInfo.refreshTimeUsecs -format 'yyyy-MM-dd hh:mm:ss'
    "{0}`t{1}  {2}" -f $sourceName, $agentVersion, $agentStatus
    """{0}"",""{1}"",""{2}"",""{3}"",""{4}""" -f $sourceName, $agentVersion, $upgradeStatus, $agentStatus, $lastRefresh | Out-File -FilePath $outfileName -Append -Encoding utf8
}

"`nOutput saved to $outfilename`n"
