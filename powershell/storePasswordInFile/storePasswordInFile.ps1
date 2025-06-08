# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][switch]$skipValidation
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if(!$password){
    $password = '1'
    $confirmPassword = '2'
    while($password -ne $confirmPassword){
        $secureString = Read-Host -Prompt "`n  enter password" -AsSecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        $secureString = Read-Host -Prompt "confirm password" -AsSecureString
        $confirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        if($confirmPassword -ne $password){
            Write-Host "passwords do not match!" -ForegroundColor Yellow
        }
    }
}

if(!$skipValidation){
    Write-Host "`nValidating password"
    # authentication =============================================
    apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $True -quiet

    # exit on failed authentication
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated" -ForegroundColor Yellow
        exit 1
    }
    # end authentication =========================================
}

# authenticate
if($useApiKey){
    storePasswordInFile -vip $vip -username $username -domain $domain -passwd $password -useApiKey
}else{
    storePasswordInFile -vip $vip -username $username -domain $domain -passwd $password
}
