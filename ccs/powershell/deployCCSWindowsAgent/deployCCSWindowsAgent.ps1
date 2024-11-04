### usage: ./deployWindowsAgent.ps1 -vip bseltzve01 -username admin -serverList ./servers.txt [ -installAgent ] [ -register ] [ -registerSQL ] [ -serviceAccount mydomain.net\myuser ]
### provide a list of servers in a text file
### specify any of -installAgent -register -registerSQL -serviceAccount -storePassword

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter(Mandatory=$True)][string]$region,
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][string]$serverName,
    [Parameter()][switch]$storePassword,
    [Parameter()][switch]$installAgent,
    [Parameter()][switch]$register,
    [Parameter()][switch]$registerSQL,
    [Parameter()][switch]$sqlCluster,
    [Parameter()][string]$serviceAccount = $null,
    [Parameter()][string]$filePath,
    [Parameter()][string]$saasConnector = $null,
    [Parameter()][string]$installType = 'onlyagent'
)

if($register -and !$saasConnector){
    Write-Host "-saasConnector required to register" -ForegroundColor Yellow
    exit
}

if($serverList){
    $servers = get-content $serverList
    }elseif($serverName) {
        $servers = @($serverName)
    }else{
        Write-Host "No Servers Specified" -ForegroundColor Yellow
        exit
    }
    
### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
Import-Module $(Join-Path -Path $PSScriptRoot -ChildPath userRights.psm1)

### function to set service account
Function Set-ServiceAcctCreds([string]$strCompName,[string]$strServiceName,[string]$newAcct,[string]$newPass){
    $filter = 'Name=' + "'" + $strServiceName + "'" + ''
    $service = Get-WMIObject -ComputerName $strCompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    $service.Change($null,$null,$null,$null,$null,$null,$newAcct,$newPass)
    $service.StopService()
    while ($service.Started){
      Start-Sleep 2
      $service = Get-WMIObject -ComputerName $strCompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    }
    $service.StartService()
}

# authentication =============================================
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# end authentication =========================================

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId

### get sqlAccount Password
if($serviceAccount){
    $sqlPassword = Get-CohesityAPIPassword -vip windows -username $serviceAccount
    if(!$sqlPassword){
        $securePassword = Read-Host -AsSecureString -Prompt "Enter password for $serviceAccount"
        $sqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $securePassword ))
        if($storePassword){
            Set-CohesityAPIPassword -vip windows -username $serviceAccount -pwd $sqlPassword
        }
    }
}

if($sqlCluster){
    $entityType = 2
}else{
    $entityType = 1
}

$remoteFilePath = ''
### download agent installer to local host
if ($installAgent) {
    if(!$filePath){
        $downloadsFolder = join-path -path $([Environment]::GetFolderPath("UserProfile")) -ChildPath downloads
        $images = api get -mcmv2 data-protect/agents/images?platform=Windows
        $downloadURL = $images.agents[0].downloadURL
        $fileName = "cohesity-agent.exe"
        $filePath = join-path -path $downloadsFolder -ChildPath $fileName
        Write-Host "Downloading Windows agent to $filepath..."
        fileDownload -uri $downloadURL -fileName $filepath
    }else{
        $fileName = Split-Path $filePath -leaf
    }
    
    $remoteFilePath = Join-Path -Path "C:\Windows\Temp" -ChildPath $fileName
}

foreach ($server in $servers){
    $server = $server.ToString()
    "managing Cohesity Agent on $server"

    ### install Cohesity Agent
    if ($installAgent) {
        ### copy agent installer to server
        "`tcopying agent installer..."
        Copy-Item $filePath \\$server\c$\Windows\Temp

        ### install agent and open firewall port
        "`tinstalling Cohesity agent..."
        $null = Invoke-Command -Computername $server -ArgumentList $remoteFilePath -ScriptBlock {
            param($remoteFilePath)
            if (! $(Get-Service | Where-Object { $_.Name -eq 'CohesityAgent' })) {
                ([WMICLASS]"\\localhost\ROOT\CIMV2:win32_process").Create("$remoteFilePath /verySilent /norestart /type=$installType")
                New-NetFirewallRule -DisplayName 'Cohesity Agent' -Profile 'Domain' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 50051
            }
        }
    }

    ### register server as physical source
    if($register){
        "`tRegistering as Cohesity protection source..."
        $sources = api get -mcmv2 "data-protect/sources?regionIds=$region&environments=kPhysical"
        $saasConnectors = api get -mcmv2 "rigelmgmt/rigel-groups?regionIds=$region&tenantId=$tenantId&fetchConnectorGroups=true"
        $sc = $saasConnectors.rigelGroups | Where-Object {$_.groupName -eq $saasConnector}
        if(! $sc){
            Write-Host "SaaS connector $saasConnector not found" -ForegroundColor Yellow
            exit
        }
        $source = $sources.sources | Where-Object { $_.name -ieq $server }
        if(!$source){
            $newSource = @{
                "environment" = "kPhysical";
                "physicalParams" = @{
                    "endpoint" = $server;
                    "physicalType" = "kHost";
                    "hostType" = "kWindows"
                };
                "connectionId" = $sc.groupId
            }
            $result = api post -mcmv2 data-protect/sources/registrations $newSource -region $sc.regionId
            Start-Sleep 10
        }    
    }

    ### set service account
    if($serviceAccount){
        "`tSetting CohesityAgent Service Logon Account..."
        Grant-UserRight -Computer $server -User $serviceAccount -Right SeServiceLogonRight
        $null = Set-ServiceAcctCreds $server 'CohesityAgent' $serviceAccount $sqlPassword
    }

    ### register server as SQL
    if ($registerSQL) {
        if (! $($sources.rootNodes | Where-Object { $_.rootNode.name -eq $server -and $_.applications.environment -eq 'kSQL' })) {
            $sources = api get -mcmv2 "data-protect/sources?environments=kPhysical&regionId=$region"
            $source = $sources.sources | Where-Object { $_.name -ieq $server }
            if ($source) {
                Write-Host "`tRegistering as SQL protection source..."
                $regSQL = @{
                    "protectionSourceId" = $source.sourceInfoList[0].sourceId;
                    "applications" = @(
                        "kSQL"
                    );
                    "hasPersistentAgent" = $true
                }
                $result = api post protectionSources/applicationServers $regSQL -region $source.sourceInfoList[0].regionId
            }
            else {
                Write-Host "$server is not yet registered as a protection source" -foregroundcolor Yellow
            }
        }
    }
}
