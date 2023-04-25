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
$nodes = api get protectionSources/registrationInfo?environments=kPhysical
$nodes.rootNodes | Sort-Object -Property {$_.rootNode.physicalProtectionSource.name} | `
         Select-Object -Property @{label='Name'; expression={$_.rootNode.physicalProtectionSource.name}},
                                 @{label='Version'; expression={$_.rootNode.physicalProtectionSource.agents[0].version}},
                                 @{label='Host Type'; expression={$_.rootNode.physicalProtectionSource.hostType.subString(1)}},
                                 @{label='OS Name'; expression={$_.rootNode.physicalProtectionSource.osName}} 
# foreach ($node in $nodes){
#     $name = $node.protectionSource.physicalProtectionSource.name
#     $version = $node.protectionSource.physicalProtectionSource.agents[0].version
#     $hostType = $node.protectionSource.physicalProtectionSource.hostType.subString(1)
#     $osName = $node.protectionSource.physicalProtectionSource.osName
    
# }
