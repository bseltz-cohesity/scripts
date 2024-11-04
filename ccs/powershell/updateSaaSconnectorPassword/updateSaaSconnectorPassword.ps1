# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][string]$vip,
    [Parameter()][string]$currentPassword,
    [Parameter()][string]$newPassword = $null,
    [Parameter()][string]$confirmNewPassword = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if(! $currentPassword){
    $secureString = Read-Host -Prompt "current password" -AsSecureString
    $currentPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

# authenticate
apiauth -vip $vip -username 'admin' -passwd $currentPassword -noPromptForPassword $True -noDomain

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

if(! $newPassword){
    $secureString = Read-Host -Prompt "new password" -AsSecureString
    $newPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

while($confirmNewPassword -cne $newPassword){
    $secureString = Read-Host -Prompt "confirm new password" -AsSecureString
    $confirmNewPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    if($confirmNewPassword -cne $newPassword){
        Write-Host "passwords do not match!" -ForegroundColor Yellow
    }
}

$user = api get users | Where-Object username -eq 'admin'

$userParams = @{
    "sid" = $user.sid;
    "username" = $user.username;
    "roles" = @($user.roles);
    "password" = $newPassword;
    "currentPassword" = $currentPassword
}

$result = api put users $userParams