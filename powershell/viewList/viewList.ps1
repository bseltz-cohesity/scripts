### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$ignore = @('madrox:', 'magneto_', 'icebox_', 'AUDIT_', 'yoda_', 'cohesity_download_', 'COHESITY_HELIOS_')

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
