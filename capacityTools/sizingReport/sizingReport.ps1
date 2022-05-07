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
$objectFileName = "SizingReport-PerObject-$($cluster.name)-$dateString.csv"
"""Owner"",""Job Name"",""Job Type"",""Source Name"",""Logical $unit"",""Peak Read $unit"",""Last Day Read $unit"",""Read Over Days $unit"",""Avg Read $unit"",""Last Day Written $unit"",""Written Over Days $unit"",""Avg Written $unit"",""Days Collected"",""Daily Read Change Rate %"",""Daily Write Change Rate %"",""Avg Replica Queue Hours"",""Avg Replica Hours"",""Avg Logical Replicated"",""Avg Physical Replicated""" | Out-File -FilePath $objectFileName

$runningTasks = 0

$now = (Get-Date).AddDays(-$backDays)
$daysBackUsecs = dateToUsecs $now.AddDays(-$daysBack)

$jobStats = @{}
$workloadStats = @{}
$clusterStats = @{}

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
            $changeRate = [math]::Round((100 * $xDaysDataRead / $logicalSize) / $numDays, 0)
            $writeChangeRate = [math]::Round((100 * $xDaysDataWritten/ $logicalSize) / $numDays, 0)
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
        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}"",""{12}"",""{13}"",""{14}"",""{15}"",""{16}"",""{17}"",""{18}""" -f $owner, $jobName, $jobType, $sourceName, $(toUnits $logicalSize), $(toUnits $peakRead), $(toUnits $lastDayDataRead), $(toUnits $xDaysDataRead), $(toUnits $avgDataRead), $(toUnits $lastDayDataWritten), $(toUnits $xDaysDataWritten), $(toUnits $avgDataWritten), $numDays, $changeRate, $writeChangeRate, $avgReplicaDelay, $avgReplicaDuration, $(toUnits $avgLogicalReplicated), $(toUnits $avgPhysicalReplicated) | Out-File -FilePath $objectFileName -Append
        if($jobName -notin $jobStats.Keys){
            $jobStats[$jobName] = @{
                'owner' = $owner;
                'jobType' = $jobType;
                'avgDataWritten' = $avgDataWritten;
                'avgDataRead' = $avgDataRead;
                'logicalSize' = $logicalSize;
                'avgLogicalReplicated' = $avgLogicalReplicated;
                'avgPhysicalReplicated' = $avgPhysicalReplicated
            }
        }else{
            $jobStats[$jobName].avgDataWritten += $avgDataWritten
            $jobStats[$jobName].avgDataRead += $avgDataRead
            $jobStats[$jobName].logicalSize += $logicalSize
            $jobStats[$jobName].avgLogicalReplicated += $avgLogicalReplicated
            $jobStats[$jobName].avgPhysicalReplicated += $avgPhysicalReplicated
        }
    }
}

# Per Job Stats
$jobFileName = "SizingReport-PerJob-$($cluster.name)-$dateString.csv"

"""Owner"",""JobName"",""JobType"",""Logical $unit"",""Avg Read $unit"",""Avg Written $unit"",""Read Change Rate"",""Write Change Rate"",""Avg Logical Replicated $unit"",""Avg Physical Replicated $unit""" | Out-File -FilePath $jobFileName 
foreach($jobName in ($jobStats.Keys | sort)){
    $owner = $jobStats[$jobName].owner
    $jobType = $jobStats[$jobName].jobType
    $logicalSize = 0
    $avgDataRead = 0
    $avgDataWritten = 0
    $logicalSize = $jobStats[$jobName].logicalSize
    $avgDataRead = $jobStats[$jobName].avgDataRead
    $avgDataWritten = $jobStats[$jobName].avgDataWritten
    $avgLogicalReplicated = $jobStats[$jobName].avgLogicalReplicated
    $avgPhysicalReplicated = $jobStats[$jobName].avgPhysicalReplicated
    if("$($owner)--$($jobType)" -notin $workloadStats.Keys){
        $workloadStats["$($owner)--$($jobType)"] = @{
            'logicalSize' = $logicalSize;
            'avgDataRead' = $avgDataRead;
            'avgDataWritten' = $avgDataWritten
            'avgLogicalReplicated' = $avgLogicalReplicated
            'avgPhysicalReplicated' = $avgPhysicalReplicated
        }
    }else{
        $workloadStats["$($owner)--$($jobType)"].logicalSize += $logicalSize
        $workloadStats["$($owner)--$($jobType)"].avgDataRead += $avgDataRead
        $workloadStats["$($owner)--$($jobType)"].avgDataWritten += $avgDataWritten
        $workloadStats["$($owner)--$($jobType)"].avgLogicalReplicated += $avgLogicalReplicated
        $workloadStats["$($owner)--$($jobType)"].avgPhysicalReplicated += $avgPhysicalReplicated
    }
    if($logicalSize -gt 0){
        $changeRate = [math]::Round(100 * $avgDataRead / $logicalSize, 0)
        $writeChangeRate = [math]::Round(100 * $avgDataWritten / $logicalSize, 0)
    }else{
        $changeRate = '-'
        $writeChangeRate = '-'
    }
    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}""" -f $owner, $jobName, $jobType, $(toUnits $logicalSize), $(toUnits $avgDataRead), $(toUnits $avgDataWritten), $changeRate, $writeChangeRate, $(toUnits $avgLogicalReplicated), $(toUnits $avgPhysicalReplicated) | Out-File -FilePath $jobFileName -Append
}

# Per Workload Stats
$workloadFileName = "SizingReport-PerWorkload-$($cluster.name)-$dateString.csv"

"""Owner"",""JobType"",""Logical $unit"",""Avg Read $unit"",""Avg Written $unit"",""Read Change Rate"",""Write Change Rate""" | Out-File -FilePath $workloadFileName

foreach($keyName in ($workloadStats.Keys | sort)){
    $owner, $jobType = $keyName.split('--')
    $logicalSize = $workloadStats[$keyName].logicalSize
    $avgDataRead = $workloadStats[$keyName].avgDataRead
    $avgDataWritten = $workloadStats[$keyName].avgDataWritten
    $avgLogicalReplicated = $workloadStats[$keyName].avgLogicalReplicated
    $avgPhysicalReplicated = $workloadStats[$keyName].avgPhysicalReplicated
    if($logicalSize -gt 0){
        $changeRate = [math]::Round(100 * $avgDataRead / $logicalSize, 0)
        $writeChangeRate = [math]::Round(100 * $avgDataWritten / $logicalSize, 0)
    }else{
        $changeRate = '-'
        $writeChangeRate = '-'
    }
    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}""" -f $owner, $jobType, $(toUnits $logicalSize), $(toUnits $avgDataRead), $(toUnits $avgDataWritten), $changeRate, $writeChangeRate | Out-File -FilePath $workloadFileName -Append
}
