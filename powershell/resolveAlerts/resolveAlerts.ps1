### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][string]$resolution,
    [Parameter()][string]$alertType,
    [Parameter()][string]$alertCode,
    [Parameter()][string]$severity,
    [Parameter()][string]$systemName,
    [Parameter()][string]$matchString,
    [Parameter()][string]$startDate,
    [Parameter()][string]$endDate,
    [Parameter()][int]$maxDays = 0,
    [Parameter()][switch]$sortByDescription
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

$usingHelios = $False
if(($mcm -or $vip -eq 'helios.cohesity.com') -and (!$clusterName)){
    $usingHelios = $True
    $sessionUser = api get sessionUser
    $accountId = $sessionUser.salesforceAccount.accountId
    # $tenantId = $sessionUser.profiles[0].tenantId
}

$alertQuery = "alerts?maxAlerts=1000&alertStateList=kOpen"
if($alertType){
    $alertQuery = $alertQuery + "&alertTypeList=$alertType"
}
if($startDate){
    $startDateUsecs = dateToUsecs $startDate
    $alertQuery = $alertQuery + "&startDateUsecs=$startDateUsecs"
}
if($endDate){
    $endDateUsecs = dateToUsecs $endDate
    $alertQuery = $alertQuery + "&endDateUsecs=$endDateUsecs"
}
if($maxDays -gt 0){
    $startDateUsecs = timeAgo $maxDays days
    $alertQuery = $alertQuery + "&startDateUsecs=$startDateUsecs"
}

if($usingHelios){
    if($region){
        $cohesity_api.header['regionid'] = $region
    }
    $clusterList = @()
    foreach($h in heliosClusters){
        $clusterList = @($clusterList + "$($h.clusterId):$($h.clusterIncarnationId)")
    }
    $clusterIds = $clusterList -join ','
    $alerts = api get -mcm "$alertQuery&clusterIdentifiers=$clusterIds" | Where-Object alertState -ne 'kResolved'
    # $alerts = api get -mcm "$alertQuery" | Where-Object alertState -ne 'kResolved'
    $alertClusters = @($alerts.clusterName | Sort-Object -Unique)
    $alertRegions = @($alerts.regionId | Sort-Object -Unique)
    foreach($alert in $alerts){
        if(! $alert.PSObject.Properties['clusterName']){
            setApiProperty -object $alert -name clusterName -value $alert.regionId
        }
    }
}else{
    $alerts = api get $alertQuery | Where-Object alertState -ne 'kResolved'
}

# filter alerts
function filterAlerts($alerts, $filterOnCluster=$False){
    if($systemName){
        $alerts = $alerts | Where-Object clusterName -eq $systemName
    }
    if($severity){
        $alerts = $alerts | Where-Object severity -eq $severity
    }
    if($usingHelios -and $clusterName -and $filterOnCluster -eq $True){
        $alerts = $alerts | Where-Object clusterName -eq $clusterName
    }
    if($matchString){
        $alerts = $alerts | Where-Object {$_.alertDocument.alertDescription -match $matchString}
    }
    if($alertCode){
        $alerts = $alerts | Where-Object {$_.alertCode -eq $alertCode}
    }
    return $alerts
}

function filterAlerts2($alerts, $filterOnCluster=$False){
    if($severity){
        $alerts = $alerts | Where-Object severity -eq $severity
    }
    if($usingHelios -and $clusterName -and $filterOnCluster -eq $True){
        $alerts = $alerts | Where-Object clusterName -eq $clusterName
    }
    if($matchString){
        $alerts = $alerts | Where-Object {$_.alertDocument.alertDescription -match $matchString}
    }
    if($alertCode){
        $alerts = $alerts | Where-Object {$_.alertCode -eq $alertCode}
    }
    return $alerts
}

function resolveAlerts($ids, $resolutions){
    $resolutions = $resolutions | Sort-Object -Property createdTimeUsecs
    # Write-Host $ids
    if($ids.Count -gt 0 -and $ids[0] -ne $null){
        if($resolutions -ne $null){
            $resolutionId = $resolutions[-1].resolutionDetails.resolutionId
            $null = api put "alertResolutions/$resolutionId" @{"alertIdList" = @($ids)}
        }else{
            $alertResolution = @{
                "alertIdList" = @($ids);
                "resolutionDetails" = @{
                    "resolutionDetails" = $resolution;
                    "resolutionSummary" = $resolution
                }
            }
            $null = api post alertResolutions $alertResolution # -quiet
        }
    }
}

