# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][array]$clusterName = $null,
    [Parameter()][int]$days = 7,
    [Parameter()][switch]$includeLogs,
    [Parameter()][switch]$fullOnly,
    [Parameter()][switch]$localOnly,
    [Parameter()][string]$objectType,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'GiB',
    [Parameter()][string]$outputPath = '.',
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][switch]$amPmFormat,
    [Parameter()][switch]$onHoldOnly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$daysBack = (Get-Date).AddDays(-$days)
$daysBackUsecs = dateToUsecs $daysBack
$tail = "&startTimeUsecs=$daysBackUsecs"

# outfile
$now = Get-Date
$nowUsecs = dateToUsecs $now
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = $(Join-Path -Path $outputPath -ChildPath "protectionActivityReport-$dateString.csv")

# headings
$headings = "Cluster Name,Activity Type,Target,Start Time,End Time,Duration,status,slaStatus,snapshotStatus,objectName,sourceName,groupName,policyName,Object Type,backupType,Logical Size $unit,Data Read $unit,Data Written $unit,Logical Bytes Transferred $unit,Physical Bytes Transferred $unit,Organization Name"

$headings | Out-File -FilePath $outfileName

# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}

# normalize status
$normalizeStatus = @{
    'kSuccessful' = 'Succeeded';
    'kSuccess' = 'Succeeded';
    'kWarning' = 'SucceededWithWarning';
    'kFailure' = 'Failed';
    'kFailed' = 'Failed';
    'kCanceled' = 'Canceled';
    'kSkipped' = 'Skipped';
    'Succeeded' = 'Succeeded';
    'SucceededWithWarning' = 'SucceededWithWarning';
    'Failed' = 'Failed';
    'Canceled' = 'Canceled';
    'Skipped' = 'Skipped'
}

function toUnits($val){
    return ("{0:n1}" -f ($val/($conversion[$unit]))).replace(',','')
}

$query = ''
if($localOnly){
    $query = '&isActive=true'
}

function dateToString($dt, $format='yyyy-MM-dd HH:mm:ss'){
    if($dt -eq $null -or $dt -eq '-'){
        return '-'
    }else{
        if($amPmFormat){
            $format = 'yyyy-MM-dd hh:mm:ss tt'
        }
        return ($dt.ToString($format) -replace [char]8239, ' ')
    }
}

function reportReplications(){
    $thisActivityType = 'Replication'
    foreach($result in $object.replicationInfo.replicationTargetResults){
        $thisTarget = $result.clusterName
        if(!$thisTarget){
            continue
        }
        $replicationDurationSeconds = '-'
        $replicationEndTime = '-'
        if($result.PSObject.Properties['endTimeUsecs']){
            $replicationEndTime = usecsToDate $result.endTimeUsecs
            $replicationDurationSeconds = ("{0:n0}" -f ($replicationEndTime - $objectStartTime).totalSeconds).replace(',','')
        }
        $replicationStatus = $normalizeStatus[$result.status]
        if($replicationStatus -eq 'Succeeded' -and $normalizeStatus[$objectStatus] -ne $replicationStatus){
            $replicationStatus = $normalizeStatus[$objectStatus]
        }
        $replicationActivityType = 'Replication'
        if($result.PSObject.Properties['ownershipContext'] -and $result.ownershipContext -eq 'FortKnox'){
            $replicationActivityType = 'ReplicaVault'
        }
        $replicationLogicalBytesTransferred = toUnits $result.stats.logicalBytesTransferred
        $replicationPhysicalBytesTransferred = toUnits $result.stats.physicalBytesTransferred
        $cluster.name, $replicationActivityType, $result.clusterName, $(dateToString $objectStartTime), $(dateToString $replicationEndTime), $replicationDurationSeconds, $replicationStatus, $slaStatus, 'Active', $objectName, $registeredSourceName, $job.name, $policyName, $environment, $runType, $objectLogicalSizeBytes, '-', '-', $replicationLogicalBytesTransferred, $replicationPhysicalBytesTransferred, $tenant -join "," | Out-File -FilePath $outfileName -Append
    }
}

