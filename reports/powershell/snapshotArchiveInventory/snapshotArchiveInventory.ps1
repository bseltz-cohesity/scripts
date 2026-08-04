# snapshotArchiveInventory.ps1
#
# Inventories every local snapshot and archive copy that is currently available for
# recovery across one or more Cohesity clusters (directly, or Helios/MCM-managed).
# Supports multiple clusters in a single run - see the -vip/-clusterName notes below,
# based on the baseAuth-multi.ps1 pattern. All clusters are written to one combined
# output file (each row already carries a Cluster Name column).
#
# Built from the baseV2Report.ps1 template, using the v2 data-protect APIs
# documented in cluster_v2_api.yaml:
#   GET  /data-protect/protection-groups                       (list jobs)
#   GET  /data-protect/protection-groups/{id}/runs              (via Get-Runs helper)
#   GET  /protectionSources/registrationInfo                    (resolve source names)
#
# For each restorable run, every object's localSnapshotInfo (the copy stored on this
# cluster, whether it was backed up locally or replicated in - a run's
# isReplicationRun/originClusterIdentifier fields tell us which) and
# archivalInfo.archivalTargetResults (archive copies, e.g. Cloud/Tape/Nas targets)
# are inspected. If a replicated run has no full local copy, object.originalBackupInfo
# is used as a fallback to still report the copy.
#
# Archival copies are tracked two ways by the API. Cloud Archive Direct writes
# straight to the target, so per-object archivalInfo.archivalTargetResults is
# populated directly. A regular "secondary copy" archival task instead only shows
# up at the run level (run.archivalInfo.archivalTargetResults) - there is no
# per-object breakdown, because the whole run's snapshot is archived as a unit.
# For those, we infer an object-level recovery point for every object that has a
# valid snapshot in the run and isn't already covered by its own object-level
# entry for that target. The Logical Size shown for an inferred entry is the whole
# archival task's aggregate size, not a true per-object figure - there isn't one
# available from the API for these copies.
#
# Only entries that have a snapshotId, are not manually deleted, and have not
# passed their expiration time are reported, unless -includeExpired is specified.
#
# Multi-cluster usage:
#   -vip can be one or more direct cluster VIPs/FQDNs (each authenticated separately),
#   or the default 'helios.cohesity.com' for Helios/MCM. When connecting through
#   Helios, -clusterName selects one or more managed clusters by name; if omitted,
#   every cluster visible to that Helios/MCM account is inventoried.

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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][array]$clusterName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][int]$days,
    [Parameter()][switch]$includeExpired,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'GiB',
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$now = Get-Date
$nowUsecs = dateToUsecs $now

$daysBackUsecs = $null
if($days){
    $daysBack = $now.AddDays(-$days)
    $daysBackUsecs = dateToUsecs $daysBack
}

# outfile - one combined file for every cluster in this run (each row carries its own Cluster Name)
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "snapshotArchiveInventory-$dateString.tsv"

# headings
$headings = "Cluster Name
Tenant
Job Name
Environment
Run Type
Run Start Time
Object Name
Registered Source
Recovery Type
Target Name
Target Type
Snapshot Start Time
Snapshot End Time
Expiration Time
Status
On Legal Hold
Logical Size ($unit)"
$headings = $headings -split "`n" -join "`t"
$headings | Out-File -FilePath $outfileName -Encoding utf8

# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    if($null -eq $val){
        return ''
    }
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

# write a tab separated row to the output file
function writeRow([array]$values){
    ($values -join "`t") | Out-File -FilePath $outfileName -Append -Encoding utf8
}

# returns $true if a usecs timestamp is in the past (i.e. expired)
function isExpired($expiryUsecs){
    if($null -eq $expiryUsecs -or $expiryUsecs -eq 0){
        # no expiration set - kept forever (e.g. legal hold, or no retention policy applied)
        return $false
    }
    return ($expiryUsecs -lt $nowUsecs)
}

# local snapshot status (kSuccessful, kFailed, ...) and archive/replication target
# status (Succeeded, Failed, ...) use two different vocabularies for the same
# outcomes - map both onto one canonical set of words
$statusMap = @{
    'kSuccessful'               = 'Succeeded'
    'kFailed'                   = 'Failed'
    'kInProgress'                = 'Running'
    'kWarning'                  = 'SucceededWithWarning'
    'kWaitingForNextAttempt'    = 'Missed'
    'kWaitingForOlderBackupRun' = 'Missed'
    'kCurrentAttemptPaused'     = 'Paused'
    'kCurrentAttemptResuming'   = 'Resuming'
    'kCurrentAttemptPausing'    = 'Pausing'
    'kSkipped'                  = 'Skipped'
}
function normalizeStatus($status){
    if(! $status){
        return $status
    }
    if($statusMap.ContainsKey($status)){
        return $statusMap[$status]
    }
    if($status -match '^k[A-Z]'){
        return $status.subString(1)
    }
    return $status
}

