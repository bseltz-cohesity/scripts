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

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$pathList = @(gatherList -Param $mountPoint -FilePath $mountList -Name 'paths' -Required $True)

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
