[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][switch]$EntraId,
    [Parameter()][string]$startDate = '',
    [Parameter()][string]$endDate = '',
    [Parameter()][switch]$thisCalendarMonth,
    [Parameter()][switch]$lastCalendarMonth,
    [Parameter()][int]$days = 7,
    [Parameter()][int]$dayRange = 180,
    [Parameter()][array]$clusterNames,
    [Parameter(Mandatory = $True)][string]$reportName = 'Protection Runs',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][string]$outputPath = '.',
    [Parameter()][switch]$includeCCS,
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment,
    [Parameter()][switch]$excludeLogs,
    [Parameter()][int]$timeoutSeconds = 300,
    [Parameter()][int]$sleepTimeSeconds = 15,
    [Parameter()][switch]$dbg
) #  [Parameter()][switch]$replicationOnly,

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

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain 'local' -helios -entraIdAuthentication $EntraId

$allClusters = (api get -mcmv2 cluster-mgmt/info).cohesityClusters
$regions = api get -mcmv2 dms/regions
if($includeCCS){
    foreach($region in $regions.regions){
        setApiProperty -object $region -name 'clusterName' -Value $region.name
        $allClusters = @($allClusters + $region)
    }
}

# select clusters to include
$selectedClusters = $allClusters
if($clusterNames.length -gt 0){
    $selectedClusters = $allClusters | Where-Object {$_.clusterName -in $clusterNames -or $_.clusterId -in $clusterNames}
    $unknownClusters = $clusterNames | Where-Object {$_ -notin @($allClusters.clusterName) -and $_ -notin @($allClusters.clusterId)}
    if($unknownClusters){
        Write-Host "Clusters not found:`n $($unknownClusters -join ', ')" -ForegroundColor Yellow
        exit
    }
}

# date range
$today = Get-Date

if($startDate -ne '' -and $endDate -ne ''){
    $uStart = dateToUsecs $startDate
    $uEnd = dateToUsecs $endDate
}elseif ($thisCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)))
    $uEnd = dateToUsecs ($today)
}elseif ($lastCalendarMonth) {
    $uStart = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddMonths(-1))
    $uEnd = dateToUsecs ($today.Date.AddDays(-($today.day-1)).AddSeconds(-1))
}else{
    $uStart = timeAgo $days 'days'
    $uEnd = dateToUsecs ($today)
}

$start = (usecsToDate $uStart).ToString('yyyy-MM-dd')
$end = (usecsToDate $uEnd).ToString('yyyy-MM-dd')

$dayRangeUsecs = $dayRange * 86400000000

# build time ranges
$ranges = @()
$gotAllRanges = $False
$thisUend = $uEnd
$thisUstart = $uStart
while($gotAllRanges -eq $False){
    if(($thisUend - $uStart) -gt $dayRangeUsecs){
        $thisUstart = $thisUend - $dayRangeUsecs
        $ranges = @($ranges + @{'start' = $thisUstart; 'end' = $thisUend})
        $thisUend = $thisUstart - 1
    }else{
        $ranges = @($ranges + @{'start' = $uStart; 'end' = $thisUend})
        $gotAllRanges = $True
    }
}

$excludeLogsFilter = @{
    "attribute" = "backupType";
    "filterType" = "In";
    "inFilterParams" = @{
        "attributeDataType" = "String";
        "stringFilterValues" = @(
            "kRegular",
            "kFull",
            "kSystem"
        );
        "attributeLabels" = @(
            "Incremental",
            "Full",
            "System"
        )
    }
}

$environmentFilter = @{
    "attribute" = "environment";
    "filterType" = "In";
    "inFilterParams" = @{
        "attributeDataType" = "String";
        "stringFilterValues" = @(
            $environment
        );
        "attributeLabels" = @(
            $environment
        )
    }
}

