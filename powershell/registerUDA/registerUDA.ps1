# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][ValidateSet('CockroachDB', 'DB2', 'MySQL', 'Other', 'SapHana', 'SapMaxDB', 'SapOracle', 'SapSybase', 'SapSybaseIQ', 'SapASE')][string]$sourceType='Other',
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter(Mandatory = $True)][string]$scriptDir,
    [Parameter(Mandatory = $True)][string]$sourceArgs,
    [Parameter()][switch]$mountView,
    [Parameter(Mandatory = $True)][string]$appUsername,
    [Parameter()][string]$appPassword=$null
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
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

if(!$appPassword){
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
"Registering UDA protection source '$sourceName'..."
$result = api post -v2 data-protect/sources/registrations $regParams
if($result.PSObject.Properties['id']){
    $id = waitForRefresh($result.id)
}
