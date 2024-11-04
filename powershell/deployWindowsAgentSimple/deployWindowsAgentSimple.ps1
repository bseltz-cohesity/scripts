### usage: ./deployWindowsAgent.ps1 -vip bseltzve01 -username admin -serverList ./servers.txt [ -installAgent ] [ -register ] [ -registerSQL ] [ -serviceAccount mydomain.net\myuser ]
### provide a list of servers in a text file
### specify any of -installAgent -register -registerSQL -serviceAccount -storePassword

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][string]$serverName,
    [Parameter()][switch]$storePassword,
    [Parameter()][switch]$installAgent,
    [Parameter()][string]$serviceAccount = $null,
    [Parameter(Mandatory=$True)][string]$filepath
)

. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($serverList){
    $servers = get-content $serverList
}elseif($serverName) {
    $servers = @($serverName)
}else{
    Write-Warning "No Servers Specified"
    exit
}

$remoteFilePath = Join-Path -Path "C:\Windows\Temp" -ChildPath $filepath

Import-Module $(Join-Path -Path $PSScriptRoot -ChildPath userRights.psm1)

### function to set service account
Function Set-ServiceAcctCreds([string]$strCompName,[string]$strServiceName,[string]$newAcct,[string]$newPass){
    $null = Invoke-Command -Computername $strCompName -ArgumentList $strServiceName, $newAcct, $newPass -ScriptBlock {
        param($strServiceName, $newAcct, $newPass)
        $filter = 'Name=' + "'" + $strServiceName + "'" + ''
        $service = Get-WMIObject -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
        $service.Change($null,$null,$null,$null,$null,$null,$newAcct,$newPass)
        $null = Restart-Service -Name $strServiceName
    }
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
                ([WMICLASS]"\\localhost\ROOT\CIMV2:win32_process").Create("$remoteFilePath /type=allcbt /verysilent /suppressmsgboxes /norestart")
                New-NetFirewallRule -DisplayName 'Cohesity Agent' -Profile 'Domain' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 50051
            }
        }
    }

    ### set service account
    if($serviceAccount){
        "`tSetting CohesityAgent Service Logon Account..."
        Grant-UserRight -Computer $server -User $serviceAccount -Right SeServiceLogonRight
        $null = Set-ServiceAcctCreds $server 'CohesityAgent' $serviceAccount $sqlPassword
    }
}
