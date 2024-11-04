### usage: 
# ./registerGenericNasList.ps1 -vip bseltzve01 `
#                              -username admin `
#                              -domain mydomain.net `
#                              -mountList ./mountList.txt `
#                              -smbUserName mydomain\myusername

### provide a list of mount points in a text file

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][string]$tenant,
    [Parameter()][array]$mountPoint, # nas path to register (comma separated)
    [Parameter()][string]$mountList, # text file of nas paths to register (one per line)
    [Parameter()][string]$smbUserName = '', # username to register smb paths
    [Parameter()][string]$smbPassword # password to register smb paths
 )

# prompt for smb password if needed
if ($smbUserName -ne ''){
    if(! $smbPassword){
        $securePassword = Read-Host -Prompt "Please enter password for $smbUserName" -AsSecureString
        $cred = New-Object -TypeName System.Net.NetworkCredential
        $cred.SecurePassword = $securePassword
        $smbPassword = $cred.Password
    }
}

# gather path list
$pathList = @()
if($mountList -and (Test-Path $mountList -PathType Leaf)){
    $pathList += Get-Content $mountList | Where-Object {$_ -ne ''}
}elseif($mountList){
    Write-Warning "File $mountList not found!"
    exit 1
}
if($mountPoint){
    $pathList += $mountPoint
}
if($pathList.Length -eq 0){
    Write-Host "No nas paths specified"
    exit 1
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -tenant $tenant

$sources = api get "protectionSources/registrationInfo?includeEntityPermissionInfo=true"

foreach ($nasPath in $pathList) {
    $nasPath = [string]$nasPath
    $existing = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $nasPath}

    if($existing){
        $existingSource = api get "/backupsources?allUnderHierarchy=true&entityId=$($existing.rootNode.id)&onlyReturnOneLevel=true"
        $updateParams = @{
            'entity' = $existingSource.entityHierarchy.entity;
            'entityInfo' = $existingSource.entityHierarchy.registeredEntityInfo.connectorParams;
        }
    }
    
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
        if($existingSource){
            $updateParams.entityInfo.credentials = $credentials
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
        if($existing){
            "Updating $nasPath"
            # $null = api put "/backupsources/$($existing.rootNode.id)" $updateParams
        }else{
            "Registering $nasPath"
            $null = api post /backupsources $newSource
        }
    }
}
