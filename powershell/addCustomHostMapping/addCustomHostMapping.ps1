### usage: ./archiveOldSnapshots.ps1 -vip mycluster -username admin [ -domain local ] -vault S3 -olderThan 365 [ -IfExpiringAfter 30 ] [ -keepFor 365 ] [ -archive ]
# version 5

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$ip, #ip address of host mapping
    [Parameter(Mandatory = $True)][string[]]$hostNames #one or more host names (comma separated)
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get host mappings
$hosts = api get /nexus/cluster/get_hosts_file

### add new host mapping
$hosts.hosts += @{ 'ip' = $ip; 'domainName' = $hostNames}
$result = api put /nexus/cluster/upload_hosts_file $hosts
write-host $result.message -ForegroundColor Green
