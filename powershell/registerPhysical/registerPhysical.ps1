### usage: ./new-PhysicalSource.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -server win2016.mydomain.com

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter()][string]$serverName, #Server to add as physical source
    [Parameter()][string]$serverList
)

# gather view list
if($serverList){
    $servers = get-content $serverList
}elseif($serverName){
    $servers = @($serverName)
}else{
    Write-Host "No servers Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

foreach($server in $servers){
    $server = [string]$server
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
        'forceRegister' = $True
    }
    
    $result = api post /backupsources $newSource
    if($result.entity.id){
        "$server Registered"
    }
}

