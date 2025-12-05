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
    [Parameter(Mandatory = $True)][string]$subscriptionId,
    [Parameter(Mandatory = $True)][string]$applicationId,
    [Parameter(Mandatory = $True)][string]$tenantId,
    [Parameter()][string]$applicationKey
)

### source the cohesity-api helper code
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

if(! $applicationKey){
    $secureString = Read-Host -Prompt "Enter applicationKey" -AsSecureString
    $applicationKey = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
}

$regParams = @{
    "entity" = @{
        "type" = 8;
        "azureEntity" = @{
            "type" = 0;
            "name" = $subscriptionId;
            "id" = "/subscriptions/$subscriptionId"
        }
    };
    "entityInfo" = @{
        "type" = 8;
        "credentials" = @{
            "cloudCredentials" = @{
                "azureCredentials" = @{
                    "subscriptionType" = 1;
                    "subscriptionId" = $subscriptionId;
                    "applicationId" = $applicationId;
                    "tenantId" = $tenantId;
                    "applicationKey" = $applicationKey
                }
            }
        };
    };
    "registeredEntityParams" = @{
        "isSpaceThresholdEnabled" = $false;
        "throttlingPolicy" = @{
            "isThrottlingEnabled" = $false;
            "isDatastoreStreamsConfigEnabled" = $false;
            "datastoreStreamsConfig" = @{}
        };
        "vmwareParams" = @{}
    };
}

Write-Host "Registering $subscriptionId"
$null = api post /backupsources $regParams
