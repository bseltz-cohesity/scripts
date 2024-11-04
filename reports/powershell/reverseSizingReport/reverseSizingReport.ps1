### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][string]$accessCluster,
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'GiB',
    [Parameter()][int]$daysBack = 7,
    [Parameter()][Int64]$numRuns = 1000,
    [Parameter()][Int64]$backDays = 0
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

if($accessCluster){
    accessCluster $accessCluster
}

Write-Host "`nGathering Sizing info...`n"

$cluster = api get cluster?fetchStats=true

$now = (Get-Date).AddDays(-$backDays)
$daysBackUsecs = dateToUsecs $now.AddDays(-$daysBack)

$sizingData = @{}
$remotes = @()
$policyNames = @()

$policies = (api get -v2 "data-protect/policies").policies
$frequentSchedules = @('Minutes', 'Hours', 'Days')

$views = api get -v2 file-services/views?includeStats=true
$protectedViews = @()

foreach($job in (api get -v2 "data-protect/protection-groups?includeTenants=true").protectionGroups | Sort-Object -Property name){
    $maxRunBytes = 0
    $jobId = $job.id
    $jobName = $job.name
    Write-Host "$jobName"
    $jobType = $job.environment.Substring(1)
    if($jobType -eq 'VMware'){
        $vmsearch = api get "/searchvms?entityTypes=kVMware&jobIds=$(($jobId -split ':')[2])"
        $vmbytes = $runBytes = ($vmsearch.vms.vmDocument.objectId.entity.vmwareEntity.frontEndSizeInfo.sizeBytes | Measure-Object -sum).Sum
    }
    if($jobType -eq 'RemoteAdapter'){
        $jobType = 'View'
    }
    $policyName = '-'
    if($job.isActive -eq $True){
        $policy = $policies | Where-Object {$_.id -eq $job.policyId}
        $policyName = $policy.name
    }
    if($job.isDeleted -eq $True){
        $policyName = 'deleted'
    }
    $policyNames = @($policyNames + $policyName)
    if($policyName -notin $sizingData.Keys){
        $sizingData[$policyName] = @{}
    }
    if($jobType -notin $sizingData[$policyName].Keys){
        $sizingData[$policyName][$jobType] = @{}
    }
    $endUsecs = dateToUsecs $now
    while($True){
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&numRuns=$numRuns&runTypes=kIncremental,kFull&includeObjectDetails=True" # &includeObjectDetails=True
        if($runs.runs.Count -gt 0){
            if($runs.runs[-1].PSObject.Properties['originalBackupInfo']){
                $endUsecs = $runs.runs[-1].originalBackupInfo.startTimeUsecs - 1
            }else{
                $endUsecs = $runs.runs[-1].localBackupInfo.startTimeUsecs - 1
            }
        }else{
            break
        }
        foreach($run in $runs.runs){
            if(! $run.PSObject.Properties['isLocalSnapshotsDeleted'] -or $run.isLocalSnapshotsDeleted -ne $True){
                $runBytes = 0
                if($run.PSObject.Properties['originalBackupInfo']){
                    if($jobType -eq 'VMware'){
                        $runBytes = $vmbytes
                    }else{
                        $run.objects.originalBackupInfo.snapshotInfo.stats.logicalSizeBytes | %{ $runBytes += $_}
                    }
                    $runStartTimeUsecs = $run.originalBackupInfo.startTimeUsecs
                    $owner = $run.originClusterIdentifier.clusterName
                    if($owner -notin $remotes){
                        $remotes = @($remotes + $owner)
                    }
                }else{
                    if($jobType -eq 'VMware'){
                        $runBytes = $vmbytes
                    }else{
                        $run.objects.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes | %{ $runBytes += $_}
                    }
                    $runStartTimeUsecs = $run.localBackupInfo.startTimeUsecs
                    $owner = $cluster.name
                }
                if($runBytes -gt $maxRunBytes){
                    $maxRunBytes = $runBytes
                }
                if($owner -notin $sizingData[$policyName][$jobType].Keys){
                    $sizingData[$policyName][$jobType][$owner] = @{'total' = 0}
                }
                if($runStartTimeUsecs -lt $daysBackUsecs){
                    break
                }
            }
        }
    }
    if($jobName -notin $sizingData["$policyName"]["$jobType"]["$owner"].Keys){
        if($maxRunBytes -gt 0){
            if($jobType -in @('AD', 'Oracle', 'SQL')){
                $maxRunBytes = $maxRunBytes / 2
            }
            # Write-Host "    $([math]::Round($maxRunBytes / (1024 * 1024 * 1024 * 1024), 1))"
            $sizingData["$policyName"]["$jobType"]["$owner"]["$jobName"] = $maxRunBytes
            $sizingData["$policyName"]["$jobType"]["$owner"]['total'] += $maxRunBytes
        }
    }
}

