### usage: ./deployWindowsAgent.ps1 -vip bseltzve01 -username admin -serverList ./servers.txt [ -installAgent ] [ -register ] [ -registerSQL ] [ -serviceAccount mydomain.net\myuser ]
### provide a list of servers in a text file
### specify any of -installAgent -register -registerSQL -serviceAccount -storePassword

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][string]$vip,
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][string]$server,
    [Parameter()][switch]$storePassword,
    [Parameter()][switch]$installAgent,
    [Parameter()][switch]$register,
    [Parameter()][switch]$registerAD,
    [Parameter()][switch]$registerSQL,
    [Parameter()][switch]$sqlCluster,
    [Parameter()][string]$serviceAccount = $null,
    [Parameter()][string]$filepath
)

if($serverList){
    $servers = get-content $serverList
    }elseif($server) {
        $servers = @($server)
    }else{
        Write-Warning "No Servers Specified"
        exit
    }
    
### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
Import-Module $(Join-Path -Path $PSScriptRoot -ChildPath userRights.psm1)

### function to set service account
Function Set-ServiceAcctCreds([string]$strCompName,[string]$strServiceName,[string]$newAcct,[string]$newPass){
    $null = Invoke-Command -Computername $strCompName -ArgumentList $strServiceName, $newAcct, $newPass -ScriptBlock {
        param($strServiceName, $newAcct, $newPass)
        $filter = 'Name=' + "'" + $strServiceName + "'" + ''
        $service = Get-WMIObject -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
        $service.Change($null,$null,$null,$null,$null,$null,$newAcct,$newPass)
        $service.StopService()
        while ($service.Started){
            Start-Sleep 2
            $service = Get-WMIObject -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
        }
        $service.StartService()
        while(! $service.Started){
            Start-Sleep 2
            $service = Get-WMIObject -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
        }
    }
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -tenant $tenant -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

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

### get protection sources
$sources = api get protectionSources/registrationInfo

### download agent installer to local host
if ($installAgent) {
    if($filepath){
        $agentFile = $filepath
    }else{
        $downloadsFolder = join-path -path $([Environment]::GetFolderPath("UserProfile")) -ChildPath downloads
        $agentFile = "Cohesity_Agent_$(((api get cluster).clusterSoftwareVersion).split('_')[0])_Win_x64_Installer.exe"
        $filepath = join-path -path $downloadsFolder -ChildPath $agentFile
        fileDownload 'physicalAgents/download?hostType=kWindows' $filepath
    }
    $remoteFilePath = Join-Path -Path "C:\Windows\Temp" -ChildPath $agentFile
}

foreach ($server in $servers){
    $server = $server.ToString()
    "managing Cohesity Agent on $server"

    ### install Cohesity Agent
    if ($installAgent) {

        ### copy agent installer to server
        "`tcopying agent installer..."
        Copy-Item $filepath \\$server\c$\Windows\Temp

        ### install agent and open firewall port
        "`tinstalling Cohesity agent..."
        $null = Invoke-Command -Computername $server -ArgumentList $remoteFilePath -ScriptBlock {
            param($remoteFilePath)
            if (! $(Get-Service | Where-Object { $_.Name -eq 'CohesityAgent' })) {
                ([WMICLASS]"\\localhost\ROOT\CIMV2:win32_process").Create("$remoteFilePath /type=allcbt /verysilent /suppressmsgboxes /NORESTART")
                New-NetFirewallRule -DisplayName 'Cohesity Agent' -Profile 'Domain' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 50051
            }
        }
    }

    ### register server as physical source
    if($register){
        "`tRegistering as Cohesity protection source..."
        $sourceId = $null
        $phys = api get protectionSources?environments=kPhysical
        $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
        if($null -eq $sourceId){
            $newPhysicalSource = @{
                'entity' = @{
                    'type' = 6;
                    'physicalEntity' = @{
                        'name' = $server;
                        'type' = $entityType;
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
        
            $result = api post /backupsources $newPhysicalSource
            if($null -eq $result){
                continue
            } 
        }    
    }

    ### set service account
    if($serviceAccount){
        "`tSetting CohesityAgent Service Logon Account..."
        Grant-UserRight -Computer $server -User $serviceAccount -Right SeServiceLogonRight
        $null = Set-ServiceAcctCreds $server 'CohesityAgent' $serviceAccount $sqlPassword
    }

    ### register server as AD domain controller
    if ($registerAD){
        "`tRegistering as Active Directory Domain Controller..."
        $phys = api get protectionSources?environments=kPhysical
        $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
        $adParams = @{
            "ownerEntity" = @{
                "id" = $sourceId
            };
            "appEnvVec"   = @(
                29
            )
        }
        $null = api post /applicationSourceRegistration $adParams
    }

    ### register server as SQL
    if ($registerSQL) {
        if (! $($sources.rootNodes | Where-Object { $_.rootNode.name -eq $server -and $_.applications.environment -eq 'kSQL' })) {
            "`tRegistering as SQL protection source..."
            $phys = api get protectionSources?environments=kPhysical
            $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
            if ($sourceId) {
                $regSQL = @{"ownerEntity" = @{"id" = $sourceId}; "appEnvVec" = @(3)}
                $null = api post /applicationSourceRegistration $regSQL
            }
            else {
                Write-Warning "$server is not yet registered as a protection source"
            }
        }
    }
}
