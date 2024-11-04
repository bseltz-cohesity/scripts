    ### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username
    [Parameter()][string]$domain = 'local', # Cohesity user domain name
    [Parameter()][string]$serverList, # file with servers to add as Oracle sources
    [Parameter()][string]$server, # one server to add as an Oracle source
    [Parameter()][string]$dbUser, # optional username for DB authentication
    [Parameter()][string]$dbPassword # optional password for DB authentication
)

# gather server list
if($serverList){
    $servers = get-content $serverList
}elseif($server){
    $servers = @($server)
}else{
    Write-Warning "No Servers Specified"
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get protection sources
$oracleSources = api get protectionSources?environments=kOracle
$phys = api get protectionSources?environments=kPhysical

foreach ($server in $servers){
    $server = $server.ToString()
    $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
    if (!$sourceId){
        # register physical server if not already registered
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
        # see if server is already registered as Oracle
        if($oracleSources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}){
            Write-Host "$server is already registered as an Oracle protection source" -ForegroundColor Blue
            break
        }
        # register server as Oracle
        "Registering $server as an Oracle protection source..."
        Start-Sleep 5
        $regOracle = @{"ownerEntity" = @{"id" = $sourceId}; "appEnvVec" = @(19)}
        if($dbUser -and $dbPassword){
            $regOracle['appCredentialsVec'] = @(
                @{
                    "envType" = 19;
                    "credentials" = @{
                        "username" = $dbUser;
                        "password" = $dbPassword
                    }
                }
            )        
        }
        $null = api post /applicationSourceRegistration $regOracle
    }
    else {
        Write-Host "failed to register $server" -ForegroundColor Yellow
    }
}
