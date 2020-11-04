[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #cohesity username
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][Int64]$days, # number of days back to gather statistics
    [Parameter()][ValidateSet("Daily","Weekly","Monthly")][string]$rollup = 'Daily' # show daily, weekly or monthly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain


function processStats($stats, $name, $environment, $location){
    
    "`n    $name`n" | Tee-Object -FilePath $outFile -Append
    $entityListId = $stats.statsList[0].groupList[0].entityId

    $timeSeries = api get "statistics/timeSeriesStats?startTimeMsecs=$daysAgoMsecs&schemaName=BookKeeperStats&metricName=ChunkBytesPhysical&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=$entityListId&endTimeMsecs=$todayMsecs"
    foreach($dataPoint in $timeSeries.dataPointVec | Sort-Object -Property timestampMsecs){
        $timeStampMsecs = $dataPoint.timestampMsecs
        $timeStamp = usecsToDate ($timeStampMsecs * 1000)
        $consumedBytes = $dataPoint.data.int64Value
        $consumedGiB = [math]::Round($consumedBytes / (1024 * 1024 * 1024), 2)
        $showStat = $false
        if($rollup -eq 'Monthly'){
            if($timeStamp.Day -eq 1 -or $timeStamp.Day -eq 2){
                $showStat = $True
            }
        }elseif($rollup -eq 'Weekly'){
            if($timeStamp.DayOfWeek -eq 'Sunday' -or $timeStamp.DayOfWeek -eq 'Monday'){
                $showStat = $True
            }
            
        }else{
            $showStat = $True
        }
        if($showStat){
            "        {0,30} {1,11:f2} GiB" -f $timeStamp, $consumedGiB | Tee-Object -FilePath $outFile -Append
        }
    }
}

$todayMsecs = (dateToUsecs (Get-Date))/1000
$daysAgoMsecs = (dateToUsecs ((Get-Date).AddDays(-$days)))/1000
$cluster = api get cluster
$jobs = api get protectionJobs?allUnderHierarchy=true
$views = api get views?allUnderHierarchy=true

$outFile = Join-Path -Path $PSScriptRoot -ChildPath "$($cluster.name)-consumptionReport.txt"

"`nLocal Jobs..." | Tee-Object -FilePath $outFile

foreach($job in $jobs | Sort-Object -Property name){
    if($job.policyId.split(':')[0] -eq $cluster.id){
        $stats = api get "stats/consumers?consumerType=kProtectionRuns&consumerIdList=$($job.id)"
        if($stats.statsList){
            processStats $stats $job.name $job.environment.subString(1) 'Local'
        }
    }
}

"`nUnprotected Views..." | Tee-Object -FilePath $outFile -Append
foreach($view in $views.views | Sort-Object -Property name | Where-Object viewProtection -eq $null){
    $stats = api get "stats/consumers?consumerType=kViews&consumerIdList=$($view.viewId)"
    if($stats.statsList){
        processStats $stats $view.name 'View' 'Local'
    }
}

"`nReplicated Jobs..." | Tee-Object -FilePath $outFile -Append
foreach($job in $jobs | Sort-Object -Property name){
    if($job.policyId.split(':')[0] -ne $cluster.id){
        $stats = api get "stats/consumers?consumerType=kReplicationRuns&consumerIdList=$($job.id)"
        if($stats.statsList){
            processStats $stats $job.name $job.environment.subString(1) 'Replicated'
        }
    }
}

"`nOutput saved to $outFile`n"
