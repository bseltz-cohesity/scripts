### usage: ./agentVersions.ps1 -vip 192.168.1.198 -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding(PositionalBinding=$false)]
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
    [Parameter()][string]$clusterName = $null,
    [Parameter()][string]$environment = $null
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
$headings = """Cluster Name"",""Source Name"",""Agent Version"",""OS Type"",""OS Name"",""File CBT"",""Vol CBT"""
$headings | Out-File -FilePath $outfileName # -Encoding utf8

### list agent info
$nodes = api get protectionSources/registrationInfo?allUnderHierarchy=true
$nodes.registrationInfo

if($environment){
    $nodes.rootNodes = $nodes.rootNodes | Where-Object {$environment -in $_.registrationInfo.environments}
}

$nodes.rootNodes | Sort-Object -Property {$_.rootNode.name} | `
         Where-Object {$_.rootNode.$(($_.rootNode.PSObject.Properties | Where-Object {$_ -cmatch 'ProtectionSource'}).name).PSObject.Properties['agents']} | `
         Select-Object -Property @{label='Source Name'; expression={$_.rootNode.name}},
                                 @{label='Agent Version'; expression={$_.rootNode.$(($_.rootNode.PSObject.Properties | Where-Object {$_ -cmatch 'ProtectionSource'}).name).agents[0].version}},
                                 @{label='OS Type'; expression={$_.rootNode.$(($_.rootNode.PSObject.Properties | Where-Object {$_ -cmatch 'ProtectionSource'}).name).hostType.subString(1)}},
                                 @{label='OS Name'; expression={$_.rootNode.$(($_.rootNode.PSObject.Properties | Where-Object {$_ -cmatch 'ProtectionSource'}).name).osName}}

foreach ($node in $nodes.rootNodes){
    $psproperty = ($node.rootNode.PSObject.Properties | Where-Object {$_ -cmatch 'ProtectionSource'}).name
    $name = $node.rootNode.name
    $version = ''
    $hostType = ''
    $osName = ''
    $apps = ''
    if($node.rootNode.$psproperty.PSObject.Properties['agents'] -and $node.rootNode.$psproperty.agents.Count -gt 0){
        $version = $node.rootNode.$psproperty.agents[0].version
        $fileCBT = $node.rootNode.$psproperty.agents[0].fileCbtInfo.isInstalled
        $volCBT = $node.rootNode.$psproperty.agents[0].volCbtInfo.isInstalled
        $hostType = $node.rootNode.$psproperty.hostType.subString(1)
        $osName = $node.rootNode.$psproperty.osName
        $apps = $node.registrationInfo['environments']
        """$clusterName"",""$name"",""$version"",""$hostType"",""$osName"",""$fileCBT"",""$volCBT""" | Out-File -FilePath $outfileName -Append
    }
}

"`nOutput saved to $outfilename`n"