foreach($view in $views.views){
    if($view.name -notin $protectedViews){
        if('unprotected' -notin $sizingData.Keys){
            $sizingData['unprotected'] = @{'View' = @{"$($cluster.name)" = @{'total' = 0}}}
        }
        $sizingData['unprotected']['View'][$cluster.name]['total'] += $view.stats.dataUsageStats.totalLogicalUsageBytes
    }
}

$dateString = (get-date).ToString('yyyy-MM-dd')
$fileName = "reverseSizingReport-SizingInfo-$($cluster.name)-$dateString.csv"
"""Owner"",""Job Type"",""Policy Name"",""Logical Size $unit"",""Workload Size TB""" | Out-File -FilePath $fileName -Encoding utf8

foreach($policyName in $sizingData.Keys){

    foreach($jobType in $sizingData["$policyName"].Keys){

        foreach($owner in $sizingData["$policyName"]["$jobType"].Keys){
 
            $total = toUnits ($sizingData["$policyName"]["$jobType"]["$owner"]['total'])

            $totalTB = [math]::Round($sizingData["$policyName"]["$jobType"]["$owner"]['total'] / (1000 * 1000 * 1000 * 1000), 2)
            """$owner"",""$jobType"",""$policyName"",""$total"",""$totalTB""" | Out-File -FilePath $fileName -Encoding utf8 -Append
        }
    }
}

# Cluster Info
$policyFileName = "reverseSizingReport-ClusterInfo-$($cluster.name)-$dateString.txt"

"Cluster Info:`n" | Out-File -FilePath $policyFileName
$clusterCapacityTiB = [math]::Round($cluster.stats.usagePerfStats.physicalCapacityBytes / (1024 * 1024 * 1024 * 1024), 2)
$clusterUsageTiB = [math]::Round($cluster.stats.usagePerfStats.totalPhysicalUsageBytes / (1024 * 1024 * 1024 * 1024), 2)
$clusterCapacityTB = [math]::Round($cluster.stats.usagePerfStats.physicalCapacityBytes / (1000 * 1000 * 1000 * 1000), 2)
$clusterUsageTB = [math]::Round($cluster.stats.usagePerfStats.totalPhysicalUsageBytes / (1000 * 1000 * 1000 * 1000), 2)
$ec21RequiredTB = [math]::Round($clusterUsageTB * 0.67, 2)
    "      Cluster Name: $($cluster.name)" | Out-File -FilePath $policyFileName -Append
    "             Total: $($clusterCapacityTiB) TiB ($($clusterCapacityTB) TB)" | Out-File -FilePath $policyFileName -Append
    "              Used: $($clusterUsageTiB) TiB ($($clusterUsageTB) TB)" | Out-File -FilePath $policyFileName -Append
    " Dedup Storage Req: $ec21RequiredTB TB (EC 2:1)" | Out-File -FilePath $policyFileName -Append
    "        Node Count: $($cluster.nodeCount)" | Out-File -FilePath $policyFileName -Append
    $nodes = api get nodes
    "    Product Models:" | Out-File -FilePath $policyFileName -Append
    foreach($node in $nodes){
        if($node.PSObject.Properties['productModel']){
            "                    $($node.productModel)" | Out-File -FilePath $policyFileName -Append
        }
    }

