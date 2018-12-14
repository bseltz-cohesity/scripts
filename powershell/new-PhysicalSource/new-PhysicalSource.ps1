### usage: ./new-PhysicalSource.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -server win2016.mydomain.com

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter(Mandatory = $True)][string]$server #Server to add as physical source
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$newSource = @{
    'entity' = @{
        'type' = 6;
        'physicalEntity' = @{
            'name' = $server;
            'type' = 1;
            'hostType' = 1
        }
    };
    'entityInfo' = @{
        'endpoint' = $server;
        'type' = 6;
        'hostType' = 1
    };
    'sourceSideDedupEnabled' = $true;
    'throttlingPolicy' = @{
        'isThrottlingEnabled' = $false
    };
    'forceRegister' = $false
}

$result = api post /backupsources $newSource
if($result){
    "New Physical Server Registered. ID: $($result.id)"
}