function reportArchives(){
    $thisActivityType = 'Archival'
    foreach($result in $run.archivalInfo.archivalTargetResults){
        $thisTarget = $result.targetName
        $archivalEndTime = '-'
        $archivalDurationSeconds = '-'
        if($result.PSObject.Properties['endTimeUsecs']){
            $archivalEndTime = usecsToDate $result.endTimeUsecs
            $archivalDurationSeconds = ("{0:n0}" -f ($archivalEndTime - $objectStartTime).totalSeconds).replace(',','')
        }
        $archiveStatus = $normalizeStatus[$result.status]
        if($archiveStatus -eq 'Succeeded' -and $normalizeStatus[$objectStatus] -ne $archiveStatus){
            $archiveStatus = $normalizeStatus[$objectStatus]
        }
        $archivalActivityType = 'Archival'
        if($result.PSObject.Properties['ownershipContext'] -and $result.ownershipContext -eq 'FortKnox'){
            $archivalActivityType = 'CloudVault'
        }
        # archivalInfo here is run-level (across all objects), so allocate this target's transfer
        # stats to the current object based on its share of the run's total local backup data read
        $archivalLogicalBytesTransferred = toUnits ($result.stats.logicalBytesTransferred * $objectShareOfRun)
        $archivalPhysicalBytesTransferred = toUnits ($result.stats.physicalBytesTransferred * $objectShareOfRun)
        $cluster.name, $archivalActivityType, $result.targetName, $(dateToString $objectStartTime), $(dateToString $archivalEndTime), $archivalDurationSeconds, $archiveStatus, $slaStatus, 'Active', $objectName, $registeredSourceName, $job.name, $policyName, $environment, $runType, $objectLogicalSizeBytes, '-', '-', $archivalLogicalBytesTransferred, $archivalPhysicalBytesTransferred, $tenant -join "," | Out-File -FilePath $outfileName -Append
    }
}

function reportBackup(){
    $runType = $backupInfo.runType
    $expiryTimeUsecs = $snapshotInfo.expiryTimeUsecs
    $objectName = $object.object.name
    $onLegalHold = $object.onLegalHold
    if($environment -notin @('kOracle', 'kSQL') -or ($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -notin @('kDatabase'))){
        
        $objectStatus = $snapshotInfo.status

        if($objectStatus -eq 'kSuccessful'){
            $objectStatus = 'kSuccess'
        }
        $objectStatus = $normalizeStatus[$objectStatus]
        if($snapshotInfo.startTimeUsecs){
            $objectStartTime = usecsToDate $snapshotInfo.startTimeUsecs
        }else{
            $objectStartTime = $runStartTime
        }
        
        $objectEndTime = $null
        $objectDurationSeconds = '-'
        if($snapshotInfo.PSObject.Properties['endTimeUsecs']){
            $objectEndTime = usecsToDate $snapshotInfo.endTimeUsecs
            $objectDurationSeconds = ("{0:n0}" -f ($objectEndTime - $objectStartTime).totalSeconds).replace(',','')
        }
        $objectLogicalSizeBytes = toUnits $snapshotInfo.stats.logicalSizeBytes
        $objectBytesRead = toUnits $snapshotInfo.stats.bytesRead
        if($snapshotInfo.stats.PSObject.Properties['bytesWritten']){
            # true local snapshot -> local read/write stats apply, no archival transfer stats here
            $objectBytesWritten = toUnits $snapshotInfo.stats.bytesWritten
            $objectLogicalBytesTransferred = '-'
            $objectPhysicalBytesTransferred = '-'
        }else{
            # archive-direct backup (no local snapshot) -> archival transfer stats live on this object's own stats
            $objectBytesWritten = '-'
            $objectLogicalBytesTransferred = toUnits $snapshotInfo.stats.logicalBytesTransferred
            $objectPhysicalBytesTransferred = toUnits $snapshotInfo.stats.physicalBytesTransferred
        }
        if(!$onHoldOnly -or $onLegalHold -eq $True){
            $cluster.name, $activityType, $target, $(dateToString $objectStartTime), $(dateToString $objectEndTime), $objectDurationSeconds, $objectStatus, $slaStatus, 'Active', $objectName, $registeredSourceName, $job.name, $policyName, $environment, $runType, $objectLogicalSizeBytes, $objectBytesRead, $objectBytesWritten, $objectLogicalBytesTransferred, $objectPhysicalBytesTransferred, $tenant -join "," | Out-File -FilePath $outfileName -Append
        }
    }
}