$replicationFilter = @{
    "attribute" = "activityType";
    "filterType" = "In";
    "inFilterParams" = @{
        "attributeDataType" = "String";
        "stringFilterValues" = @(
            "Replication"
        );
        "attributeLabels" = @(
            "Replication"
        )
    }
}

# Convert timestamps to dates
$epochColumns = @('lastRunTime', 
                  'lastSuccessfulBackup', 
                  'endTimeUsecs',
                  'startTimeUsecs', 
                  'runStartTimeUsecs', 
                  'recoveryPointUsecs',
                  'lastFailedRunUsecs',
                  'lastRunTimeUsecs',
                  'lastDisconnectionTimestampUsecs')

# get list of available reports
$reports = api get -reportingV2 reports
$report = $reports.reports | Where-Object {$_.title -eq $reportName}
if(! $report){
    Write-Host "Invalid report name: $reportName" -ForegroundColor Yellow
    Write-Host "`nAvailable report names are:`n"
    Write-Host (($reports.reports.title | Sort-Object) -join "`n")
    exit
}

$title = $report.title

# output files
$csvFileName = $(Join-Path -Path $outputPath -ChildPath "$($title.replace('/','-').replace('\','-'))_$($start)_$($end).csv")
$tmpCsv =  $(Join-Path -Path $outputPath -ChildPath "tmpCsv")

