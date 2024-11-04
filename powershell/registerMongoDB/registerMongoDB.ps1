### usage: ./new-PhysicalSource.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -server win2016.mydomain.com

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # don't prompt for password
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][string]$serverName,
    [Parameter()][string]$serverList,
    [Parameter()][ValidateSet('NONE','SCRAM','LDAP','KERBEROS')][string]$authType = 'NONE',
    [Parameter()][string]$authUsername = $null,
    [Parameter()][string]$authPassword = $null,
    [Parameter()][string]$authDatabase = $null,
    [Parameter()][string]$krbPrincipal = $null,
    [Parameter()][string]$secondaryTag = $null,
    [Parameter()][switch]$useSSL,
    [Parameter()][switch]$useSecondary
)

# gather view list
if($serverList){
    $servers = get-content $serverList
}elseif($serverName){
    $servers = @($serverName)
}else{
    Write-Host "No servers Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

foreach($server in $servers){
    $server = [string]$server
    $server = $server.replace(' ', '')
    $seeds = @($server -split ',')
    $registeredSource = (api get "protectionSources/registrationInfo?environments=kMongoDB").rootNodes | Where-Object { $_.rootNode.name -eq $seeds[0] }
    if($registeredSource){
        Write-Host "$server is already registered" -ForegroundColor Yellow
    }else{
        $newSource = @{
            "environment" = "kMongoDB";
            "mongodbParams" = @{
                "hosts" = $seeds;
                "authType" = $authType.ToUpper();
                "username" = $authUsername;
                "password" = $authPassword;
                "authenticatingDatabase" = $authDatabase;
                "principal" = $krbPrincipal;
                "isSslRequired" = $false;
                "useSecondaryForBackup" = $false;
                "secondaryNodeTag" = $secondaryTag
            }
        }
        if($useSSL){
            $newSource.mongodbParams.isSslRequired = $True
        }
        if($useSecondary){
            $newSource.mongodbParams.useSecondaryForBackup = $True
        }
        
        $result = api post -v2 data-protect/sources/registrations $newSource
        if($result.id){
            Write-Host "$server Registered"
        }
    }
}
