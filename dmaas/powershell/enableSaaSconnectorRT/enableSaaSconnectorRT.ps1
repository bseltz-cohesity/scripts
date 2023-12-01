# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][string]$vip,
    [Parameter()][string]$username = 'admin',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$enable,
    [Parameter()][switch]$disable,
    [Parameter()][int]$days = 1
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
# apiauth_legacy -vip $vip -username $username -domain $domain -passwd $password -noPromptForPassword $noPrompt
apiauth -vip $vip -username $username -passwd $password -noPromptForPassword $noPrompt -noDomain

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$dayUsecs = dateToUsecs ((Get-Date).AddDays($days))

if($enable){
    Write-Host "Enabling support channel..."
    $result = api put -v2 support-channel-config @{'isEnabled' = $true; 'endTimeUsecs' = $dayUsecs}
}
if($disable){
    Write-Host "Disabling support channel..."
    $result = api put -v2 support-channel-config @{'isEnabled' = $false; 'endTimeUsecs' = 1673728458000000}
    exit
}

$cluster = api get cluster
$supportToken = ''
while($supportToken -eq ''){
    Start-Sleep 5
    $token = api put users/linuxSupportUserBashShellAccess
    $supportToken = $token.supportUserToken
}

Write-Host "`nCluster ID and Token for SaaS Connector:"
Write-Host "$($cluster.id) $($supportToken)`n" -ForegroundColor Cyan