$x = 0
foreach($cluster in ($selectedClusters | Sort-Object -Property clusterName)){
    $y = 0
    if($cluster.clusterName -in @($regions.regions.name)){
        $systemId = $cluster.id
    }else{
        $systemId = "$($cluster.clusterId):$($cluster.clusterIncarnationId)"
    }
    Write-Host "$($cluster.clusterName) " -NoNewline
  
    foreach($range in $ranges){
        $reportParams = @{
            "reportId" = $report.id;
            "name" = $report.title;
            "reportFormats" = @(
                "CSV"
            );
            "filters" = @(
                @{
                    "attribute"             = "date";
                    "filterType"            = "TimeRange";
                    "timeRangeFilterParams" = @{
                        "lowerBound" = [int64]$range.start;
                        "upperBound" = [int64]$range.end
                    }
                }
                @{
                    "attribute" = "systemId";
                    "filterType" = "Systems";
                    "systemsFilterParams" = @{
                        "systemIds" = @("$systemId");
                        "systemNames" = @("$($cluster.clusterName)")
                    }
                }
            );
            "timezone" = $timeZone;
            "notificationParams" = $null;
        }
        
        if($excludeLogs){
            $reportParams.filters = @($reportParams.filters + $excludeLogsFilter)
        }
        if($environment){
            $reportParams.filters = @($reportParams.filters + $environmentFilter)
        }
        if($replicationOnly){
            $reportParams.filters = @($reportParams.filters + $replicationFilter)
        }
        if($dbg){
            $reportParams | toJson
        }
        
        $request = api post -reportingV2 "reports/requests" $reportParams
        if(! $request.PSObject.Properties['id']){
            exit 1
        }
        
        $finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning')
        
        # Wait for report to generate
        while($True){   
            Start-Sleep $sleepTimeSeconds
            $thisRequest = (api get -reportingV2 "reports/requests").requests | Where-Object id -eq $request.id
            if($thisRequest.status -in $finishedStates){
                break
            }
        }
        
        # Download CSV
        
        if($thisRequest.status -ne 'Succeeded'){
            Write-Host " ** Report generation $($thisRequest.status)"
            $thisRequest | toJson
            continue
        }
        fileDownload -fileName "report-tmp.zip" -uri "https://helios.cohesity.com/heliosreporting/api/v1/public/reports/requests/$($thisRequest.id)/artifacts/CSV"
        Expand-Archive -Path "report-tmp.zip" -force
        Remove-Item -Path "report-tmp.zip" -force
        $thisCsv = Import-CSV -Path "report-tmp/$($report.id)_$(usecsToDate $thisRequest.submittedAtTimestampUsecs -format "yyyy-MM-d_Hm").csv"
        if($y -eq 0){
            $thisCsv | Export-CSV -Path $tmpCsv
            $y = 1
        }else{
            $thisCsv | Export-CSV -Path $tmpCsv -Append
        }
        $csv = @($csv + $thisCsv)
        Write-Host "($($thisCsv.Count) rows)"
        Remove-Item -Path "report-tmp" -Recurse
    }

    if(!(Test-Path -Path $tmpCsv -PathType Leaf)){
        continue
    }
    $csv = Import-CSV -Path $tmpCsv
    Remove-Item -Path $tmpCsv -force
    if($csv.Count -eq 0){
        continue
    }
    $columns = $csv[0].PSObject.properties.name 

    # exclude environments
    if($excludeEnvironment){
        $csv = $csv | Where-Object environment -notin $excludeEnvironment
    }

    foreach($epochColumn in $epochColumns){
        $csv | Where-Object {$_.PSObject.Properties[$epochColumn] -and $_.$epochColumn -ne $null -and $_.$epochColumn -ne 0} | ForEach-Object{
            $_.$epochColumn = usecsToDate $($_.$epochColumn)
        }
    }

    # convert usecs to seconds
    $usecColumns = @('durationUsecs', 'totalDisconnectedTimeUsecs')
    $usecColumnRenames = @{'durationUsecs' = 'durationSeconds'}
    foreach($usecColumn in $usecColumns){
        $csv | Where-Object {$_.PSObject.Properties[$usecColumn]} | ForEach-Object{
            $_.$usecColumn = [int]($_.$usecColumn / 1000000)
        }
    }

    # merge ranges
    if($ranges.Count -gt 1){
        # merge protected objects
        if($reportName -eq 'protected objects'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.system}, {$_.sourceName}, {$_.objectType}, {$_.objectName} # , {$_.groupName}
            foreach($group in $groups){
                $records = $group.group | Sort-Object -Property lastRunTime
                $primaryRecord = $records[-1]
                $primaryRecord.numSuccessfulBackups = ($records.numSuccessfulBackups | Measure-Object -sum).sum
                $primaryRecord.numUnsuccessfulBackups = ($records.numUnsuccessfulBackups | Measure-Object -sum).sum
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
        # merge failures
        if($reportName -eq 'failures'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.system}, {$_.sourceName}, {$_.objectType}, {$_.objectName} # , {$_.groupName}
            foreach($group in $groups){
                $records = $group.group | Sort-Object -Property lastFailedRunUsecs
                $primaryRecord = $records[-1]
                $primaryRecord.failedBackups = ($records.failedBackups | Measure-Object -sum).sum
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
        # merge protected / unprotected objects
        if($reportName -eq 'protected / unprotected objects'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.systems}, {$_.sourceName}, {$_.objectType}, {$_.environment}, {$_.objectName}
            foreach($group in $groups){
                $records = $group.group
                $primaryRecord = $records[0]
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
        # merge protection group summary
        if($reportName -eq 'protection group summary'){
            $newCSV = @()
            $groups = $csv | Group-Object -Property {$_.system}, {$_.sourceEnvironment}, {$_.groupName}
            foreach($group in $groups){
                $records = $group.group | Sort-Object -Property lastRunTimeUsecs
                $primaryRecord = $records[-1]
                $primaryRecord.successfulBackups = ($records.successfulBackups | Measure-Object -sum).sum
                $primaryRecord.failedBackups = ($records.failedBackups | Measure-Object -sum).sum
                $primaryRecord.dataIngestBytes = ($records.dataIngestBytes | Measure-Object -sum).sum
                $newCSV = @($newCSV + $primaryRecord)
            }
            $csv = $newCSV
        }
    }
    if($x -eq 0){
        $csv | Export-CSV -Path $csvFileName
        $x = 1
    }else{
        $csv | Export-CSV -Path $csvFileName -Append
    }
}

Write-Host "`nCSV output saved to $csvFileName`n"
