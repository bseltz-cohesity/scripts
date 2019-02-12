### usage: ./deployWindowsAgent.ps1 -vip bseltzve01 -username admin -serverList ./servers.txt [ -installAgent ] [ -register ] [ -registerSQL ] [ -sqlAccount mydomain.net\myuser ]
### provide a list of servers in a text file
### specify any of -installAgent -register -registerSQL -sqlAccount

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][string]$server,
    [Parameter()][switch]$installAgent,
    [Parameter()][switch]$register,
    [Parameter()][switch]$registerSQL,
    [Parameter()][switch]$sqlCluster,
    [Parameter()][string]$sqlAccount = $null
)

### source the cohesity-api helper code
. ./cohesity-api
Import-Module .\userRights.psm1

### function to set service account
Function Set-ServiceAcctCreds([string]$strCompName,[string]$strServiceName,[string]$newAcct,[string]$newPass){
    $filter = 'Name=' + "'" + $strServiceName + "'" + ''
    $service = Get-WMIObject -ComputerName $strCompName -namespace "root\cimv2" -class Win32_Service -Filter $filter
    $service.Change($null,$null,$null,$null,$null,$null,$newAcct,$newPass)
    $service.StopService()
    while ($service.Started){
      sleep 2
      $service = Get-WMIObject -ComputerName $strCompName -namespace "root\cimv2" -class Win32_Service -Filter $filter
    }
    $service.StartService()
}

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get sqlAccount Password
if($sqlAccount){
    $securePassword = Read-Host -AsSecureString -Prompt "Enter password for $sqlAccount"
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $sqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
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
    $downloadsFolder = join-path -path $([Environment]::GetFolderPath("UserProfile")) -ChildPath downloads
    $agentFile = $("cohesity-agent-windows" + (api get basicClusterInfo).clusterSoftwareVersion + ".exe")
    $filepath = join-path -path $downloadsFolder -ChildPath $agentFile
    fileDownload 'physicalAgents/download?hostType=kWindows' $filepath
    $remoteFilePath = Join-Path -Path "C:\Windows\Temp" -ChildPath $agentFile
}

if($serverList){
$servers = get-content $serverList
}elseif($server) {
    $servers = @($server)
}else{
    Write-Warning "No Servers Specified"
    exit
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
        $result = Invoke-Command -Computername $server -ArgumentList $remoteFilePath -ScriptBlock {
            param($remoteFilePath)
            if (! $(Get-Service | Where-Object { $_.Name -eq 'CohesityAgent' })) {
                ([WMICLASS]"\\localhost\ROOT\CIMV2:win32_process").Create("$remoteFilePath /type=allcbt /verysilent /supressmsgboxes /norestart")
                New-NetFirewallRule -DisplayName 'Cohesity Agent' -Profile 'Domain' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 50051
            }
        }
    }

    ### register server as physical source
    if($register){
        "`tRegistering as Cohesity protection source..."
        $sourceId = $null
        while($null -eq $sourceId){
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
                    'forceRegister' = $false
                }
            
                $result2 = api post /backupsources $newPhysicalSource     
            }    
        }
    }

    ### set service account
    if($sqlAccount){
        "`tSetting CohesityAgent Service Logon Account..."
        Grant-UserRight -Computer $server -User $sqlAccount -Right SeServiceLogonRight
        $result3 = Set-ServiceAcctCreds $server 'CohesityAgent' $sqlAccount $sqlPassword
    }

    ### register server as SQL
    if ($registerSQL) {
        if (! $($sources.rootNodes | Where-Object { $_.rootNode.name -eq $server -and $_.applications.environment -eq 'kSQL' })) {
            "`tRegistering as SQL protection source..."
            $phys = api get protectionSources?environments=kPhysical
            $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
            if ($sourceId) {
                $regSQL = @{"ownerEntity" = @{"id" = $sourceId}; "appEnvVec" = @(3)}
                $result4 = api post /applicationSourceRegistration $regSQL
            }
            else {
                Write-Warning "$server is not yet registered as a protection source"
            }
        }
    }
}
