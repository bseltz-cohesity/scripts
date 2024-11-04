### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$currentPassword = $null,
    [Parameter()][string]$newPassword = $null,
    [Parameter()][string]$confirmNewPassword = $null 
)

if(! $currentPassword){
    $secureString = Read-Host -Prompt "current password" -AsSecureString
    $currentPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

if(! $newPassword){
    $secureString = Read-Host -Prompt "new password" -AsSecureString
    $newPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

if(! $confirmNewPassword){
    $secureString = Read-Host -Prompt "confirm new password" -AsSecureString
    $confirmNewPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

if($newPassword -cne $confirmNewPassword){
    Write-Host "new password does not match on confirmation" -ForegroundColor Yellow
    exit 1
}else{
    ### authenticate
    $HEADER = @{'accept' = 'application/json'; 
    'content-type' = 'application/json'}

    $BODY = ConvertTo-Json @{'domain' = 'local'; 
                'username' = $username; 
                'password' = $currentPassword}

    $URL = "https://$vip/login"
    $user = Invoke-RestMethod -Method Post -Uri $URL -Header $HEADER -Body $BODY -SkipCertificateCheck -SessionVariable session

    ### update password
    $user.user | Add-Member -MemberType NoteProperty -Name 'currentPassword' -Value $currentPassword
    $user.user | Add-Member -MemberType NoteProperty -Name 'password' -Value $newPassword
    Write-Host "Setting password..."
    $URL = "https://$vip/irisservices/api/v1/public/users"
    $userupdate = Invoke-RestMethod -Method Put -Uri $URL -Header $HEADER -Body ($user.user | ConvertTo-Json) -SkipCertificateCheck -WebSession $session
}
