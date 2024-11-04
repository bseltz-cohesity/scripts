
### usage: ./tearDownVolumeMount.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -taskId 23998

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$taskId #source server that was backed up
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### tear down mount
$tearDownTask = api post /destroyclone/$taskId
"Tearing down mount points..."