[CmdletBinding()]
param (
    [Parameter()][array]$vip,                   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',  # username (local or AD)
    [Parameter()][string]$domain = 'local',     # local or AD domain
    [Parameter()][switch]$useApiKey,            # use API key for authentication
    [Parameter()][string]$password,             # optional password
    [Parameter()][switch]$noPrompt,             # do not prompt for password
    [Parameter()][string]$tenant,               # org to impersonate
    [Parameter()][switch]$mcm,                  # connect through mcm
    [Parameter()][string]$mfaCode = $null,      # mfa code
    [Parameter()][array]$clusterName = $null,   # cluster to connect to via helios/mcm
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB','MB','GB','TB')][string]$unit = 'MiB',  # data size units
    [Parameter()][int]$pageSize = 1000          # number of items per API query
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024; 'MB' = 1000 * 1000; 'GB' = 1000 * 1000 * 1000; 'TB' = 1000 * 1000 * 1000}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

$csvFile = "licenseUsageDetails.csv"
"""Cluster"",""Job/View Name"",""Tenant"",""License Type"",""$unit License Usage"",""Environment"",""Origination"",""$unit Logical"",""$unit Ingested"",""$unit Consumed"",""$unit Written"",""$unit Unique"",""Dedup Ratio"",""Compression"",""Storage Domain"",""Resiliency Setting""" | Out-File -FilePath $csvFile -Encoding utf8
$totalsFile = "licenseUsagePerTenant.csv"
"""Tenant"",""License Type"","" $unit License Usage""" | Out-File -FilePath $totalsFile -Encoding utf8

$nowMsecs = [int64]((dateToUsecs) / 1000)
$monthAgoMsecs = [int64]((timeAgo 1 month) / 1000)

$tenantTotals = @{}

