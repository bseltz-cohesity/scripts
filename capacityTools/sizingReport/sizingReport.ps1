### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
   [Parameter()][int]$daysBack = 7,
   [Parameter()][Int64]$numRuns = 100
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

### authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('Succeeded', 'Canceled', 'Failed', 'Warning')

$today = Get-Date

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "Sizing Report-$($cluster.name)-$dateString.csv"
"Owner,Job Name,Job Type,Source Name,Logical $unit,Peak Read $unit,Last Day Read $unit,Read Over Days $unit,Last Day Written $unit,Written Over Days $unit,Days Collected,Daily Read Change Rate %,Daily Write Change Rate %" | Out-File -FilePath $outfileName

$nowUsecs = dateToUsecs (get-date)

$runningTasks = 0

$now = Get-Date
$nowUsecs = dateToUsecs $now
$daysBackUsecs = dateToUsecs $now.AddDays(-$daysBack)

foreach($job in (api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true").protectionGroups | Sort-Object -Property name){
    $jobId = $job.id
    $jobName = $job.name
    "$jobName"
    $jobType = $job.environment.Substring(1)
    $stats = @{}
    $owners = @{}
    $endUsecs = dateToUsecs (Get-Date)
    while($True){
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=True&numRuns=$numRuns"
        if($runs.runs.Count -gt 0){
            $endUsecs = $runs.runs[-1].localBackupInfo.startTimeUsecs - 1
        }else{
            break
        }
        foreach($run in $runs.runs){
            $runId = $run.id
            if($run.PSObject.Properties['originalBackupInfo']){
                $runStartTimeUsecs = $run.originalBackupInfo.startTimeUsecs
            }else{
                $runStartTimeUsecs = $run.localBackupInfo.startTimeUsecs
            }
            if($runStartTimeUsecs -lt $daysBackUsecs){
                break
            }
            foreach($server in ($run.objects | Sort-Object -Property {$_.object.name})){
                $sourceName = $server.object.name
                if($server.PSObject.Properties['originalBackupInfo']){
                    $logicalBytes = $server.originalBackupInfo.snapshotInfo.stats.logicalSizeBytes
                    $bytesRead = $server.originalBackupInfo.snapshotInfo.stats.bytesRead
                    $bytesWritten = 0
                    $owner = $run.originClusterIdentifier.clusterName
                }else{
                    $logicalBytes = $server.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
                    $bytesRead = $server.localSnapshotInfo.snapshotInfo.stats.bytesRead
                    $bytesWritten = $server.localSnapshotInfo.snapshotInfo.stats.bytesWritten
                    $owner = $cluster.name
                }
                if($sourceName -notin $stats.Keys){
                    $stats[$sourceName] = @()
                }
                $stats[$sourceName] += @{'startTimeUsecs' = $runStartTimeUsecs;
                                         'dataRead' = $bytesRead;
                                         'dataWritten' = $bytesWritten;
                                         'logicalSize' = $logicalBytes}
                $owners[$sourceName] = $owner
            }
        }
    }
    foreach($sourceName in ($stats.Keys | sort)){
        "  $sourceName"
        $owner = $owners[$sourceName]
        # logical size
        $logicalSize = $stats[$sourceName][0].logicalSize
        
        # last 24 hours
        $midnight = get-date -Hour 0 -Minute 0
        $midnightUsecs = dateToUsecs $midnight
        $last24Hours = dateToUsecs ($midnight.AddDays(-1))
        $last24HourStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $last24Hours -and $_.startTimeUsecs -lt $midnightUsecs}
        $last24HoursDataRead = 0
        $last24HourStats.dataRead | foreach-object{ $last24HoursDataRead += $_ }
        $last24HoursDataWritten = 0
        $last24HourStats.dataWritten | ForEach-Object{ $last24HoursDataWritten += $_}

        # last X days
        $lastXDays = dateToUsecs ((get-date -Hour 0 -Minute 0).AddDays(-$daysBack))
        $lastXDaysStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $lastXDays}
        $lastXDaysDataRead = 0
        $lastXDaysStats.dataRead | foreach-object{ $lastXDaysDataRead += $_ }
        $lastXDaysDataWritten = 0
        $lastXDaysStats.dataWritten | ForEach-Object{ $lastXDaysDataWritten += $_}
        $peakRead = ($lastXDaysStats.dataRead | Measure-Object -Maximum).Maximum

        # number of days gathered
        $oldestStat = usecsToDate $stats[$sourceName][-1]['startTimeUsecs']
        $numDays = ($today - $oldestStat).Days + 1
        if($logicalSize -gt 0){
            $changeRate = 100 * [math]::Round(($lastXDaysDataRead / $logicalSize) / $numDays, 2)
            # if($changeRate -gt 100){
            #     $changeRate = '-'
            # }
            $writeChangeRate = 100 * [math]::Round(($lastXDaysDataWritten/ $logicalSize) / $numDays, 2)
        }else{
            $changeRate = '-'
            $writeChangeRate = '-'
        }

        "{0},{1},{2},{3},""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",{10},{11},{12}" -f $owner, $jobName, $jobType, $sourceName, $(toUnits $logicalSize), $(toUnits $peakRead), $(toUnits $last24HoursDataRead), $(toUnits $lastXDaysDataRead), $(toUnits $last24HoursDataWritten), $(toUnits $lastXDaysDataWritten), $numDays, $changeRate, $writeChangeRate | Out-File -FilePath $outfileName -Append
    }
}
