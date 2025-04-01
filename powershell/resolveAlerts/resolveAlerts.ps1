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
    [Parameter()][string]$region = $null,  # filter on dmaas region
    [Parameter()][string]$resolution,
    [Parameter()][string]$alertType,
    [Parameter()][string]$alertCode,
    [Parameter()][string]$severity,
    [Parameter()][string]$matchString,
    [Parameter()][string]$startDate,
    [Parameter()][string]$endDate,
    [Parameter()][int]$maxDays = 0
)

$usingHelios = $False
if(($mcm -or $vip -eq 'helios.cohesity.com') -and (!$clusterName)){
    $usingHelios = $True
}

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
    $alerts = api get -mcm $alertQuery | Where-Object alertState -ne 'kResolved'
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
    if($severity){
        $alerts = $alerts | Where-Object severity -eq $severity
    }
    if($usingHelios -and $clusterName -and $filterOnCluster){
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
    if($ids.Count -gt 0){
        if($resolutions -ne $null){
            $resolutionId = $resolutions[0].resolutionDetails.resolutionId
            $null = api put "alertResolutions/$($resolutions[0].resolutionDetails.resolutionId)" @{
                "alertIdList" = @($ids)
            }
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

$alerts = filterAlerts $alerts $True

if($alerts.Count -eq 0){
    Write-Host "No alerts found"
    exit
}

$alertsList = @()

if($usingHelios){
    $alerts | Sort-Object -Property {$_.latestTimestampUsecs} | Format-Table -Property clusterName, @{l='Latest Occurrence'; e={usecsToDate ($_.latestTimestampUsecs)}}, alertType, severity, @{l='Description'; e={$_.alertDocument.alertDescription}}
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
    $alerts | Sort-Object -Property latestTimestampUsecs | Format-Table -Property @{l='Latest Occurrence'; e={usecsToDate ($_.latestTimestampUsecs)}}, alertType, severity, @{l='Description'; e={$_.alertDocument.alertDescription}}
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
    $resolutions = api get alertResolutions | Where-Object {$_.resolutionDetails.resolutionSummary -eq $resolution}
    if($usingHelios){
        foreach($region in $alertRegions){
            $cohesity_api.header['regionid'] = $region
            resolveAlerts @($alerts.id) $resolutions
        }
        foreach($clusterName in $alertClusters){
            $theseAlerts = $alerts | Where-Object clusterName -eq $clusterName
            $thisCluster = heliosCluster $clusterName
            if($cohesity_api.clusterReadOnly -ne $True){
                $theseClusterAlerts = api get $alertQuery | Where-Object alertState -ne 'kResolved'
                $theseClusterAlerts = filterAlerts $theseClusterAlerts $False
                resolveAlerts @($theseClusterAlerts.id) $resolutions
            }else{
                Write-Host "cluster $clusterName is read-only, can't resolve alerts via Helios" -foregroundcolor Yellow
            }
        }
    }else{
        resolveAlerts @($alerts.id) $resolutions
    }
}
