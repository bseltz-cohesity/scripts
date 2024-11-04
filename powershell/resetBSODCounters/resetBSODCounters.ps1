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
    [Parameter()][switch]$restartAgent,
    [Parameter()][switch]$reboot
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

$servers = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $false)

if($servers.Count -eq 0){
    
    # source the cohesity-api helper code
    . $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

    # authentication =============================================
    # demand clusterName for Helios/MCM
    if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
        Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
        exit 1
    }

    # authenticate
    apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

    # exit on failed authentication
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated" -ForegroundColor Yellow
        exit 1
    }

    # select helios/mcm managed cluster
    if($USING_HELIOS){
        $thisCluster = heliosCluster $clusterName
        if(! $thisCluster){
            exit 1
        }
    }
    # end authentication =========================================

    # find servers protected by block-based physical protection groups
    $jobs = api get -v2 "data-protect/protection-groups?environments=kPhysical&isActive=true"
    $sources = api get "protectionSources/registrationInfo?environments=kPhysical"
    $winIds = @(($sources.rootNodes | Where-Object {$_.rootNode.physicalProtectionSource.hostType -eq 'kWindows'}).rootNode.id)
    $servers = @(($jobs.protectionGroups.physicalParams.volumeProtectionTypeParams.objects | Where-Object {$_.id -in $winIds}).name)
}

if($servers.Count -eq 0){
    Write-Host "No servers specified"
}

$myComputerName = $env:computername

foreach ($server in $servers){
    $server = $server.ToString()
    $thisServer = ($server -split '\.')[0]
    if($thisServer -eq $myComputerName){
        Write-Host "$server ==> skipping (this computer)" -ForegroundColor Yellow
        continue
    }

    # update registry key
    Write-Host "$server ==> updating registry"
    $null = Invoke-Command -Computername $server -ScriptBlock {
        $keyName = 'HKLM:\SYSTEM\CurrentControlSet\Services\CBTFlt'
        $flagName = 'BSODTolerenceCounter'
        $flagValue = 0
        $existingFlag = Get-ItemProperty -Path $keyName -Name $flagName -ErrorAction SilentlyContinue
        if($existingFlag){
            # edit existing entry
            $null = Set-Itemproperty -path $keyName -Name $flagName -value $flagValue
        }
    }

    # restart Cohesity agent
    if($restartAgent -and !$reboot){
        Write-Host "$server ==> restarting agent"
        $null = Invoke-Command -Computername $server -ScriptBlock {
            Restart-Service -Name CohesityAgent
        }
    }

    # reboot
    if($reboot){
        $thisServer = ($server -split '\.')[0]
        if($thisServer -eq $myComputerName){
            Write-Host "$server ==> skipping reboot (this computer)"
        }else{
            Write-Host "$server ==> Rebooting"
            Restart-Computer -ComputerName $server -Force
        }
    }
}
