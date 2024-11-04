### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][array]$pause,
    [Parameter()][array]$resume,
    [Parameter()][array]$terminate,
    [Parameter()][switch]$wait
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

$apps = api get apps | Where-Object installState -eq 'kInstalled'
$appInstances = api get appInstances

$waitForApps = @()
$transitionalStates = @('kInitializing', 'kTerminating', 'kPausing')

Write-Host ''

foreach($thisapp in $apps | Sort-Object -Property {$_.metadata.name}){
    $appName = $thisapp.metadata.name
    $appInstance = $appInstances | Where-Object {$_.appName -eq $thisapp.metadata.name -and $_.state -ne 'kTerminated'}
    if($appInstance){
        $appInstanceId = $appInstance.appInstanceId
        if($appInstance.state -eq 'kRunning'){
            $appState = '     Running'
            if($appName -in $pause){
                $null = api put "appInstances/$appInstanceId/states" @{"state" = "kPaused"}
                $appState = '     Pausing'
                $waitForApps = @($waitForApps + $appInstanceId)
            }
            if($appName -in $terminate){
                $null = api put "appInstances/$appInstanceId/states" @{"state" = "kTerminated"}
                $appState = ' Terminating'
                $waitForApps = @($waitForApps + $appInstanceId)
            }
        }elseif($appInstance.state -eq 'kPaused'){
            $appState = '      Paused'
            if($appName -in $resume){
                $null = api put "appInstances/$appInstanceId/states" @{"state" = "kRunning"}
                $appState = 'Initializing'
                $waitForApps = @($waitForApps + $appInstanceId)
            }
            if($appName -in $terminate){
                $null = api put "appInstances/$appInstanceId/states" @{"state" = "kTerminated"}
                $appState = ' Terminating'
                $waitForApps = @($waitForApps + $appInstanceId)
            }
        }elseif($appInstance.state -eq 'kPausing'){
            $appState = '     Pausing'
            $waitForApps = @($waitForApps + $appInstanceId)
        }elseif($appInstance.state -eq 'kInitializing'){
            $appState = 'Initializing'
            $waitForApps = @($waitForApps + $appInstanceId)
        }elseif($appInstance.state -eq 'kTerminating'){
            $appState = ' Terminating'
            $waitForApps = @($waitForApps + $appInstanceId)
        }else{
            $appState = $appInstance.state
        }
        Write-Host "$($appState)  $($thisapp.metadata.name) - $($thisapp.metadata.devVersion)"
    }
}

Write-Host ''

if($wait){
    $waitForApps = @($waitForApps | Sort-Object -Unique)
    if($waitForApps.Count -gt 0){
        Write-Host "Waiting for app states to complete transition..."
        $stillWaiting = $True
        while($stillWaiting -eq $True){
            $stillWaiting = $false
            Start-Sleep 5
            $appInstances = api get appInstances
            foreach($appInstanceId in $waitForApps){
                $appInstance = $appInstances | Where-Object appInstanceId -eq $appInstanceId
                if($appInstance -and $appInstance.state -in $transitionalStates){
                    $stillWaiting = $True
                }
            }
        }
        Write-Host ''
    }
}
