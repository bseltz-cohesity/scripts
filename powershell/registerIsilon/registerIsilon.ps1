### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # do not prompt for password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter(Mandatory = $True)][string]$sourceName, # name of isilon to register
    [Parameter(Mandatory = $True)][string]$apiUser, # user to connect to Isilon API
    [Parameter()][string]$apiPassword, # Isilon API password
    [Parameter()][string]$smbUser, # SMB username
    [Parameter()][string]$smbPassword, # SMB password
    [Parameter()][array]$blackListIP,
    [Parameter()][string]$blackList
)

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

$blacklistIPs = @(gatherList -Param $blackListIP -FilePath $blackList -Name 'blackList IPs' -Required $False)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# prompt for passwords
if(! $apiPassword){
    $secureString = Read-Host -Prompt "Enter Password for API user $apiUser" -AsSecureString
    $apiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

if($smbUser -and ! $smbPassword){
    $secureString = Read-Host -Prompt "Enter Password for SMB user $smbUser" -AsSecureString
    $smbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

if($smbUser -match '\\'){
    $smbDomain, $smbUser = $smbUser -split '\\'
}

$newSourceParams = @{
    "entity" = @{
        "type" = 14;
        "isilonEntity" = @{
            "type" = 0
        }
    };
    "entityInfo" = @{
        "endpoint" = $sourceName;
        "credentials" = @{
            "username" = $apiUser;
            "password" = $apiPassword
        };
        "type" = 14
    };
    "registeredEntityParams" = @{}
}

if($smbuser){
    $newSourceParams.entityInfo.credentials['nasMountCredentials'] = @{
        "protocol" = 2;
        "username" = $smbUser;
        "password" = $smbPassword;
        "domainName" = $smbDomain;
    }
}

if($blacklistIPs.Count -gt 0){
    $newSourceParams.registeredEntityParams['blacklistedIpAddrs'] = $blacklistIPs
}

Write-Host "Registering $sourceName..."
$null = api post /backupsources $newSourceParams
