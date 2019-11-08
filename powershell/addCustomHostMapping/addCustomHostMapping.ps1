### usage: ./addCustomHostMapping.ps1 -vip mycluster -username admin [ -domain local ] -ip ipaddress -hostNames myserver, myserver.mydomain.net

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

"$hostNames"
### add new host mapping
$hosts.hosts = @($hosts.hosts + @{ 'ip' = $ip; 'domainName' = @($hostNames)})
$hosts | setApiProperty 'validate' $True
$result = api put /nexus/cluster/upload_hosts_file $hosts
write-host $result.message -ForegroundColor Green
