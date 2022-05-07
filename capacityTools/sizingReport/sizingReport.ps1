### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
   [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
   [Parameter()][string]$domain = 'local', #local or AD domain
   [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
   [Parameter()][int]$daysBack = 7,
   [Parameter()][Int64]$numRuns = 100,
   [Parameter()][Int64]$backDays = 0
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

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "Sizing Report-$($cluster.name)-$dateString.csv"
"""Owner"",""Job Name"",""Job Type"",""Source Name"",""Logical $unit"",""Peak Read $unit"",""Last Day Read $unit"",""Read Over Days $unit"",""Avg Read $unit"",""Last Day Written $unit"",""Written Over Days $unit"",""Avg Written $unit"",""Days Collected"",""Daily Read Change Rate %"",""Daily Write Change Rate %"",""Avg Replica Queue Hours"",""Avg Replica Hours"",""Avg Logical Replicated"",""Avg Physical Replicated""" | Out-File -FilePath $outfileName

$runningTasks = 0

$now = (Get-Date).AddDays(-$backDays)
$daysBackUsecs = dateToUsecs $now.AddDays(-$daysBack)

foreach($job in (api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true").protectionGroups | Sort-Object -Property name){
    $jobId = $job.id
    $jobName = $job.name
    "$jobName"
    $jobType = $job.environment.Substring(1)
    $stats = @{}
    $owners = @{}
    $endUsecs = dateToUsecs $now
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
                if(!($run.environment -eq 'kAD' -and $server.object.objectType -eq 'kDomainController')){
                    if($server.PSObject.Properties['originalBackupInfo']){
                        $logicalBytes = $server.originalBackupInfo.snapshotInfo.stats.logicalSizeBytes
                        $bytesRead = $server.originalBackupInfo.snapshotInfo.stats.bytesRead
                        $bytesWritten = 0
                        if($server.PSObject.Properties['replicationInfo']){
                            $bytesWritten = $server.replicationInfo.replicationTargetResults.stats.physicalBytesTransferred
                        }
                        $owner = $run.originClusterIdentifier.clusterName
                    }else{
                        $logicalBytes = $server.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
                        $bytesRead = $server.localSnapshotInfo.snapshotInfo.stats.bytesRead
                        $bytesWritten = $server.localSnapshotInfo.snapshotInfo.stats.bytesWritten
                        $owner = $cluster.name
                    }
                    $logicalReplicated = 0
                    $physicalReplicated = 0
                    $replicaDelay = 0
                    $replicaDuration = 0
                    if($server.PSObject.Properties['replicationInfo']){
                        $replicaQueuedTime = $server.replicationInfo.replicationTargetResults[0].queuedTimeUsecs
                        $replicaStartTime = $server.replicationInfo.replicationTargetResults[0].startTimeUsecs
                        $replicaEndTime = $server.replicationInfo.replicationTargetResults[0].endTimeUsecs
                        $replicaDelay = ($replicaStartTime - $replicaQueuedTime) / 3600000000
                        $replicaDuration = ($replicaEndTime - $replicaStartTime) / 3600000000
                        $server.replicationInfo.replicationTargetResults.stats.logicalBytesTransferred | ForEach-Object {$logicalReplicated += $_}
                        $server.replicationInfo.replicationTargetResults.stats.physicalBytesTransferred | ForEach-Object {$physicalReplicated += $_}
                    }
                    if($sourceName -notin $stats.Keys){
                        $stats[$sourceName] = @()
                    }
                    $stats[$sourceName] += @{'startTimeUsecs' = $runStartTimeUsecs;
                                             'dataRead' = $bytesRead;
                                             'dataWritten' = $bytesWritten;
                                             'logicalSize' = $logicalBytes;
                                             'replicaDelay' = $replicaDelay;
                                             'replicaDuration' = $replicaDuration;
                                             'logicalReplicated' = $logicalReplicated;
                                             'physicalReplicated' = $physicalReplicated
                                            }
                    $owners[$sourceName] = $owner
                }
            }
        }
    }
    foreach($sourceName in ($stats.Keys | sort)){
        "  $sourceName"
        $owner = $owners[$sourceName]

        # logical size
        $logicalSize = ($stats[$sourceName].logicalSize | Measure-Object -Maximum).Maximum

        # last 24 hours
        $midnight = (get-date -Hour 0 -Minute 0).AddDays(-$backDays)
        $midnightUsecs = dateToUsecs $midnight
        $lastDay = dateToUsecs ($midnight.AddDays(-1))
        $lastDayStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $lastDay -and $_.startTimeUsecs -lt $midnightUsecs}
        $lastDayDataRead = 0
        $lastDayStats.dataRead | foreach-object{ $lastDayDataRead += $_ }
        $lastDayDataWritten = 0
        $lastDayStats.dataWritten | ForEach-Object{ $lastDayDataWritten += $_}

        # last X days
        $xDays = dateToUsecs ((get-date -Hour 0 -Minute 0).AddDays(-($daysBack + $backDays)))
        $xDaysStats = $stats[$sourceName] | Where-Object {$_.startTimeUsecs -ge $xDays}
        $xDaysDataRead = 0
        $xDaysStats.dataRead | foreach-object{ $xDaysDataRead += $_ }
        $xDaysDataWritten = 0
        $xDaysStats.dataWritten | ForEach-Object{ $xDaysDataWritten += $_}
        $peakRead = ($xDaysStats.dataRead | Measure-Object -Maximum).Maximum
        $xDaysReplicaDelay = 0
        $xDaysStats.replicaDelay | foreach-object{ $xDaysReplicaDelay += $_ }
        $xDaysLogicalReplicated = 0
        $xDaysStats.logicalReplicated | foreach-object { $xDaysLogicalReplicated += $_ }
        $xDaysPhysicalReplicated = 0
        $xDaysStats.physicalReplicated | foreach-object { $xDaysPhysicalReplicated += $_ }
        $xDaysReplicaDuration = 0
        $xDaysStats.replicaDuration | foreach-object { $xDaysReplicaDuration += $_ }
        # number of days gathered
        $oldestStat = usecsToDate $stats[$sourceName][-1]['startTimeUsecs']
        $numDays = ($now - $oldestStat).Days + 1
        if($logicalSize -gt 0){
            $changeRate = 100 * [math]::Round(($xDaysDataRead / $logicalSize) / $numDays, 2)
            $writeChangeRate = 100 * [math]::Round(($xDaysDataWritten/ $logicalSize) / $numDays, 2)
        }else{
            $changeRate = '-'
            $writeChangeRate = '-'
        }
        $avgDataRead = [math]::Round($xDaysDataRead / $numDays, 2)
        $avgDataWritten = [math]::Round($xDaysDataWritten / $numDays, 2)
        $avgReplicaDelay = [math]::Round($xDaysReplicaDelay / $numDays, 0)
        $avgReplicaDuration = [math]::Round($xDaysReplicaDuration / $numDays, 0)
        $avgLogicalReplicated = [math]::Round($xDaysLogicalReplicated / $numDays, 2)
        $avgPhysicalReplicated = [math]::Round($xDaysPhysicalReplicated / $numDays, 2)
        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}"",""{12}"",""{13}"",""{14}"",""{15}"",""{16}"",""{17}"",""{18}""" -f $owner, $jobName, $jobType, $sourceName, $(toUnits $logicalSize), $(toUnits $peakRead), $(toUnits $lastDayDataRead), $(toUnits $xDaysDataRead), $(toUnits $avgDataRead), $(toUnits $lastDayDataWritten), $(toUnits $xDaysDataWritten), $(toUnits $avgDataWritten), $numDays, $changeRate, $writeChangeRate, $avgReplicaDelay, $avgReplicaDuration, $(toUnits $avgLogicalReplicated), $(toUnits $avgPhysicalReplicated) | Out-File -FilePath $outfileName -Append
    }
}