function processStats($clusterName, $stats, $name, $environment, $location, $tenant, $sd){
        $rs = ''
        $sdName = ''
        if($sd){
            $sdName = $sd.name
            if($sd.storagePolicy.numFailuresTolerated -eq 0){
                $rs = 'RF 1'
            }else{
                $rs = 'RF 2'
            }
            if($sd.storagePolicy.PSObject.Properties['erasureCodingInfo']){
                $rs = "EC $($sd.storagePolicy.erasureCodingInfo.numDataStripes):$($sd.storagePolicy.erasureCodingInfo.numCodedStripes)"
            }
        }
        $logicalBytes = $stats.totalLogicalUsageBytes
        $dataIn = $stats.dataInBytes
        $dataInAfterDedup = $stats.dataInBytesAfterDedup
        $dataWritten = $stats.dataWrittenBytes
        $consumedBytes = $stats.storageConsumedBytes
        $uniquBytes = $stats.uniquePhysicalDataBytes
        if($dataInAfterDedup -gt 0 -and $dataWritten -gt 0){
            $dedup = [math]::Round($dataIn/$dataInAfterDedup,1)
            $compression = [math]::Round($dataInAfterDedup/$dataWritten,1)
        }else{
            $dedup = 0
            $compression = 0
        }
        $consumption = toUnits $consumedBytes
        $logical = toUnits $logicalBytes
        $dataInUnits = toUnits $dataIn
        $dataWrittenUnits = toUnits $dataWritten
        $licenseUsage = $dataWritten
        $uniqueUnits = toUnits $uniquBytes

        Write-Host ("{0,35}: {1,11:f2} {2}" -f $name, $consumption, $unit)

        if($environment -eq 'View'){
            $licenseType = 'SmartFiles'
        }else{
            if($location -eq 'Local'){
                $licenseType = 'DataProtect'
            }else{
                $licenseType = 'Replica'
            }
        }

        if($tenant -notin $script:tenantTotals.keys){
            $script:tenantTotals[$tenant] = @{
                'SmartFiles' = 0;
                'DataProtect' = 0;
                'Replica' = 0
            }
        }
        $script:tenantTotals[$tenant][$licenseType] += $licenseUsage

        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}"",""{12}"",""{13}"",""{14}"",""{15}""" -f $clusterName,
            $name,
            $tenant,
            $licenseType,
            $(toUnits $licenseUsage),
            $environment,
            $location,
            $logical,
            $dataInUnits,
            $consumption,
            $dataWrittenUnits,
            $uniqueUnits,
            $dedup,
            $compression,
            $sdName,
            $rs | Out-File -FilePath $csvFile -Append
}

function getStats($consumerType){
    $theseStats = @()
    $stats = api get "stats/consumers?maxCount=$pageSize&fetchViewBoxName=true&fetchTenantName=true&fetchProtectionPolicy=true&fetchProtectionEnvironment=true&consumerType=$consumerType"

    $theseStats = @($theseStats + $stats.statsList)
    while($stats.cookie -ne ''){
        $stats = api get "stats/consumers?maxCount=$pageSize&fetchViewBoxName=true&fetchTenantName=true&fetchProtectionPolicy=true&fetchProtectionEnvironment=true&consumerType=$consumerType&cookie=$($stats.cookie)"
        $theseStats = @($theseStats + $stats.statsList)
    }
    return $theseStats
}

function reportStorage(){
    $cluster = api get cluster
    Write-Host "`n========================`n$($cluster.name)`n========================`n"
    $storageDomains = api get viewBoxes
    $jobs = api get -v2 data-protect/protection-groups?includeTenants=true
    $views = api get -v2 "file-services/views?maxCount=2000&includeTenants=true"
    $protectedViews = @()
    $seenJobs = @()

    # Local Jobs
    $stats = getStats kProtectionRuns
    $stats = $stats | Where-Object {$_.name -notmatch '_DELETED_'} 

    foreach($stat in $stats | Sort-Object -Property name){
        $job = $jobs.protectionGroups | Where-Object name -eq $stat.name
        if($stat.protectionEnvironment -eq 'kPuppeteer'){
            $view = $views.views | Where-Object viewId -eq $job.remoteAdapterParams.viewId
            $protectedViews = @($protectedViews + $view.name)
        }
        $sd = $null
        if($stat.groupList[0].viewBoxid){
            $sd = $storageDomains | Where-Object {$_.id -eq $stat.groupList.viewBoxid}
        }
        $stats = $null
        if($stat.groupList[0].PSObject.Properties['tenantName']){
            $tenant = $stat.groupList[0].tenantName
        }else{
            $tenant = '-'
        }
        $environment = 'unknown'
        if($stat.PSObject.Properties['protectionEnvironment']){
            $environment = $stat.protectionEnvironment.subString(1)
        }
        if($environment -eq 'Puppeteer'){
            $environment = 'RemoteAdapter'
        }
        if($stat.stats){
            processStats $cluster.name $stat.stats $stat.name $environment 'Local' $tenant $sd
        }
    }

    # Replicated Jobs
    $stats = getStats kReplicationRuns
    $stats = $stats | Where-Object {$_.name -notmatch '_DELETED_'} 

    foreach($stat in $stats | Sort-Object -Property name){
        $job = $jobs.protectionGroups | Where-Object name -eq $stat.name
        if($stat.protectionEnvironment -eq 'kPuppeteer'){
            $view = $views.views | Where-Object viewId -eq $job.remoteAdapterParams.viewId
            $protectedViews = @($protectedViews + $view.name)
        }
        $sd = $null
        if($stat.groupList[0].viewBoxid){
            $sd = $storageDomains | Where-Object {$_.id -eq $stat.groupList.viewBoxid}
        }
        $stats = $null
        if($stat.groupList[0].PSObject.Properties['tenantName']){
            $tenant = $stat.groupList[0].tenantName
        }else{
            $tenant = '-'
        }
        $environment = 'unknown'
        if($stat.PSObject.Properties['protectionEnvironment']){
            $environment = $stat.protectionEnvironment.subString(1)
        }
        if($environment -eq 'Puppeteer'){
            $environment = 'RemoteAdapter'
        }
        if($stat.stats){
            processStats $cluster.name $stat.stats $stat.name $environment 'Replicated' $tenant $sd
        }
    }

    # View Jobs
    $stats = getStats kViewProtectionRuns
    $stats = $stats | Where-Object {$_.name -notmatch '_DELETED_'}
    
    foreach($stat in $stats | Sort-Object -Property name){
        if($stat.name -in $seenJobs){
            continue
        }
        $job = $jobs.protectionGroups | Where-Object name -eq $stat.name
        if(($job.policyId -split ":")[0] -eq $cluster.id){
            $location = 'Local'
        }else{
            $location = 'Replicated'
        }
        $seenJobs = @($seenJobs + $stat.name)
        $protectedViews = @($protectedViews + $($job.viewParams.objects.name))
        $protectedViews = @($protectedViews + $($job.viewParams.replicationParams.viewNameConfigList.viewName))
        $sd = $null
        if($stat.groupList[0].viewBoxid){
            $sd = $storageDomains | Where-Object {$_.id -eq $stat.groupList.viewBoxid}
        }
        $stats = $null
        if($stat.groupList[0].PSObject.Properties['tenantName']){
            $tenant = $stat.groupList[0].tenantName
        }else{
            $tenant = '-'
        }
        if($stat.stats){
            processStats $cluster.name $stat.stats $stat.name 'View' $location $tenant $sd
        }
    }
    
    # Unprotected Views
    $stats = getStats kViews

    foreach($stat in $stats | Sort-Object -Property name){
        if($stat.name -in $protectedViews){
            continue
        }
        $sd = $null
        if($stat.groupList[0].viewBoxid){
            $sd = $storageDomains | Where-Object {$_.id -eq $stat.groupList.viewBoxid}
        }
        $stats = $null
        if($stat.groupList[0].PSObject.Properties['tenantName']){
            $tenant = $stat.groupList[0].tenantName
        }else{
            $tenant = '-'
        }
        if($stat.stats){
            processStats $cluster.name $stat.stats $stat.name 'View' 'Local' $tenant $sd
        }
    }
}

# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        output "`n$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            reportStorage
        }
    }else{
        reportStorage
    }
}

foreach($tenant in $tenantTotals.keys){
    foreach($licenseType in $tenantTotals[$tenant].keys){
        """$tenant"",""$licenseType"",""$(toUnits $tenantTotals[$tenant][$licenseType])""" | Out-File -FilePath $totalsFile -Append
    }
}

Write-Host "`nSaving detailed report as $csvFile"
Write-Host "Saving per tenant totals as $totalsFile`n"
