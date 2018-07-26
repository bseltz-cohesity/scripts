### usage: ./agentVersions.ps1 -vip 192.168.1.198 -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local' #local or AD domain
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### list agent info
$agents = api get protectionSources | Where-Object { $_.protectionSource.name -eq 'Physical Servers' }
foreach ($node in $agents.nodes){
    $name = $node.protectionSource.physicalProtectionSource.agents[0].name
    $version = $node.protectionSource.physicalProtectionSource.agents[0].version
    "$version`t$name"
}
