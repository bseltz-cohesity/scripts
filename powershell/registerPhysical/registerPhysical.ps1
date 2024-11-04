### usage: ./new-PhysicalSource.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -server win2016.mydomain.com

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][string]$serverName, #Server to add as physical source
    [Parameter()][string]$serverList,
    [Parameter()][switch]$force,
    [Parameter()][switch]$reRegister
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

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$forceRegister = $false
if($force){
    $forceRegister = $True
}

foreach($server in $servers){
    $server = [string]$server
    $registeredSource = (api get "protectionSources/registrationInfo?includeEntityPermissionInfo=true").rootNodes | Where-Object { $_.rootNode.name -eq $server }
    if($registeredSource -and ! $reRegister){
        "$server is already registered"
    }else{
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
            'forceRegister' = $forceRegister
        }
        if($reRegister){
            $newSource['reRegister'] = $True
        }
        $result = api post /backupsources $newSource
        if($result.entity.id){
            "$server Registered"
        }
    }
}
