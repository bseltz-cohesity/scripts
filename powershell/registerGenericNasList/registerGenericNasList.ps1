### usage: 
# ./registerGenericNasList.ps1 -vip bseltzve01 `
#                              -username admin `
#                              -domain mydomain.net `
#                              -nasList ./nasList.txt `
#                              -smbUserName mydomain\myusername

### provide a list of mount points in a text file

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$nasList, #protection source name of the netapp
    [Parameter()][string]$smbUserName = '' #name of the svm (child of the netapp)
 )

if ($smbUserName -ne ''){
    $securePassword = Read-Host -Prompt "Please enter password for $smbUserName" -AsSecureString
    $cred = New-Object -TypeName System.Net.NetworkCredential
    $cred.SecurePassword = $securePassword
    $smbPassword = $cred.Password
}

$pathList = Get-Content $nasList

### source the cohesity-api helper code
. ./cohesity-api


### authenticate
apiauth -vip $vip -username $username -domain $domain

foreach ($nasPath in $pathList) {
    $nasPath = $nasPath.ToString()
    $newSource = @{}

    if ($nasPath.Contains('\')) {
        $protocol = 2 #SMB
        if ($smbUserName.Contains('\')) {
            $domainName, $smbUserName = $smbUserName.Split('\')
        }
        $credentials = @{
            'username'            = '';
            'password'            = '';
            'nasMountCredentials' = @{
                'protocol' = 2;
                'username' = $smbUserName;
                'password' = $smbPassword
            }
        }
        if ($domainName) {
            $credentials.nasMountCredentials['domainName'] = $domainName
        }
    }
    else {
        $protocol = 1 #NFS
    }
    
    $newSource = @{
        'entity'     = @{
            'type'             = 11;
            'genericNasEntity' = @{
                'protocol' = $protocol;
                'type'     = 1;
                'path'     = $nasPath
            }
        };
        'entityInfo' = @{
            'endpoint' = $nasPath;
            'type'     = 11
        };
        'registeredEntityParams' = @{
            'genericNasParams' = @{
              'skipValidation' = $true
            }
        }
    }
    
    if ($protocol -eq 2) {
        $newSource.entityInfo['credentials'] = $credentials
    }

    if($nasPath -ne ''){
        "Registering $nasPath"
        $null = api post /backupsources $newSource
    }
}
