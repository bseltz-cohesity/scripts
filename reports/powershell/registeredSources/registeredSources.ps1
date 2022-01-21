### process commandline arguments
[CmdletBinding()]
param (
   [Parameter()][string]$vip = 'helios.cohesity.com', #the cluster to connect to (DNS name or IP)
   [Parameter()][string]$username = 'helios', #username (local or AD)
   [Parameter()][string]$heliosAccessCluster,
   [Parameter()][string]$domain = 'local' #local or AD domain
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

if($vip -eq 'helios.cohesity.com' -and $heliosAccessCluster){
    heliosCluster $heliosAccessCluster
}

$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')

$cluster = api get cluster
$outFile = Join-Path -Path $PSScriptRoot -ChildPath "registeredSources-$($cluster.name)-$dateString.csv"

"Status,Source Name, Environment,Protected,Unprotected,Auth Status,Auth Error,Last Refresh,Refresh Error,App Health Checks" | Out-File -FilePath $outFile

$sources = api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false

foreach($source in $sources.rootNodes | Sort-Object -Property {$_.rootNode.name}){
    $status = 'Healthy'
    $authStatus = $authError = $lastRefreshError = ''
    $sourceName = $source.rootNode.name
    $sourceType = $source.rootNode.environment.subString(1)
    $lastRefreshUsecs = $source.registrationInfo.refreshTimeUsecs
    # check for refresh error
    if($source.registrationInfo.PSObject.Properties['refreshErrorMessage']){
        $lastRefreshError = $source.registrationInfo.refreshErrorMessage.split("`n")[0]
        if($lastRefreshError.length -gt 50){
            $lastRefreshError = $lastRefreshError.subString(0,50)
        }
        $status = 'Unhealthy'
    }
    $protected = $source.stats.protectedCount
    $unprotected = $source.stats.unprotectedCount
    # check for authentication completion
    if($source.registrationInfo.PSObject.Properties['authenticationStatus']){
        $authStatus = $source.registrationInfo.authenticationStatus.subString(1)
    }
    if($authStatus -ne 'Finished' -and $sourceType -ne 'GenericNas'){
        $status = 'Unhealthy'
    }
    # check for authentication error
    if($source.registrationInfo.PSObject.Properties['authenticationErrorMessage']){
        $authError = $source.registrationInfo.authenticationErrorMessage.split("`n")[0]
        if($authError.length -gt 50){
            $authError = $authError.subString(0,50)
        }
        $status = 'Unhealthy'
    }
    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""n/a""" -f $status, $sourceName, $sourceType, $protected, $unprotected, $authStatus, $authError, (usecsToDate $lastRefreshUsecs), $lastRefreshError | Out-File -FilePath $outFile -Append
    if($source.registrationInfo.PSObject.Properties['registeredAppsInfo']){
        foreach($app in $source.registrationInfo.registeredAppsInfo){
            $status = 'Healthy'
            $authStatus = $authError = $lastRefreshError = ''
            $sourceType = $app.environment.subString(1)
            # check for authentication completion
            if($app.PSObject.Properties['authenticationStatus']){
                $authStatus = $app.authenticationStatus.subString(1)
            }
            if($authStatus -ne 'Finished'){
                $status = 'Unhealthy'
            }
            # check for authentication error
            if($app.PSObject.Properties['authenticationErrorMessage']){
                $authError = $app.authenticationErrorMessage.split("`n")[0]
                if($authError.length -gt 50){
                    $authError = $authError.subString(0,50)
                }
                $status = 'Unhealthy'
            }
            # check for refresh error
            if($app.PSObject.Properties['refreshErrorMessage']){
                $lastRefreshError = $app.refreshErrorMessage.split("`n")[0]
                if($lastRefreshError.length -gt 50){
                    $lastRefreshError = $lastRefreshError.subString(0,50)
                }
                $status = 'Unhealthy'
            }
            # check for app health check results
            if($app.PSObject.Properties['hostSettingsCheckResults']){
                $failedChecks = $app.hostSettingsCheckResults | Where-Object resultType -ne 'kPass'
                if($failedChecks.Count -gt 0){
                    $healthChecks = "{0}: {1}" -f $failedChecks[0].checkType.subString(1), $failedChecks[0].userMessage.split("`n")[0]
                    $status = 'Unhealthy'
                }else{
                    $healthChecks = 'Passed'
                }
            }else{
                $healthChecks = 'n/a'
            }
            """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}""" -f $status, $sourceName, $sourceType, $protected, $unprotected, $authStatus, $authError, (usecsToDate $lastRefreshUsecs), $lastRefreshError, $healthChecks | Out-File -FilePath $outFile -Append
        }
        "{0}  ({1})" -f $sourceName, $status
    }
}

"`nOutput saved to $outfile`n"