function reportRuns(){
    ""
    $cluster = api get cluster
    $thisCluster = $($cluster.name).ToUpper()
    $jobs = api get -v2 "data-protect/protection-groups?includeTenants=true$query"
    $sources = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false"
    $policies = api get -v2 data-protect/policies

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $endUsecs = $nowUsecs
        $environment = $job.environment
        $tenant = $job.permissions.name
        if(!$objectType -or $objectType -eq $environment){
            "{0}: {1}" -f $thisCluster, $job.name
            $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
            if(!$policyName){
                $policyName = '-'
            }
            $lastRunId = 0
            while($True){
                if($fullOnly){
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&runTypes=kFull$tail"
                }elseif($includeLogs){
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true$tail"
                }else{
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&runTypes=kIncremental,kFull$tail"
                }
                if(!$runs.runs -or $runs.runs.Count -eq 0 -or $runs.runs[-1].id -eq $lastRunId){
                    break
                }
                $runs.runs = $runs.runs | Where-Object {$_.id -ne $lastRunId}
                $lastRunId = $runs.runs[-1].id
                foreach($run in $runs.runs){
                    $localSources = @{}
                    $runTarget = 'Local'
                    if($run.PSObject.Properties['localBackupInfo']){
                        $backupInfo = $run.localBackupInfo
                        $runActivityType = 'Backup'
                    }elseif($run.PSObject.Properties['originalBackupInfo']){
                        $backupInfo = $run.originalBackupInfo
                        $runActivityType = 'Inbound Replication'
                    }else{
                        $backupInfo = $run.archivalInfo.archivalTargetResults[0]
                        $runActivityType = 'Archival'
                        $runTarget = $run.archivalInfo.archivalTargetResults[0].targetName
                    }
                    $runLevelArchives = $null
                    if($run.PSObject.Properties['archivalInfo'] -and $run.archivalInfo.PSObject.Properties['archivalTargetResults']){
                        $runLevelArchives = $run.archivalInfo.archivalTargetResults
                    }
                    $runType = $backupInfo.runType
                    if($includeLogs -or $runType -ne 'kLog'){
                        $runStartTime = usecsToDate $backupInfo.startTimeUsecs
                        if($days -and $daysBack -gt $runStartTime){
                            break
                        }
                        if($backupInfo.isSlaViolated){
                            $slaStatus = 'Missed'
                        }else{
                            $slaStatus = 'Met'
                        }
                        # "    {0}" -f $runStartTime
                        # total local backup data read across all objects in this run, used to allocate
                        # run-level archival transfer stats proportionally to each object
                        $totalRunBytesRead = 0
                        foreach($object in $run.objects){
                            if($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -eq 'kHost'){
                                $localSources["$($object.object.id)"] = $object.object.name
                            }
                            if($object.PSObject.Properties['localSnapshotInfo'] -and $object.localSnapshotInfo.snapshotInfo.stats.bytesRead){
                                $totalRunBytesRead += $object.localSnapshotInfo.snapshotInfo.stats.bytesRead
                            }
                        }
                        $lockUntil = ''
                        if($backupInfo.PSObject.Properties['dataLockConstraints']){
                            if($backupInfo.dataLockConstraints.expiryTimeUsecs -gt $nowUsecs -and $backupInfo.dataLockConstraints.mode -eq 'Compliance'){
                                $lockUntil = usecsToDate $backupInfo.dataLockConstraints.expiryTimeUsecs -format 'yyyy-MM-dd hh:mm'
                            }
                        }

                        foreach($object in $run.objects){
                            $objectName = $object.object.name
                            $onLegalHold = $object.onLegalHold
                            if($environment -notin @('kOracle', 'kSQL') -or ($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -notin @('kDatabase'))){
                                
                                if($object.object.PSObject.Properties['sourceId']){
                                    if($environment -in @('kOracle', 'kSQL')){
                                        $registeredSourceName = $localSources["$($object.object.sourceId)"]
                                    }else{
                                        $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
                                        $registeredSourceName = $registeredSource.rootNode.name
                                    }
                                    if(!$registeredSourceName){
                                        $registeredSourceName = $objectName
                                    }
                                }else{
                                    $registeredSourceName = $objectName
                                }
                                # reset to the run's default activity type/target before deciding how
                                # this particular object was protected
                                $target = $runTarget
                                $activityType = $runActivityType
                                if($object.PSObject.Properties['localSnapshotInfo']){
                                    $snapshotInfo = $object.localSnapshotInfo.snapshotInfo
                                    reportBackup
                                }elseif($object.PSObject.Properties['archivalInfo'] -and $object.archivalInfo.PSObject.Properties['archivalTargetResults']){
                                    # archive-direct object (no local snapshot) - it may have been sent to
                                    # more than one archival target, so report every one of them
                                    foreach($archiveDirectResult in $object.archivalInfo.archivalTargetResults){
                                        $snapshotInfo = $archiveDirectResult
                                        $target = $archiveDirectResult.targetName
                                        $activityType = 'Archival'
                                        if($archiveDirectResult.PSObject.Properties['ownershipContext'] -and $archiveDirectResult.ownershipContext -eq 'FortKnox'){
                                            $activityType = 'CloudVault'
                                        }
                                        reportBackup
                                    }
                                }
                                $objectStatus = $snapshotInfo.status
                                $objectLogicalSizeBytes = toUnits $snapshotInfo.stats.logicalSizeBytes
                                if($snapshotInfo.startTimeUsecs){
                                    $objectStartTime = usecsToDate $snapshotInfo.startTimeUsecs
                                }else{
                                    $objectStartTime = $runStartTime
                                }
                                # this object's share of the run's total local backup data read, used to
                                # allocate run-level archival transfer stats (logical/physical bytes transferred)
                                # proportionally across objects since those stats are only reported at the run level
                                if($totalRunBytesRead -gt 0 -and $snapshotInfo.stats.bytesRead){
                                    $objectShareOfRun = $snapshotInfo.stats.bytesRead / $totalRunBytesRead
                                }else{
                                    $objectShareOfRun = 0
                                }
                                if($object.PSObject.Properties['replicationInfo'] -and $object.replicationInfo.PSObject.Properties['replicationTargetResults']){
                                    reportReplications
                                }
                                if($runLevelArchives -ne $null -and $activityType -ne 'Archival' -and $activityType -ne 'CloudVault'){
                                    reportArchives
                                }
                            }
                            
                        }
                    }
                }
                if($runs.runs[-1].PSObject.Properties['localBackupInfo']){
                    $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs
                }elseif($runs.runs[-1].PSObject.Properties['originalBackupInfo']){
                    $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs
                }else{
                    $endUsecs = $runs.runs[-1].archivalInfo.archivalTargetResults[0].endTimeUsecs
                }
            }
        }
    }
}

# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
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
            reportRuns
        }
    }else{
        reportRuns
    }
}

"`nOutput saved to $outfilename`n"
