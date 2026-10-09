# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
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
    [Parameter(Mandatory=$True)][string]$exchangeFQDN,
    [Parameter(Mandatory=$True)][string]$exchangeUser,
    [Parameter()][string]$exchangePassword
)

if(!$exchangePassword){
    $secureString = Read-Host -Prompt "Enter password for $exchangeUser" -AsSecureString
    $exchangePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

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

$regParams = @{
    "environment" = "kEwsExchange";
    "ewsExchangeParams" = @{
        "ewsEndpoint" = "https://$exchangeFQDN/EWS/Exchange.asmx";
        "serviceAccountCredentialsList" = @(
            @{
                "username" = "$exchangeUser";
                "password" = "$exchangePassword"
            }
        );
        "authMethod" = "kNtlm";
        "useProxy" = $false
    }
}
Write-Host "Registering $exchangeFQDN"
$null = api post -v2 data-protect/sources/registrations $regParams
