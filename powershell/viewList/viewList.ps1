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
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName
)

### source the cohesity-api helper code
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

# $ignore = @('madrox:', 'magneto_', 'icebox_', 'AUDIT_', 'yoda_', 'cohesity_download_', 'COHESITY_HELIOS_')
$ignore = @()

$views = api get "views?_includeTenantInfo=true&allUnderHierarchy=true&includeInternalViews=true"
foreach ($view in $views.views){
    if($True -notin ($ignore | foreach{$view.name -match $_})){
        $logicalGB = $view.logicalUsageBytes/(1024*1024*1024)
        "    View Name: $($view.name)"
        "  Description: $($view.description)"
        "Logical Bytes: $($view.logicalUsageBytes)"
        "      Created: $(usecsToDate ($view.createTimeMsecs * 1000))"
        "    Whitelist:"
        "-------"
    }
}