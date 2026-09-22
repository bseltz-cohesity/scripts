### usage: ./resetUserPassword.ps1 -vip mycluster `
#                                   -username admin `
#                                   -domain local `
#                                   -targetUsername jsmith `
#                                   -newPassword 'NewP@ssw0rd!'
#
# resets the password of a LOCAL Cohesity user (e.g. after a lockout or forgotten password)
# if -newPassword is not specified, you will be prompted to enter and confirm one
# (or use -generatePassword to have the script create a random strong password for you)

# process commandline arguments
[CmdletBinding()]
param (
    # connection/authentication parameters (see baseAuth.ps1)
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    # target user / new password parameters
    [Parameter(Mandatory = $True)][string]$targetUsername,
    [Parameter()][string]$newPassword,
    [Parameter()][switch]$generatePassword
)

# password resets are only supported for LOCAL Cohesity users
$targetDomain = 'LOCAL'

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# find the target user =========================================
$targetLocation = $vip
if($USING_HELIOS){
    $targetLocation = $clusterName
}

Write-Host "Looking up user $targetUsername..."
$existingUsers = api get -v2 "users?usernames=$targetUsername&domain=$targetDomain"
$targetUser = @($existingUsers.users | Where-Object {$_.username -eq $targetUsername})

if(!$targetUser -or $targetUser.Count -eq 0){
    Write-Host "User $targetUsername not found on $targetLocation" -ForegroundColor Yellow
    exit 1
}

if($targetUser.Count -gt 1){
    Write-Host "Multiple LOCAL users matched ${targetUsername}:" -ForegroundColor Yellow
    $targetUser | Select-Object -Property username, domain, sid | Format-Table -AutoSize
    exit 1
}

$targetUser = $targetUser[0]
# end find the target user =====================================

# determine the new password ===================================
if(!$newPassword){
    if($generatePassword){
        $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*'
        $newPassword = -join (1..16 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    }elseif(!$noPrompt){
        $confirmPassword = $null
        while($newPassword -cne $confirmPassword -or [string]::IsNullOrEmpty($newPassword)){
            $secureNewPassword = Read-Host -Prompt "Enter new password for $($targetUser.username)" -AsSecureString
            $secureConfirmPassword = Read-Host -Prompt "Confirm new password" -AsSecureString
            $newPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureNewPassword))
            $confirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureConfirmPassword))
            if($newPassword -cne $confirmPassword){
                Write-Host "Passwords do not match" -ForegroundColor Yellow
            }
        }
    }else{
        Write-Host "-newPassword or -generatePassword is required when -noPrompt is specified" -ForegroundColor Yellow
        exit 1
    }
}
# end determine the new password ================================

# reset the password =============================================
# UpdateUser is a PUT (full replace), so start from the user's existing
# properties (from the GET above) rather than sending only username/password,
# otherwise settings like roles, restricted, locked, etc. would be cleared
$updateParams = @{
    'username' = $targetUser.username
}

foreach($prop in 'description', 'effectiveTimeMsecs', 'expiryTimeMsecs', 'locked', 'restricted', 'roles'){
    if($targetUser.PSObject.Properties[$prop]){
        $updateParams[$prop] = $targetUser.$prop
    }
}

$updateParams['localUserParams'] = @{
    'password' = $newPassword
}
if($targetUser.localUserParams -and $targetUser.localUserParams.PSObject.Properties['email']){
    $updateParams['localUserParams']['email'] = $targetUser.localUserParams.email
}

Write-Host "Resetting password for $($targetUser.username)..."
$result = api put -v2 "users/$($targetUser.sid)" $updateParams

if($result){
    Write-Host "Password reset successfully for $($targetUser.username)" -ForegroundColor Green
    if($generatePassword){
        Write-Host "New password: $newPassword" -ForegroundColor Green
    }
}else{
    Write-Host "Password reset failed for $($targetUser.username): $($cohesity_api.last_api_error)" -ForegroundColor Yellow
    exit 1
}
# end reset the password ==========================================
