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
    [Parameter()][string]$currentPassword,
    [Parameter()][string]$newPassword,
    [Parameter()][switch]$enableSudoAccess
)

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

if(! $newPassword){
    $newPassword = '1'
    $newPassword2 = '2'
    while($newPassword -ne $newPassword2){
        $secureString = Read-Host -Prompt "   Enter new support password" -AsSecureString
        $secureString2 = Read-Host -Prompt "Confirm new support password" -AsSecureString
        $newPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
        $newPassword2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString2))
        if($newPassword -ne $newPassword2){
            Write-Host "Passwords do not match`n" -foregroundcolor Yellow
        }
    }
}

if(! $currentPassword){
    $currentPassword = $newPassword
}

# support account
Write-Host "Setting support password..."
$supportCreds = @{
    "linuxUsername" = "support";
    "linuxPassword" = "$newPassword";
    "linuxCurrentPassword" = "$currentPassword"
}

$null = api put users/linuxPassword $supportCreds

if($enableSudoAccess){
    Write-Host "Enabling sudo access..."
    $null = api put users/linuxSupportUserSudoAccess @{"sudoAccessEnable" = $True}
}
