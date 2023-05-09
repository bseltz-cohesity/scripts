### usage: ./agentVersions.ps1 -vip 192.168.1.198 -username admin [ -domain local ]

### process commandline arguments
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
$clusterName = $cluster.name
$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "agentVersions-$clusterName-$dateString.csv"

# headings
$headings = """Cluster Name"",""Source Name"",""Agent Version"",""OS Type"",""OS Name"""
$headings | Out-File -FilePath $outfileName # -Encoding utf8

### list agent info
$nodes = api get protectionSources/registrationInfo?environments=kPhysical
$nodes.rootNodes | Sort-Object -Property {$_.rootNode.physicalProtectionSource.name} | `
         Select-Object -Property @{label='Source Name'; expression={$_.rootNode.physicalProtectionSource.name}},
                                 @{label='Agent Version'; expression={$_.rootNode.physicalProtectionSource.agents[0].version}},
                                 @{label='OS Type'; expression={$_.rootNode.physicalProtectionSource.hostType.subString(1)}},
                                 @{label='OS Name'; expression={$_.rootNode.physicalProtectionSource.osName}} 

foreach ($node in $nodes.rootNodes){
    $name = $node.rootNode.physicalProtectionSource.name
    $version = ''
    if($node.rootNode.physicalProtectionSource.PSObject.Properties['agents'] -and $node.rootNode.physicalProtectionSource.agents.Count -gt 0){
        $version = $node.rootNode.physicalProtectionSource.agents[0].version
    }
    $hostType = $node.rootNode.physicalProtectionSource.hostType.subString(1)
    $osName = $node.rootNode.physicalProtectionSource.osName
    """$clusterName"",""$name"",""$version"",""$hostType"",""$osName""" | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfilename`n"
