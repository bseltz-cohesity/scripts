### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local'
)

# parse domain\username or username@domain
if($username.Contains('\')){
    $domain, $username = $username.Split('\')
}
if($username.Contains('@')){
    $username, $domain = $username.Split('@')
}

# prompt for password
$secureString = Read-Host -Prompt "Enter password for $domain\$username at $vip" -AsSecureString
$pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
$opwd = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pwd))

# pwfile path
$pwfile = $(Join-Path -Path $PSScriptRoot -ChildPath YWRtaW4)

$pwlist = Get-Content -Path $pwfile -ErrorAction SilentlyContinue
$updatedContent = ''
$foundPwd = $false
foreach($pwitem in $pwlist){
    $v, $d, $u, $cpwd = $pwitem.split(":", 4)
    # update existing
    if($v -eq $vip -and $d -eq $domain -and $u -eq $username){
        $foundPwd = $true
        $updatedContent += "{0}:{1}:{2}:{3}`n" -f $vip, $domain, $username, $opwd
    # other existing records    
    }else{
        if($pwitem -ne ''){
            $updatedContent += "{0}`n" -f $pwitem
        }
    }
}
# add new
if(!$foundPwd){
    $updatedContent += "{0}:{1}:{2}:{3}`n" -f $vip, $domain, $username, $opwd
}

$updatedContent | out-file -FilePath $pwfile
write-host "Password stored!" -ForegroundColor Green