function resolveHeliosAlerts($alerts, $resolutions){
    $resolutions = $resolutions | Sort-Object -Property createdTimeUsecs
    if($alerts.Count -gt 0){
        if($resolutions -ne $null){
            $newResolution = @{
                "accountId" = $accountId;
                "tenantId" = $null;
                "resolutionId" = "$($resolutions[-1].resolutionId)";
                "description" = "$($resolutions[-1].description)";
                "resolutionName" = "$($resolutions[-1].resolutionName)";
                "resolvedAlerts" = @()
            } # $resolutions[-1].resolvedAlerts
        }else{
            $newResolution = @{
                "accountId" = $accountId;
                "tenantId" = $null;
                "description" = "$resolution";
                "resolutionName" = "$resolution";
                "resolvedAlerts" = @()
            }
        }
        if($newResolution.tenantId -eq ""){
            $newResolution.tenantId = $null
        }
        foreach($alert in $alerts){
            $newResolution.resolvedAlerts = @($newResolution.resolvedAlerts + @{
                "alertId" = "$(($alert.id -split ':')[0])";
                "alertName" = "$($alert.alertDocument.alertName)";
                "clusterId" = $alert.clusterId;
                "firstTimestampUsecs" = $alert.firstTimestampUsecs
            })
        }
        # Write-Host ($newResolution | toJson)
        $null = api post -mcmv2 alert-service/alerts/resolutions $newResolution
    }
}

$alerts = filterAlerts $alerts $True

if($alerts.Count -eq 0){
    Write-Host "No alerts found"
    exit
}

$alertsList = @()

if($usingHelios){
    if($sortByDescription){
        $alerts | Sort-Object -Property {$_.alertDocument.alertDescription} | Format-Table -Property clusterName, @{l='Latest Occurrence'; e={usecsToDate ($_.latestTimestampUsecs)}}, alertType, severity, @{l='Description'; e={$_.alertDocument.alertDescription}}
    }else{
        $alerts | Sort-Object -Property {$_.latestTimestampUsecs} | Format-Table -Property clusterName, @{l='Latest Occurrence'; e={usecsToDate ($_.latestTimestampUsecs)}}, alertType, severity, @{l='Description'; e={$_.alertDocument.alertDescription}}
    }
    Write-Host "$($alerts.Count) alerts"
    $alerts | Sort-Object -Property latestTimestampUsecs -Descending | Foreach-Object {
        $alertsList += [ordered] @{
            'Cluster' = $_.clusterName;
            'Latest Occurence' = usecsToDate ($_.latestTimestampUsecs);
            'Alert Type' = $_.alertType;
            'Severity' = $_.severity;
            'Description' = $_.alertDocument.alertDescription
        }
    }
}else{
    if($sortByDescription){
        $alerts | Sort-Object -Property {$_.alertDocument.alertDescription} | Format-Table -Property @{l='Latest Occurrence'; e={usecsToDate ($_.latestTimestampUsecs)}}, alertType, severity, @{l='Description'; e={$_.alertDocument.alertDescription}}
    }else{
        $alerts | Sort-Object -Property latestTimestampUsecs | Format-Table -Property @{l='Latest Occurrence'; e={usecsToDate ($_.latestTimestampUsecs)}}, alertType, severity, @{l='Description'; e={$_.alertDocument.alertDescription}}
    }
    Write-Host "$($alerts.Count) alerts"
    $alerts | Sort-Object -Property latestTimestampUsecs -Descending | Foreach-Object {
        $alertsList += [ordered] @{
            'Latest Occurence' = usecsToDate ($_.latestTimestampUsecs);
            'Alert Type' = $_.alertType;
            'Severity' = $_.severity;
            'Description' = $_.alertDocument.alertDescription
        }
    }
}
($alertsList | ConvertTo-Json -Depth 99 | ConvertFrom-Json) | Export-Csv -Path "alerts.csv" -Encoding utf8 -NoTypeInformation

if($resolution){
    "Resolving alerts..."
    if($usingHelios){
        $resolutions = api get -mcmv2 alert-service/alerts/resolutions | Where-Object {$_.resolutionName -eq $resolution}
    }else{
        $resolutions = api get alertResolutions | Where-Object {$_.resolutionDetails.resolutionSummary -eq $resolution}
    }
    
    if($usingHelios){
        # foreach($region in $alertRegions){
        #     $cohesity_api.header['regionid'] = $region
            resolveHeliosAlerts @($alerts) $resolutions
        # }
        $alertClusters = @($alerts.clusterName | Sort-Object -Unique)
        foreach($clusterName in $alertClusters){
            $theseAlerts = $alerts | Where-Object clusterName -eq $clusterName
            $thisCluster = heliosCluster $clusterName
            $resolutions = api get alertResolutions | Where-Object {$_.resolutionDetails.resolutionSummary -eq $resolution}
            if($cohesity_api.clusterReadOnly -ne $True){
                $theseClusterAlerts = api get $alertQuery | Where-Object alertState -ne 'kResolved'
                $theseClusterAlerts = filterAlerts $theseClusterAlerts
                resolveAlerts @($theseClusterAlerts.id) $resolutions
            }else{
                Write-Host "cluster $clusterName is read-only, can't resolve alerts via Helios" -foregroundcolor Yellow
            }
        }
    }else{
        resolveAlerts @($alerts.id) $resolutions
    }
}
