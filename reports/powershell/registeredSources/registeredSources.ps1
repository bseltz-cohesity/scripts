### process commandline arguments
[CmdletBinding()]
param (
   [Parameter()][array]$vip = 'helios.cohesity.com', #the cluster to connect to (DNS name or IP)
   [Parameter()][string]$username = 'helios', #username (local or AD)
   [Parameter()][array]$clusterName,
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][switch]$useApiKey,                     # use API key for authentication
   [Parameter()][string]$password,                      # optional password
   [Parameter()][switch]$noPrompt,                      # do not prompt for password
   [Parameter()][string]$tenant,                        # org to impersonate
   [Parameter()][switch]$mcm,                           # connect to MCM endpoint
   [Parameter()][string]$mfaCode = $null,               # MFA code
   [Parameter()][switch]$emailMfaCode,                  # email MFA code
   [Parameter()][string]$searchString,
   [Parameter()][string]$searchType
)

$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')

$outFile = Join-Path -Path $PSScriptRoot -ChildPath "registeredSources-$dateString.csv"

"Cluster,Status,Source Name, Environment,Protected,Unprotected,Auth Status,Auth Error,Last Refresh,Refresh Error,App Health Checks" | Out-File -FilePath $outFile

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

Write-Host ""

foreach($v in $vip){
    ### authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt -quiet

    if($USING_HELIOS -and ! $clusterName){
        $clusterName = @((heliosClusters).name)
    }

    if(!$cohesity_api.authorized){
        Write-Host "$v Not authenticated" -ForegroundColor Yellow
    }else{
        if(!$USING_HELIOS){
            $clusterName = @((api get cluster).name)
        }
        foreach($cluster in $clusterName){
            if($USING_HELIOS){
                $null = heliosCluster $cluster
            }

            $sources = (api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false).rootNodes
            if($searchString){
                $sources = $sources | Where-Object {$_.rootNode.name -match $searchString}
            }
            if($searchType){
                $sources = $sources | Where-Object {$_.rootNode.environment -match $searchType}
            }
            foreach($source in $sources | Sort-Object -Property {$_.rootNode.name}){
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
                        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}""" -f $cluster, $status, $sourceName, $sourceType, $protected, $unprotected, $authStatus, $authError, (usecsToDate $lastRefreshUsecs), $lastRefreshError, $healthChecks | Out-File -FilePath $outFile -Append
                    }
                }else{
                    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""n/a""" -f $cluster, $status, $sourceName, $sourceType, $protected, $unprotected, $authStatus, $authError, (usecsToDate $lastRefreshUsecs), $lastRefreshError | Out-File -FilePath $outFile -Append
                }
                "{0}:  {1}  ({2})  {3}" -f $cluster, $sourceName, $sourceType, $status
            }
        }
    }
}

"`nOutput saved to $outfile`n"
