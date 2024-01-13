# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$serverName,
    [Parameter()][string]$serverList,
    [Parameter()][switch]$force
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$servers = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$forceRegister = $false
if($force){
    $forceRegister = $True
}

$registeredSources = api get "protectionSources/registrationInfo"

foreach($server in $servers){
    $entityId = $null
    $alreadyAD = $false
    $server = [string]$server
    Write-Host $server -NoNewline
    $registeredSource = $registeredSources.rootNodes | Where-Object { $_.rootNode.name -eq $server }
    if($registeredSource){
        $entityId = $registeredSource.rootNode.id
        if($registeredSource.applications | Where-Object environment -eq kAD){
            $alreadyAD = $True
        }
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
        Write-Host ": registering as Physical" -NoNewline
        $result = api post /backupsources $newSource -quiet
        if($result.entity.id){
            $entityId = $result.entity.id
            Start-Sleep 10
        }else{
            Write-Host ": failed to register" -ForegroundColor Yellow
            continue
        }
    }
    # register AD
    if(!$alreadyAD){
        Write-Host ": registering as Active Directory"
        $regAD = @{"ownerEntity" = @{"id" = $entityId}; "appEnvVec" = @(29)}
        $result = api post /applicationSourceRegistration $regAD
    }else{
        Write-Host ": already registered as Active Directory"
    }
}
