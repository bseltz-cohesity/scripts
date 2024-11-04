[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][array]$vip,
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$outputPath = '.'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$outfileName = $(Join-Path -Path $outputPath -ChildPath "numProtectedVMs.csv")
"""System Name"",""Number of Protected VMs""" | Out-File -FilePath $outfileName

foreach($v in $vip){
    Write-Host "`nConnecting to $v"
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated to $v" -ForegroundColor Yellow
        continue
    }

    $cluster = api get cluster
    $sources = api get "protectionSources/registrationInfo?useCachedData=false&pruneNonCriticalInfo=true&includeExternalMetadata=true&includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false&allUnderHierarchy=true&environments=kAcropolis&environments=kHyperV&environments=kHyperVVSS&environments=kKVM&environments=kVCD&environments=kVMware&environments=kAzure&environments=kAWS"
    $protectedVMs = 0
    foreach($rootNode in $sources.rootNodes){
        if($rootNode.stats.protectedCount -gt 0){
            $protectedVMs += $rootNode.stats.protectedCount
        }
    }
    Write-Host "VMs protected: $protectedVMs"
    """$($cluster.name)"",""$protectedVMs""" | Out-File -FilePath $outfileName -Append
}

write-host "`nReport Saved to $outFileName`n"
