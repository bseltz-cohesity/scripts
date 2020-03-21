    ### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][string]$server
)

if($serverList){
    $servers = get-content $serverList
}elseif($server){
    $servers = @($server)
}else{
    Write-Warning "No Servers Specified"
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get protection sources
$oracleSources = api get protectionSources?environments=kOracle
$phys = api get protectionSources?environments=kPhysical

### register server as SQL
foreach ($server in $servers){
    $server = $server.ToString()
    $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
    if (!$sourceId){
        # register physical server
        "Registering $server as a physical protection source..."
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
        if($result){
            $sourceId = $result.entity.id
        }
    }
    if ($sourceId) {
        if($oracleSources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}){
            Write-Host "$server is already registered as an Oracle protection source" -ForegroundColor Blue
            break
        }
        "Registering $server as an Oracle protection source..."
        $regOracle = @{"ownerEntity" = @{"id" = $sourceId}; "appEnvVec" = @(19)}
        $null = api post /applicationSourceRegistration $regOracle
    }
    else {
        Write-Host "$server is not registered as a protection source" -ForegroundColor Yellow
    }
}
