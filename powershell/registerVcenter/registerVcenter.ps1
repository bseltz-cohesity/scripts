# usage: ./registerVcenter.ps1 -vip mycluster -username myuser -domain mydomain.net -vcenter vcenter.mydomain.net -vcuser administrator@vsphere.local

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
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$vcenter,  # DNS or IP of vCenter
    [Parameter(Mandatory = $True)][string]$vcuser,  # vCenter username
    [Parameter()][string]$vcpassword,
    [Parameter()][switch]$useVmBiosUuid
)

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

if(!$vcpassword){
    $secureString = Read-Host -Prompt "Enter Password for vCenter user $vcuser" -AsSecureString
    $vcpassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
}

$registerVcenter = @{
    "entity"                 = @{
        "type"         = 1;
        "vmwareEntity" = @{
            "type" = 0
        }
    };
    "entityInfo"             = @{
        "endpoint"    = $vcenter;
        "type"        = 1;
        "credentials" = @{
            "username" = $vcuser;
            "password" = $vcpassword
        }
    };
    "registeredEntityParams" = @{
        "isSpaceThresholdEnabled" = $false;
        "spaceUsagePolicy"        = @{ };
        "throttlingPolicy"        = @{
            "isThrottlingEnabled"             = $false;
            "isDatastoreStreamsConfigEnabled" = $false;
            "datastoreStreamsConfig"          = @{ }
        }
    }
}
if($useVmBiosUuid){
    $registerVcenter['registeredEntityParams']['vmwareParams'] = @{'useVmBiosUuid' = $True}
}
write-host "Registering $vcenter..." 
$null = api post /backupsources $registerVcenter
Clear-Variable vcpassword
