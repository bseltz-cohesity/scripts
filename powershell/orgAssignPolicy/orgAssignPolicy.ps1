# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory=$True)][string]$orgName,
    [Parameter(Mandatory=$True)][string]$policyName
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

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

$tenants = api get "tenants?properties=ProtectionPolicy"
$tenant = $tenants | Where-Object name -eq $orgName
if(! $tenant){
    Write-Host "Org $orgName not found" -ForegroundColor Yellow
    exit
}
$policies = api get "protectionPolicies"
$policy = $policies | Where-Object name -eq $policyName

if(! $policy){
    Write-Host "Policy $policyName not found" -ForegroundColor Yellow
    exit
}else{
    Write-Host "Assigning $policyName to $orgName"
}

$policyParams = @{
    "policyIds" = @($tenant.policyIds + $policy.id | Sort-Object -Unique);
    "tenantId" = $tenant.tenantId
}

$null = api put tenants/policy $policyParams