# strips any legacy 'k' prefix (e.g. kCloud, kTape) so target type values are consistent
function normalizeEnum($value){
    if(! $value){
        return $value
    }
    if($value -match '^k[A-Z]'){
        return $value.subString(1)
    }
    return $value
}

# best effort run-level start time (works for local, replicated and archive-only runs)
function getRunStartTime($run){
    if($run.PSObject.Properties['localBackupInfo'] -and $run.localBackupInfo.PSObject.Properties['startTimeUsecs']){
        return usecsToDate $run.localBackupInfo.startTimeUsecs
    }
    if($run.PSObject.Properties['originalBackupInfo'] -and $run.originalBackupInfo.PSObject.Properties['startTimeUsecs']){
        return usecsToDate $run.originalBackupInfo.startTimeUsecs
    }
    if($run.PSObject.Properties['archivalInfo'] -and $run.archivalInfo.archivalTargetResults -and $run.archivalInfo.archivalTargetResults.Count -gt 0){
        return usecsToDate $run.archivalInfo.archivalTargetResults[0].startTimeUsecs
    }
    return $null
}

# best effort run-level run type (Incremental/Full/Log/System)
function getRunType($run){
    $rawType = $null
    if($run.PSObject.Properties['localBackupInfo'] -and $run.localBackupInfo.PSObject.Properties['runType']){
        $rawType = $run.localBackupInfo.runType
    }elseif($run.PSObject.Properties['originalBackupInfo'] -and $run.originalBackupInfo.PSObject.Properties['runType']){
        $rawType = $run.originalBackupInfo.runType
    }elseif($run.PSObject.Properties['archivalInfo'] -and $run.archivalInfo.archivalTargetResults -and $run.archivalInfo.archivalTargetResults.Count -gt 0){
        $rawType = $run.archivalInfo.archivalTargetResults[0].runType
    }
    if(! $rawType){
        return 'Unknown'
    }
    $runType = $rawType.subString(1)
    if($runType -eq 'Regular'){
        $runType = 'Incremental'
    }
    return $runType
}

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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

# running totals across every cluster in this run
$localCount = 0
$archiveCount = 0
$inferredArchiveCount = 0
$replicatedCount = 0

