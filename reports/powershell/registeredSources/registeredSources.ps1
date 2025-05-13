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
    [Parameter()][array]$searchString,
    [Parameter()][string]$searchList,
    [Parameter()][string]$searchType,
    [Parameter()][switch]$dbg,
    [Parameter()][switch]$unhealthy,
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to address
    [Parameter()][string]$sendFrom # send from address
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}


$searchStrings = @(gatherList -Param $searchString -FilePath $searchList -Name 'searches' -Required $false)

$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')

$outFile = Join-Path -Path $PSScriptRoot -ChildPath "registeredSources-$dateString.csv"

"""Cluster"",""Status"",""Source Name"","" Environment"",""Protected"",""Unprotected"",""Auth Status"",""Auth Error"",""Last Refresh"",""Refresh Error"",""App Health Checks""" | Out-File -FilePath $outFile

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

Write-Host ""

$Script:recordCount = 0

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
            $seenSources = @()

            function getSources($thesesources){
                foreach($source in $thesesources | Sort-Object -Property {$_.rootNode.name}){
                    if($source.rootNode.id -in $seenSources){
                        continue
                    }
                    $status = 'Healthy'
                    $authStatus = $authError = $lastRefreshError = ''
                    $sourceName = $source.rootNode.name
                    $sourceType = $source.rootNode.environment.subString(1)
                    $lastRefreshUsecs = $source.registrationInfo.refreshTimeUsecs
                    # check for refresh error
                    if($source.registrationInfo.PSObject.Properties['refreshErrorMessage']){
                        $lastRefreshError = $source.registrationInfo.refreshErrorMessage.split("`n")[0]
                        if($lastRefreshError.length -gt 300){
                            $lastRefreshError = $lastRefreshError.subString(0,300)
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
                        if($authError.length -gt 300){
                            $authError = $authError.subString(0,300)
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
                                if($authError.length -gt 300){
                                    $authError = $authError.subString(0,300)
                                }
                                $status = 'Unhealthy'
                            }
                            # check for refresh error
                            if($app.PSObject.Properties['refreshErrorMessage']){
                                $lastRefreshError = $app.refreshErrorMessage.split("`n")[0]
                                if($lastRefreshError.length -gt 300){
                                    $lastRefreshError = $lastRefreshError.subString(0,300)
                                }
                                $status = 'Unhealthy'
                            }
                            # check for app health check results
                            if($app.PSObject.Properties['hostSettingsCheckResults']){
                                $failedChecks = $app.hostSettingsCheckResults | Where-Object resultType -ne 'kPass'
                                if($failedChecks){
                                    $healthChecks = "{0}: {1}" -f $failedChecks[0].checkType.subString(1), $failedChecks[0].userMessage.split("`n")[0]
                                    $status = 'Unhealthy'
                                }else{
                                    $healthChecks = 'Passed'
                                }
                            }else{
                                $healthChecks = 'n/a'
                            }
                            if(!$unhealthy -or $status -eq 'Unhealthy'){
                                """$cluster"",""$status"",""$sourceName"",""$sourceType"",""$protected"",""$unprotected"",""$authStatus"",""$authError"",""$(usecsToDate $lastRefreshUsecs)"",""$lastRefreshError"",""$healthChecks""" | Out-File -FilePath $outFile -Append
                            }
                        }
                    }else{
                        if(!$unhealthy -or $status -eq 'Unhealthy'){
                            """$cluster"",""$status"",""$sourceName"",""$sourceType"",""$protected"",""$unprotected"",""$authStatus"",""$authError"",""$(usecsToDate $lastRefreshUsecs)"",""$lastRefreshError"",""n/a""" | Out-File -FilePath $outFile -Append
                        }
                    }
                    if(!$unhealthy -or $status -eq 'Unhealthy'){
                        $Script:recordCount += 1
                        "{0}:  {1}  ({2})  {3}" -f $cluster, $sourceName, $sourceType, $status
                    }
                    $seenSources = @($seenSources + $source.rootNode.id)
                }
            }

            $sources = (api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false).rootNodes
            if($searchType){
                $sources = $sources | Where-Object {$_.rootNode.environment -match $searchType -or $_.registrationInfo.registeredAppsInfo.environment -match $searchType}
            }
            if($searchStrings.Count -eq 0){
                getSources $sources
            }else{
                foreach($searchString in $searchStrings){
                    $thesesources = $sources | Where-Object {$_.rootNode.name -match $searchString}
                    getSources $thesesources
                }
            }
        }
    }
}

"`nOutput saved to $outfile`n"

if($smtpServer -and $sendTo -and $sendFrom -and $Script:recordCount -gt 0){
    if($unhealthy){
        $subject = "Cohesity Registered Sources (Unhealthy)"
        $body = "`n$recordCount unhealthy sources reported (see attached)"
    }else{
        $subject = "Cohesity Registered Sources"
        $body = "`n$recordCount sources reported (see attached)"
    }
    Write-Host "Sending report to $([string]::Join(", ", $sendTo))`n"
    # send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $subject -Body $body -Attachments $outfile -WarningAction SilentlyContinue
    }
}
