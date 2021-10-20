### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local' #local or AD domain
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')

$cluster = api get cluster
$outFile = Join-Path -Path $PSScriptRoot -ChildPath "registeredSources-$($cluster.name)-$dateString.csv"

"Source Name, Environment,Protected,Unprotected,Last Refresh,Error" | Out-File -FilePath $outFile

$sources = api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false

foreach($source in $sources.rootNodes){
    $sourceName = $source.rootNode.name
    $sourceType = $source.rootNode.environment.subString(1)
    $lastRefreshUsecs = $source.registrationInfo.refreshTimeUsecs
    $lastError = $source.registrationInfo.refreshErrorMessage
    $protected = $source.stats.protectedCount
    $unprotected = $source.stats.unprotectedCount
    "{0},{1},{2},{3},{4},""{5}""" -f $sourceName, $sourceType, $protected, $unprotected, (usecsToDate $lastRefreshUsecs), $lastError | Tee-Object -FilePath $outFile -Append
}

"`nOutput saved to $outfile`n"