# inventories whichever cluster is currently selected in the cohesity-api session
# (called once per -vip, or once per Helios-managed -clusterName)
function inventoryCluster(){
    $cluster = api get cluster
    "`n$($cluster.name)"

    $jobs = api get -v2 "data-protect/protection-groups?includeTenants=true"

    if($jobNames.Count -gt 0){
        $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
        if($notfoundJobs){
            Write-Host "    jobs not found on $($cluster.name): $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        }
    }

    $sources = api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
            $environment = $job.environment.subString(1)
            $tenant = $job.permissions.name -join ', '
            "  {0} ({1})" -f $job.name, $environment

            if($includeExpired){
                $runs = Get-Runs -jobId $job.id -includeObjectDetails -includeDeleted -startTimeUsecs $daysBackUsecs
            }else{
                # default: excludeNonRestorableRuns=true is applied server-side, so only
                # runs with at least one currently recoverable local/archive copy come back
                $runs = Get-Runs -jobId $job.id -includeObjectDetails -startTimeUsecs $daysBackUsecs
            }

            foreach($run in $runs){
                if(! $run.PSObject.Properties['objects']){
                    continue
                }
                $runType = getRunType $run
                if($runType -eq 'Log'){
                    continue
                }
                $runStartTime = getRunStartTime $run

                # a run replicated in from another cluster is flagged at the run level,
                # and carries the source cluster identity in originClusterIdentifier
                $isReplicationRun = $run.PSObject.Properties['isReplicationRun'] -and $run.isReplicationRun
                $originClusterName = $null
                if($isReplicationRun -and $run.PSObject.Properties['originClusterIdentifier'] -and $run.originClusterIdentifier){
                    $originClusterName = $run.originClusterIdentifier.clusterName
                }
                if($isReplicationRun -and ! $originClusterName){
                    $originClusterName = 'Unknown Cluster'
                }

                # secondary-copy archival tasks (non-CAD) only report at the run level
                $runArchivalTargets = @()
                if($run.PSObject.Properties['archivalInfo'] -and $run.archivalInfo.PSObject.Properties['archivalTargetResults'] -and $run.archivalInfo.archivalTargetResults){
                    $runArchivalTargets = @($run.archivalInfo.archivalTargetResults)
                }

                foreach($object in $run.objects){
                    $objectName = $object.object.name
                    if($environment -notin @('Oracle', 'SQL') -or ($environment -in @('Oracle', 'SQL') -and $object.object.objectType -ne 'kHost')){
                        if($object.object.PSObject.Properties['sourceId']){
                            $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
                            $registeredSourceName = $registeredSource.rootNode.name
                        }else{
                            $registeredSourceName = $objectName
                        }
                        if(! $registeredSourceName){
                            $registeredSourceName = $objectName
                        }

                        # ---- local snapshot (or, if this run was replicated in, the copy landed on this cluster) ----
                        $si = $null
                        if($object.PSObject.Properties['localSnapshotInfo'] -and $object.localSnapshotInfo.PSObject.Properties['snapshotInfo'] -and $object.localSnapshotInfo.snapshotInfo -and $object.localSnapshotInfo.snapshotInfo.PSObject.Properties['snapshotId'] -and $object.localSnapshotInfo.snapshotInfo.snapshotId){
                            $si = $object.localSnapshotInfo.snapshotInfo
                        }elseif($isReplicationRun -and $object.PSObject.Properties['originalBackupInfo'] -and $object.originalBackupInfo.PSObject.Properties['snapshotInfo'] -and $object.originalBackupInfo.snapshotInfo -and $object.originalBackupInfo.snapshotInfo.PSObject.Properties['snapshotId'] -and $object.originalBackupInfo.snapshotInfo.snapshotId){
                            # no full local copy on this cluster (e.g. metadata-only) - fall back to the origin cluster's snapshot info
                            $si = $object.originalBackupInfo.snapshotInfo
                        }
                        if($si){
                            $manuallyDeleted = $si.PSObject.Properties['isManuallyDeleted'] -and $si.isManuallyDeleted
                            $expired = isExpired $si.expiryTimeUsecs
                            if($includeExpired -or (! $manuallyDeleted -and ! $expired)){
                                $status = normalizeStatus $si.status
                                $startTime = $null
                                $endTime = $null
                                if($si.PSObject.Properties['startTimeUsecs'] -and $si.startTimeUsecs){ $startTime = usecsToDate $si.startTimeUsecs }
                                if($si.PSObject.Properties['endTimeUsecs'] -and $si.endTimeUsecs){ $endTime = usecsToDate $si.endTimeUsecs }
                                $expiryTime = $null
                                if($si.PSObject.Properties['expiryTimeUsecs'] -and $si.expiryTimeUsecs){ $expiryTime = usecsToDate $si.expiryTimeUsecs }
                                $logicalSize = toUnits $si.stats.logicalSizeBytes
                                $onLegalHold = [bool]($object.PSObject.Properties['onLegalHold'] -and $object.onLegalHold)

                                if($isReplicationRun){
                                    "    {0}: replicated in from {1} ({2})" -f $objectName, $originClusterName, $status
                                    writeRow @($cluster.name, $tenant, $job.name, $environment, $runType, $runStartTime, $objectName, $registeredSourceName, 'Replicated', $originClusterName, 'Cluster', $startTime, $endTime, $expiryTime, $status, $onLegalHold, $logicalSize)
                                    $script:replicatedCount++
                                }else{
                                    "    {0}: local snapshot ({1})" -f $objectName, $status
                                    writeRow @($cluster.name, $tenant, $job.name, $environment, $runType, $runStartTime, $objectName, $registeredSourceName, 'Local', '', '', $startTime, $endTime, $expiryTime, $status, $onLegalHold, $logicalSize)
                                    $script:localCount++
                                }
                            }
                        }

                        # ---- archive copies reported directly at the object level (e.g. Cloud Archive Direct) ----
                        # only a target that actually carries its own object-level snapshotId counts as "covered" -
                        # some non-CAD secondary-copy runs still list a targetId here with no snapshotId, and that
                        # must NOT suppress the run-level inference below, or the archive copy disappears entirely
                        $objectArchivalTargetIds = @()
                        if($object.PSObject.Properties['archivalInfo'] -and $object.archivalInfo.PSObject.Properties['archivalTargetResults'] -and $object.archivalInfo.archivalTargetResults){
                            foreach($target in $object.archivalInfo.archivalTargetResults){
                                if($target.PSObject.Properties['snapshotId'] -and $target.snapshotId){
                                    if($target.PSObject.Properties['targetId']){
                                        $objectArchivalTargetIds += $target.targetId
                                    }
                                    $manuallyDeleted = $target.PSObject.Properties['isManuallyDeleted'] -and $target.isManuallyDeleted
                                    $expired = isExpired $target.expiryTimeUsecs
                                    if($includeExpired -or (! $manuallyDeleted -and ! $expired)){
                                        $status = normalizeStatus $target.status
                                        $targetType = normalizeEnum $target.targetType
                                        $startTime = $null
                                        $endTime = $null
                                        if($target.PSObject.Properties['startTimeUsecs'] -and $target.startTimeUsecs){ $startTime = usecsToDate $target.startTimeUsecs }
                                        if($target.PSObject.Properties['endTimeUsecs'] -and $target.endTimeUsecs){ $endTime = usecsToDate $target.endTimeUsecs }
                                        $expiryTime = $null
                                        if($target.PSObject.Properties['expiryTimeUsecs'] -and $target.expiryTimeUsecs){ $expiryTime = usecsToDate $target.expiryTimeUsecs }
                                        $logicalSize = toUnits $target.stats.logicalSizeBytes
                                        $onLegalHold = [bool]($target.PSObject.Properties['onLegalHold'] -and $target.onLegalHold)

                                        "    {0}: archive on {1} ({2}, {3})" -f $objectName, $target.targetName, $targetType, $status
                                        writeRow @($cluster.name, $tenant, $job.name, $environment, $runType, $runStartTime, $objectName, $registeredSourceName, 'Archive', $target.targetName, $targetType, $startTime, $endTime, $expiryTime, $status, $onLegalHold, $logicalSize)
                                        $script:archiveCount++
                                    }
                                }
                            }
                        }

                        # ---- archive copies that only show up at the run level (secondary copy, non-CAD) ----
                        # every object that had a valid snapshot in this run was included in that archival task,
                        # unless the object already has its own object-level entry for the same target above
                        if($si -and $runArchivalTargets.Count -gt 0){
                            foreach($target in $runArchivalTargets){
                                # run-level archival target results don't reliably carry a snapshotId (that's only
                                # populated on the per-object entries), so gate on status instead of snapshotId
                                $alreadyCoveredAtObjectLevel = $target.PSObject.Properties['targetId'] -and ($target.targetId -in $objectArchivalTargetIds)
                                $status = normalizeStatus $target.status
                                if(! $alreadyCoveredAtObjectLevel -and $status -in @('Succeeded', 'SucceededWithWarning')){
                                    $manuallyDeleted = $target.PSObject.Properties['isManuallyDeleted'] -and $target.isManuallyDeleted
                                    $expired = isExpired $target.expiryTimeUsecs
                                    if($includeExpired -or (! $manuallyDeleted -and ! $expired)){
                                        $targetType = normalizeEnum $target.targetType
                                        $startTime = $null
                                        $endTime = $null
                                        if($target.PSObject.Properties['startTimeUsecs'] -and $target.startTimeUsecs){ $startTime = usecsToDate $target.startTimeUsecs }
                                        if($target.PSObject.Properties['endTimeUsecs'] -and $target.endTimeUsecs){ $endTime = usecsToDate $target.endTimeUsecs }
                                        $expiryTime = $null
                                        if($target.PSObject.Properties['expiryTimeUsecs'] -and $target.expiryTimeUsecs){ $expiryTime = usecsToDate $target.expiryTimeUsecs }
                                        # run-level stats are an aggregate across every object in the run, so this
                                        # is the whole archival task's size, not a true per-object breakdown
                                        $logicalSize = toUnits $target.stats.logicalSizeBytes
                                        $onLegalHold = [bool]($target.PSObject.Properties['onLegalHold'] -and $target.onLegalHold)

                                        "    {0}: archive on {1} ({2}, {3})" -f $objectName, $target.targetName, $targetType, $status
                                        writeRow @($cluster.name, $tenant, $job.name, $environment, $runType, $runStartTime, $objectName, $registeredSourceName, 'Archive', $target.targetName, $targetType, $startTime, $endTime, $expiryTime, $status, $onLegalHold, $logicalSize)
                                        $script:archiveCount++
                                        $script:inferredArchiveCount++
                                    }
                                }
                            }
                        }

                    }
                }
            }
        }
    }
}

# authentication / multi-cluster loop (see baseAuth-multi.ps1) =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if(! $USING_HELIOS -and $useApiKey -and $password){
        # a cluster API key specified on the command line won't work for multiple clusters
        $password = $null
    }
    if($USING_HELIOS){
        if(! $clusterName){
            # inventory every Helios/MCM-managed cluster if none were specified on the command line
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            inventoryCluster
        }
    }else{
        inventoryCluster
    }
}

"`n{0} local snapshots, {1} replicated snapshots, {2} archives" -f $localCount, $replicatedCount, $archiveCount
"`nOutput saved to $outfileName`n"

if($smtpServer -and $sendFrom -and $sendTo){
    write-host "Sending report to $([string]::Join(", ", $sendTo))`n"
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "snapshot/archive recovery inventory" -Body "snapshot/archive recovery inventory attached`n`n" -Attachments $outfileName -WarningAction SilentlyContinue
    }
}