[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

$credential = Get-Credential -Message "Enter Credentials for the Windows User"

$args = "write-host ('running as ' + [System.Security.Principal.WindowsIdentity]::GetCurrent().Name);
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1);
apiauth -vip {0} -username {1} -domain {2} -updatePassword;
pause;" -f $vip, $username, $domain

Start-Process powershell.exe -Credential $credential -ArgumentList ("-command $args")