$sds = api get viewBoxes?fetchStats=true
"`n`nStorage Domains:`n" | Out-File -FilePath $policyFileName -Append
foreach($sd in $sds){
    $ec = '-'
    $numDataStripes = $sd.storagePolicy.erasureCodingInfo.numDataStripes
    $numCodedStripes = $sd[0].storagePolicy.erasureCodingInfo.numCodedStripes
    $ec = "$($numDataStripes):$($numCodedStripes)"
    if($ec -eq ":"){
        $ec = "RF"
    }
    $usage = toUnits $sd.stats.usagePerfStats.totalPhysicalUsageBytes
    "    $($sd.name) ($ec) $usage $unit" | Out-File -FilePath $policyFileName -Append
}

# Policy Info
"`n`nPolicy Info:`n" | Out-File -FilePath $policyFileName -Append
foreach($policy in $policies | Where-Object {$_.name -in $policyNames} | Sort-Object -Property name){
    "         Policy Name: $($policy.name)" | Out-File -FilePath $policyFileName -Append
    # base retention
    $baseRetention = $policy.backupPolicy.regular.retention
    $dataLock = ''
    if($baseRetention.PSObject.Properties['dataLockConfig'] -and $null -eq $baseRetention.dataLockConfig){
        $dataLock = ", datalock for {0} {1}" -f $baseRetention.dataLockConfig.duration, $baseRetention.dataLockConfig.unit
    }
    if($policy.PSObject.Properties['dataLock']){
        $dataLock = ", datalock for {0} {1}" -f $baseRetention.duration, $baseRetention.unit
    }       
    # incremental backup
    if($policy.backupPolicy.regular.PSObject.Properties['incremental']){
        $backupSchedule = $policy.backupPolicy.regular.incremental.schedule
        $punit = $backupSchedule.unit
        $unitPath = "{0}Schedule" -f $punit.Tolower().Substring(0,$($punit.Length - 1))
        if($punit -in $frequentSchedules){
            $frequency = $backupSchedule.$unitPath.frequency
            "  Incremental backup: Every {0} {1} (keep for {2} {3}{4})" -f $frequency, $punit, $baseRetention.duration, $baseRetention.unit, $dataLock | Out-File -FilePath $policyFileName -Append
        }else{
            if($punit -eq 'Weeks'){
                "  Incremental backup: Weekly on {0} (keep for {1} {2}{3})" -f $($backupSchedule.$unitPath.dayOfWeek -join ', '), $baseRetention.duration, $baseRetention.unit, $dataLock | Out-File -FilePath $policyFileName -Append
            }
            if($punit -eq 'Months'){
                "  Incremental backup: Monthly on the {0} {1} (keep for {2} {3}{4})" -f $backupSchedule.$unitPath.weekOfMonth, $backupSchedule.$unitPath.dayOfWeek[0], $baseRetention.duration, $baseRetention.unit, $dataLock | Out-File -FilePath $policyFileName -Append
            }
        }
    }

    # full backup
    if($policy.backupPolicy.regular.PSObject.Properties['full']){
        $backupSchedule = $policy.backupPolicy.regular.full.schedule
        $punit = $backupSchedule.unit
        $unitPath = "{0}Schedule" -f $punit.ToLower().subString(0,$($punit.Length - 1))
        if($punit -in $frequentSchedules){
            $frequency = $backupSchedule.$unitPath.frequency
            "         Full backup: Every {0} {1} (keep for {2} {3}" -f $frequency, $punit, $baseRetention.duration, $baseRetention.unit | Out-File -FilePath $policyFileName -Append
        }else{
            if($punit -eq 'Weeks'){
                "         Full backup: Weekly on {0} (keep for {1} {2})" -f $($backupSchedule.$unitPath.dayOfWeek -join ', '), $baseRetention.duration, $baseRetention.unit | Out-File -FilePath $policyFileName -Append
            }
            if($punit -eq 'Months'){
                "         Full backup: Monthly on the {0} {1} (keep for {2} {3})" -f $backupSchedule.$unitPath.weekOfMonth, $backupSchedule.$unitPath.dayOfWeek[0], $baseRetention.duration, $baseRetention.unit | Out-File -FilePath $policyFileName -Append
            }
            if($punit -eq 'ProtectOnce'){
                "         Full backup: Once (keep for {0} {1})" -f $baseRetention.duration, $baseRetention.unit  | Out-File -FilePath $policyFileName -Append
            }
        }
    }
    # extended retention
    if($policy.PSObject.Properties['extendedRetention'] -and $null -ne $policy.extendedRetention){
        "  Extended retention:" | Out-File -FilePath $policyFileName -Append
        foreach($extendedRetention in $policy.extendedRetention){
            "                      Every {0} {1} (keep for {2} {3})" -f $extendedRetention.schedule.frequency, $extendedRetention.schedule.unit, $extendedRetention.retention.duration, $extendedRetention.retention.unit | Out-File -FilePath $policyFileName -Append
        }
    }
    # log backup
    if($policy.backupPolicy.PSObject.Properties['log']){
        $logRetention = $policy.backupPolicy.log.retention
        $backupSchedule = $policy.backupPolicy.log.schedule
        $punit = $backupSchedule.unit
        $unitPath = "{0}Schedule" -f $punit.ToLower().subString(0,$($punit.Length - 1))
        $frequency = $backupSchedule.$unitPath.frequency
        "          Log backup: Every {0} {1} (keep for {2} {3})" -f $frequency, $punit, $logRetention.duration, $logRetention.unit | Out-File -FilePath $policyFileName -Append
    }
    # remote targets
    if($policy.PSObject.Properties['remoteTargetPolicy'] -and $null -ne $policy.remoteTargetPolicy){
        # replication targets
        if($policy.remoteTargetPolicy.PSObject.Properties['replicationTargets'] -and $null -ne $policy.remoteTargetPolicy.replicationTargets){
            "        Replicate To:" | Out-File -FilePath $policyFileName -Append
            foreach($replicationTarget in $policy.remoteTargetPolicy.replicationTargets){
                if($replicationTarget.targetType -eq 'RemoteCluster'){
                    $targetName = $replicationTarget.remoteTargetConfig.clusterName
                }else{
                    $targetName = $replicationTarget.targetType
                }
                $frequencyunit = $replicationTarget.schedule.unit
                if($frequencyunit -eq 'Runs'){
                    $frequencyunit = 'Run'
                    $frequency = 1
                }else{
                    $frequency = $replicationTarget.schedule.frequency
                }
                "                      {0}: Every {1} {2} (keep for {3} {4})" -f $targetName, $frequency, $frequencyunit, $replicationTarget.retention.duration, $replicationTarget.retention.unit | Out-File -FilePath $policyFileName -Append
            }
        }
        if($policy.remoteTargetPolicy.PSObject.Properties['archivalTargets'] -and $null -ne $policy.remoteTargetPolicy.archivalTargets -and @($policy.remoteTargetPolicy.archivalTargets).Count -gt 0){
            "          Archive To:" | Out-File -FilePath $policyFileName -Append
            foreach($archivalTarget in $policy.remoteTargetPolicy.archivalTargets){
                $frequencyunit = $archivalTarget.schedule.unit
                if($frequencyunit -eq 'Runs'){
                    $frequencyunit = 'Run'
                    $frequency = 1
                }else{
                    $frequency = $archivalTarget.schedule.frequency
                }
                "                      {0}: Every {1} {2} (keep for {3} {4})" -f $archivalTarget.targetName, $frequency, $frequencyunit, $archivalTarget.retention.duration, $archivalTarget.retention.unit | Out-File -FilePath $policyFileName -Append
            }
        }
    }
    "`n" | Out-File -FilePath $policyFileName -Append
}

if($remotes.Count -gt 0){
    Write-Host "`nPlease also run this script on the following cluster(s): $(@($remotes | Sort-Object) -join ', ')" -ForegroundColor Yellow
}

"`n  Sizing Info saved to: {0}" -f $fileName
" cluster Info saved to: {0}`n" -f $policyFileName
