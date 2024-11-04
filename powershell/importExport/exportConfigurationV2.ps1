# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$configFolder = './configExports'  # folder to store export files
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    if($emailMfaCode){
        apiauth -vip $vip -username $username -domain $domain -password $password -emailMfaCode
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password -mfaCode $mfaCode
    }
}

# get cluster info
$cluster = api get cluster

# create export folder
$configPath = Join-Path -Path $configFolder -ChildPath $cluster.name 
if(! (Test-Path -PathType Container -Path $configPath)){
    $null = New-Item -ItemType Directory -Path $configPath -Force
}

$summaryFile = Join-Path -Path $configPath -ChildPath 'clusterSummary.txt'

write-host "Exporting configuration information for $($cluster.name) to $configPath..."

# cluster configuration
$cluster | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'cluster.json')
"Cluster name: {0}" -f $cluster.name | Out-File -FilePath $summaryFile
"  Cluster id: {0}" -f $cluster.id | Out-File -FilePath $summaryFile -Append
"     Version: {0}" -f $cluster.clusterSoftwareVersion | Out-File -FilePath $summaryFile -Append
"  Node count: {0}" -f $cluster.nodeCount | Out-File -FilePath $summaryFile -Append
"Domain Names: {0}" -f ($cluster.domainNames -join ', ') | Out-File -FilePath $summaryFile -Append
" DNS Servers: {0}" -f ($cluster.dnsServerIps -join ', ') | Out-File -FilePath $summaryFile -Append

api get viewBoxes | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'storageDomains.json')
api get clusterPartitions | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'clusterPartitions.json')
api get /smtpServer | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'smtp.json')
api get /snmp/config | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'snmp.json') 

# networking
api get interfaceGroups | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'interfaceGroups.json')
api get vlans?skipPrimaryAndBondIface=true | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'vlans.json')
api get /nexus/cluster/get_hosts_file | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'hosts.json')

# access management
api get activeDirectory | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'activeDirectory.json') 
api get idps?allUnderHierarchy=true | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'idps.json') 
api get ldapProvider | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'ldapProvider.json') 
api get roles | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'roles.json') 
api get users | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'users.json') 
api get groups | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'groups.json') 

# copy targets
api get remoteClusters | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'remoteClusters.json')
api get vaults | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'vaults.json')

# data protection
api get protectionSources?allUnderHierarchy=true | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'sources.json')
api get -v2 data-protect/policies?allUnderHierarchy=true | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'policies.json')
api get -v2 data-protect/protection-groups?allUnderHierarchy=true | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'jobs.json')

# file services
api get views?allUnderHierarchy=true | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'views.json')
api get externalClientSubnets | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'globalWhitelist.json')
api get shares | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath 'shares.json')
