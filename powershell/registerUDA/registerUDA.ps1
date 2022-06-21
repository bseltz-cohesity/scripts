# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][ValidateSet('CockroachDB', 'DB2', 'MySQL', 'Other', 'SapHana', 'SapMaxDB', 'SapOracle', 'SapSybase', 'SapSybaseIQ', 'SapASE')][string]$sourceType='Other',
    [Parameter()][array]$sourceName,
    [Parameter(Mandatory = $True)][string]$scriptDir,
    [Parameter()][string]$sourceArgs = $null,
    [Parameter()][switch]$mountView,
    [Parameter()][string]$appUsername = '',
    [Parameter()][string]$appPassword = ''
)

$sourceTypeName = @{
    'CockroachDB' = 'kCockroachDB'; 
    'DB2' = 'kDB2';
    'MySQL' = 'kMySQL';
    'Other' = 'kOther';
    'SapHana' = 'kSapHana';
    'SapMaxDB' = 'kSapMaxDB';
    'SapOracle' = 'kSapOracle';
    'SapSybase' = 'kSapSybase';
    'SapSybaseIQ' = 'kSapSybaseIQ';
    'SapASE' = 'kSapASE'
}

function waitForRefresh($id){
    $authStatus = ""
    while($authStatus -ne 'kFinished'){
        Start-Sleep 3
        $rootNode = (api get "protectionSources/registrationInfo?ids=$id").rootNodes[0]
        $authStatus = $rootNode.registrationInfo.authenticationStatus
        if($authStatus -ne 'kFinished'){
            write-host "$authStatus"
        }
    }
    return $rootNode.rootNode.id
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($mcm){
    apiauth -vip $vip -username $username -domain $domain -helios -password $password
}else{
    if($useApiKey){
        apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password
    }
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if($appUsername -ne '' -and $appPassword -eq ''){
    $secureString = Read-Host -Prompt "Enter your app password" -AsSecureString
    $appPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

$regParams = @{
    "environment" = "kUDA";
    "udaParams" = @{
        "sourceType" = $sourceTypeName[$sourceType];
        "hosts" = @(
            $sourceName
        );
        "credentials" = @{
            "username" = $appUsername;
            "password" = $appPassword
        };
        "scriptDir" = $scriptDir;
        "mountView" = $false;
        "viewParams" = $null;
        "sourceRegistrationArgs" = $sourceArgs
    }
}

if($mountView){
    $regParams.udaParams.mountView = $True
}

"Registering UDA protection source '$($sourceName[0])'..."
$result = api post -v2 data-protect/sources/registrations $regParams
if($result.PSObject.Properties['id']){
    $id = waitForRefresh($result.id)
}
