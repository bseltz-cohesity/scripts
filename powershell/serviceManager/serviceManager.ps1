### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$serviceNames,
    [Parameter()][switch]$start,
    [Parameter()][switch]$stop,
    [Parameter()][switch]$restart,
    [Parameter()][switch]$nowait,
    [Parameter()][int]$sleepSecs = 10
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

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

$serviceStates = api get clusters/services/states
if($serviceNames){
    $serviceStates = $serviceStates | Where-Object service -in $serviceNames
}

$finishedStates = @('kServiceRunning', 'kServiceStopped')

if($serviceNames -and ($stop -or $start -or $restart)){
    if($stop){
        $action = 'kStop'
    }elseif($start){
        $action = 'kStart'
    }else{
        $action = 'kRestart'
    }
    $result = api post clusters/services/states @{'action' = $action; 'services' = @($serviceStates.service)}
    if($result -and $result.PSObject.Properties['message']){
        Write-Host "`n$($result.message)"
    }else{
        exit
    }
    if(! $nowait){
        $allFinished = $false
        While($allFinished -eq $false){
            Start-Sleep $sleepSecs
            $serviceStates = api get clusters/services/states
            if($serviceNames){
                $serviceStates = $serviceStates | Where-Object service -in $serviceNames
            }
            $allFinished = $True
            foreach($service in $serviceStates){
                if($service.state -notin $finishedStates){
                    $allFinished = $false
                }
            }
        }
        $serviceStates | Sort-Object -Property service
    }
}else{
    $serviceStates | Sort-Object -Property service
}
