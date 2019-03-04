### usage: ./login-Cohesity.ps1 -Server mycluster -UserName myusername -Domain mydomain.net [ -UpdatePassword ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$Server, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$UserName, # username (local or AD)
    [Parameter()][string]$Domain = 'local', # local or AD domain
    [Parameter()][switch]$UpdatePassword = $false # force password prompt to store changed password
)

$pwdFile = '~/.CohesityPWD/' + $Server + '-' + $Domain + '-' + $UserName
$pwdPath = '~/.CohesityPWD'
$keyFile = '~/.ssh/id_rsa' # use the user's ssh private key as the keyFile on MAC/Linux

### create directory for stroring encrypted passwords
if(!(Test-Path $pwdPath)){
    New-Item -Path $pwdPath -ItemType Directory -Force | Out-Null
}

### prompt and store new password
if(!(Test-Path $pwdFile) -or $UpdatePassword){
    $secureStringPW = Read-Host -Prompt "Enter Password for $UserName on $Server" -AsSecureString
    if ($PSVersionTable.Platform -eq 'Unix'){
        $key = (Get-Content $keyFile -AsByteStream)[32..63]
        $encryptedPW = $secureStringPW | ConvertFrom-SecureString -Key $key
    }else{
        $encryptedPW = $secureStringPW | ConvertFrom-SecureString
    }
    $encryptedPW | Out-File $pwdFile
}else{
    $encryptedPW = Get-Content -Path $pwdFile
    if ($PSVersionTable.Platform -eq 'Unix'){
        $key = (Get-Content $keyFile -AsByteStream)[32..63]
        $secureStringPW = $encryptedPW | ConvertTo-SecureString -Key $key
    }else{
        $secureStringPW = $encryptedPW | ConvertTo-SecureString
    }
}

### create credential
if($Domain -ieq 'local'){
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $secureStringPW
}else{
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList "$Domain\$UserName", $secureStringPW
}
Connect-CohesityCluster -Server $Server -Credential $cred