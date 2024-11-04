# version: 2024-10-23

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
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][int]$growthDays = 7,
    [Parameter()][switch]$skipDeleted,
    [Parameter()][ValidateSet('MiB','GiB','TiB','MB','GB','TB')][string]$unit = 'GiB',
    [Parameter()][switch]$secondFormat,
    [Parameter()][switch]$consolidateDBs,
    [Parameter()][switch]$dbg,
    [Parameter()][switch]$includeArchives,
    [Parameter()][string]$outfileName
)

$scriptversion = '2024-10-23 (PowerShell)'

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024; 'KB' = 1000; 'MB' = 1000 * 1000; 'GB' = 1000 * 1000 * 1000; 'TB' = 1000 * 1000 * 1000 * 1000}

function toUnits($val){
    return [math]::Round($val/$conversion[$unit], 1)
}

$dateString = (get-date).ToString('yyyy-MM-dd-HH-mm')
$monthString = (get-date).ToString('yyyy-MM')
if(!$outfileName){
    $outfileName = "storagePerObjectReport-$dateString.csv"
}
$clusterStatsFileName = "$($outfileName.Substring(0,$outfileName.Length-4))-clusterstats.csv"
$logFileName = $outfileName -replace ".csv", ".log"

# log function
function output($msg, [switch]$warn, [switch]$quiet){
    if(!$quiet){
        if($warn){
            Write-Host $msg -ForegroundColor Yellow
        }else{
            Write-Host $msg
        }
    }
    $msg | Out-File -FilePath $logFileName -Append
}

# log command line parameters
Get-Date | Out-File $logFileName
"command line parameters:" | Out-File $logFileName -Append
$CommandName = $PSCmdlet.MyInvocation.InvocationName;
$ParameterList = (Get-Command -Name $CommandName).Parameters;
foreach ($Parameter in $ParameterList) {
    Get-Variable -Name $Parameter.Values.Name -ErrorAction SilentlyContinue | Where-Object name -ne 'password' | Out-File $logFileName -Append
}

# headings
"""Cluster Name"",""Origin"",""Stats Age (Days)"",""Protection Group"",""Tenant"",""Storage Domain ID"",""Storage Domain Name"",""Environment"",""Source Name"",""Object Name"",""Front End Allocated $unit"",""Front End Used $unit"",""$unit Stored (Before Reduction)"",""$unit Stored (After Reduction)"",""$unit Stored (After Reduction and Resiliency)"",""Reduction Ratio"",""$unit Change Last $growthDays Days (After Reduction and Resiliency)"",""Snapshots"",""Log Backups"",""Oldest Backup"",""Newest Backup"",""Newest DataLock Expiry"",""Archive Count"",""Oldest Archive"",""$unit Archived"",""$unit per Archive Target"",""Description"",""VM Tags""" | Out-File -FilePath $outfileName # -Encoding utf8
"""Cluster Name"",""Total Used $unit"",""BookKeeper Used $unit"",""Total Unaccounted Usage $unit"",""Total Unaccounted Percent"",""Garbage $unit"",""Garbage Percent"",""Other Unaccounted $unit"",""Other Unaccounted Percent"",""Reduction Ratio"",""All Objects Front End Size $unit"",""All Objects Stored (After Reduction) $unit"",""All Objects Stored (After Reduction and Resiliency) $unit"",""Storage Variance Factor"",""Script Version"",""Cluster Software Version""" | Out-File -FilePath $clusterStatsFileName

if($secondFormat){
    $outfile2 = "customFormat2-storagePerObjectReport-$dateString.csv"
    """Cluster Name"",""Month"",""Object Name"",""Description"",""$unit Written plus Resiliency""" | Out-File -FilePath $outfile2
}

function getCloudStats(){
    $cloudStats = $null
    $vaults = api get vaults?includeFortKnoxVault=true
    if($vaults){
        $nowMsecs = [Int64]((dateToUsecs) / 1000)
        $cloudStart = $cluster.createdTimeMsecs
        $cloudStatURL = "reports/dataTransferToVaults?endTimeMsecs=$nowMsecs&startTimeMsecs=$cloudStart"
        foreach($vault in $vaults){
            $cloudStatURL += "&vaultIds=$($vault.id)"
        }
        output "  getting external target stats..."
        $cloudStats = api get $cloudStatURL
    }
    return $cloudStats
}

function getConsumerStats($consumerType, $msecsBeforeCurrentTimeToCompare){
    $cookie = ''
    $consumerStats = @{'statsList'= @()}
    while($True){
        $theseStats = api get "stats/consumers?consumerType=$consumerType&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)&cookie=$cookie"
        if($theseStats -and $theseStats.PSObject.Properties['statsList']){
            $consumerStats['statsList'] = @($consumerStats['statsList'] + $theseStats.statsList)
        }
        if($theseStats -and $theseStats.PSObject.Properties['cookie']){
            $cookie = $theseStats.cookie
        }else{
            $cookie = ''
        }
        if($cookie -eq ''){
            break
        }
    }
    return $consumerStats
}

function reportStorage(){
    $viewHistory = @{}
    $cluster = api get "cluster?fetchStats=true"
    output "`n$($cluster.name)"
    $clusterUsed = 0
    $sumObjectsUsed = 0
    $sumObjectsWritten = 0
    $sumObjectsWrittenWithResiliency = 0

    try{
        $clusterReduction = [math]::Round($cluster.stats.usagePerfStats.dataInBytes / $cluster.stats.usagePerfStats.dataInBytesAfterReduction, 1)
        $clusterUsed = toUnits $cluster.stats.usagePerfStats.totalPhysicalUsageBytes
    }catch{
        $clusterReduction = 1
    }
    if($includeArchives){
        $cloudStats = getCloudStats
    }
    
    if($skipDeleted){
        $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true&useCachedData=true"
    }else{
        $jobs = api get -v2 "data-protect/protection-groups?includeTenants=true&useCachedData=true"
    }
    
    $storageDomains = api get viewBoxes
    
    $sourceNames = @{}
    
    $growthDaysUsecs = $growthDays * 24 * 60 * 60 * 1000000
    $nowUsecs = dateToUsecs
    $msecsBeforeCurrentTimeToCompare = $growthDays * 24 * 60 * 60 * 1000

    # local backup stats
    $localStats = getConsumerStats 'kProtectionRuns' $msecsBeforeCurrentTimeToCompare

    # replica backup stats
    $replicaStats = getConsumerStats 'kReplicationRuns' $msecsBeforeCurrentTimeToCompare

    # viewRunStats
    $viewRunStats = getConsumerStats 'kViewProtectionRuns' $msecsBeforeCurrentTimeToCompare

    $viewJobAltStats = @{}

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $v1JobId = ($job.id -split ':')[2]
        $statsAge = '-'
        $origin = 'local'
        if($job.isActive -ne $True){
            $origin = 'replica'
        }
        if($job.environment -in @('kVMware', 'kAD') -or ($job.environment -eq 'kPhysical' -and $job.physicalParams.protectionType -eq 'kVolume')){
            if($job.environment -eq 'kAD'){
                $entityType = 'kPhysical'
            }else{
                $entityType = $job.environment
            }
            $vmsearch = api get "/searchvms?allUnderHierarchy=true&entityTypes=$($entityType)&jobIds=$($v1JobId)&vmName=$($job.name)"
        }
        if($job.environment -notin @('kView')){
            output "  $($job.name)"
            $tenant = $job.permissions.name
            # get resiliency factor
            $resiliencyFactor = 1
            if($job.PSObject.Properties['storageDomainId']){
                $sd = $storageDomains | Where-Object id -eq $job.storageDomainId
                if($sd){
                    $sdName = $sd.name
                    if($sd.storagePolicy.PSObject.Properties['erasureCodingInfo']){
                        $r = $sd.storagePolicy.erasureCodingInfo
                        $resiliencyFactor = ($r.numDataStripes + $r.numCodedStripes) / $r.numDataStripes
                    }else{
                        if($sd.storagePolicy.numFailuresTolerated -eq 0){
                            $resiliencyFactor = 1
                        }else{
                            $resiliencyFactor = 2
                        }
                    }
                }else{
                    $sdName = 'DirectArchive'
                }
            }
            $objects = @{}
            
            $jobObjGrowth = 0
            $jobGrowth = 0
    
            # job stats
            if($job.isActive -eq $True){
                $stats = $localStats
            }else{
                $stats = $replicaStats
            }
            if($job.environment -eq 'kView'){
                $stats = $viewRunStats
            }
            if($stats){
                $thisStat = $stats.statsList | Where-Object {$_.id -eq $v1JobId -or $_.name -eq $job.name}
            }
            if($stats -and $thisStat){
                try{
                    $statsTimeUsecs = $thisStat[0].stats.dataWrittenBytesTimestampUsec
                    if($statsTimeUsecs -gt 0){
                        $statsAge = [math]::Round(($nowUsecs - $statsTimeUsecs) / 86400000000, 0)
                    }else{
                        $statsAge = '-'
                    }
                    $dataIn = $thisStat[0].stats.dataInBytes
                    $dataInAfterDedup = $thisStat[0].stats.dataInBytesAfterDedup
                    $jobWritten = $thisStat[0].stats.dataWrittenBytes
                    $storageConsumedBytes = $thisStat[0].stats.storageConsumedBytes
                }catch{
                    $dataIn = 0
                    $dataInAfterDedup = 0
                    $jobWritten = 0
                    $storageConsumedBytes = 0
                }
                try{
                    $storageConsumedBytesPrev = $thisStat[0].stats.storageConsumedBytesPrev
                }catch{
                    $storageConsumedBytesPrev = 0
                }
                
                if($storageConsumedBytes -gt 0 -and $storageConsumedBytesPrev -gt 0 -and $resiliencyFactor -gt 0){
                    $jobGrowth = ($storageConsumedBytes - $storageConsumedBytesPrev) / $resiliencyFactor
                }                
                if($dataInAfterDedup -gt 0 -and $jobWritten -gt 0){
                    $jobReduction = [math]::Round(($dataIn / $dataInAfterDedup) * ($dataInAfterDedup / $jobWritten), 1)
                }else{
                    $jobReduction = 1
                }
            }else{
                $jobWritten = 0
                $jobReduction = $clusterReduction
            }
    
            # runs
            $archiveCount = 0
            $oldestArchive = '-'
            $endUsecs = $nowUsecs
            $lastDataLock = '-'
            $lastRunId = 0
            while($True){
                if($dbg){
                    output "    getting runs"
                }
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true"
                if($lastRunId -ne 0){
                    $runs.runs = $runs.runs | Where-Object {$_.id -lt $lastRunId}
                }
                foreach($run in $runs.runs){
                    if($run.isLocalSnapshotsDeleted -ne $True){
                        $snap = $null
                        if($run.PSObject.Properties['localBackupInfo']){
                            $runInfo = $run.localBackupInfo
                        }elseif($run.PSObject.Properties['originalBackupInfo']){
                            $runInfo = $run.originalBackupInfo
                        }else{
                            $runInfo = $run.archivalInfo.archivalTargetResults[0]
                        }
                        if($lastDataLock -eq '-' -and $runInfo.PSObject.Properties['dataLockConstraints'] -and $runInfo.dataLockConstraints.PSObject.Properties['expiryTimeUsecs'] -and $runInfo.dataLockConstraints.expiryTimeUsecs -gt 0){
                            if($runInfo.dataLockConstraints.expiryTimeUsecs -gt $nowUsecs){
                                $lastDataLock = usecsToDate $runInfo.dataLockConstraints.expiryTimeUsecs
                            }
                        }
                        foreach($object in $run.objects | Where-Object {$_.object.environment -ne $job.environment}){
                            $sourceNames["$($object.object.id)"] = $object.object.name
                        }
                        foreach($object in $run.objects){
                            $objId = "$($object.object.id)"
                            if($object.PSObject.Properties['localSnapshotInfo']){
                                $snap = $object.localSnapshotInfo
                                $runType = $run.localBackupInfo.runType
                            }else{
                                $snap = $object.originalBackupInfo
                                $runType = $run.originalBackupInfo.runType
                            }
                            # CAD
                            if(! $snap){
                                if($object.PSObject.Properties['archivalInfo']){
                                    $archivalInfo = $object.archivalInfo.archivalTargetResults[0]
                                }
                            }
                            if($objId -notin $objects.Keys -and !($job.environment -eq 'kAD' -and $object.object.environment -eq 'kAD') -and !($job.environment -in @('kSQL', 'kOracle', 'kExchange') -and $object.object.objectType -eq 'kHost')){
                                $objects[$objId] = @{}
                                $objects[$objId]['name'] = $object.object.name
                                $objects[$objId]['parentObject'] = $false
                                $objects[$objId]['alloc'] = 0
                                $objects[$objId]['logical'] = 0
                                $objects[$objId]['fetb'] = 0
                                $objects[$objId]['archiveLogical'] = 0
                                $objects[$objId]['bytesRead'] = 0
                                $objects[$objId]['archiveBytesRead'] = 0
                                $objects[$objId]['growth'] = 0
                                $objects[$objId]['numSnaps'] = 0
                                $objects[$objId]['numLogs'] = 0
                                $objects[$objId]['vmTags'] = ''
                                if(! $snap){
                                    $objects[$objId]['newestBackup'] = $archivalInfo.startTimeUsecs
                                    $objects[$objId]['oldestBackup'] = $archivalInfo.startTimeUsecs
                                }else{
                                    $objects[$objId]['newestBackup'] = $snap.snapshotInfo.startTimeUsecs
                                    $objects[$objId]['oldestBackup'] = $snap.snapshotInfo.startTimeUsecs
                                }
                                $objects[$objId]['lastDataLock'] = $lastDataLock
                                if($object.object.PSObject.Properties['sourceId']){
                                    $objects[$objId]['sourceId'] = $object.object.sourceId
                                }
                                if($snap -and ! $snap.snapshotInfo.stats.PSObject.Properties['logicalSizeBytes']){
                                    if($dbg){
                                        output "    getting source"
                                    }
                                    $csource = api get "protectionSources?id=$objId&useCachedData=true" -quiet
                                    if( $csource.protectedSourcesSummary.Count -gt 0){
                                        $objects[$objId]['logical'] = $csource.protectedSourcesSummary[0].totalLogicalSize
                                        $objects[$objId]['alloc'] = $csource.protectedSourcesSummary[0].totalLogicalSize
                                    }else{
                                        $objects[$objId]['logical'] = 0
                                        $objects[$objId]['alloc'] = 0
                                    }
                                }else{
                                    $objects[$objId]['logical'] = $snap.snapshotInfo.stats.logicalSizeBytes
                                    $objects[$objId]['alloc'] = $snap.snapshotInfo.stats.logicalSizeBytes
                                }
                            }
                            if($objId -in $objects.Keys -and $objects[$objId]['fetb'] -eq 0 -and ($job.environment -in @('kVMware', 'kAD') -or ($job.environment -eq 'kPhysical' -and $job.physicalParams.protectionType -eq 'kVolume'))){
                                if($dbg){
                                    Write-Host "    getting fetb"
                                }
                                $vms = $vmsearch.vms | Where-Object {$_.vmDocument.objectName -eq $object.object.name}
                                
                                if($vms){
                                    if($job.environment -eq 'kVMware'){
                                        $vmbytes = $vms[0].vmDocument.objectId.entity.vmwareEntity.frontEndSizeInfo.sizeBytes
                                    }else{
                                        $vmbytes = $vms[0].vmDocument.objectId.entity.sizeInfo.value.sourceDataSizeBytes
                                    }
                                    if($vmbytes -gt 0){
                                        $objects[$objId]['logical'] = $vmbytes
                                        $objects[$objId]['fetb'] = $vmbytes
                                    }
                                    if($job.environment -eq 'kVMware'){
                                        $tagAttrs = $vms[0].vmDocument.attributeMap | Where-Object xKey -match 'VMware_tag'
                                        if($tagAttrs){
                                            $objects[$objId]['vmTags'] = $tagAttrs.xValue -join ';'
                                        }
                                    }
                                }
                            }
                            if($snap -and $objId -in $objects.Keys -and $snap.snapshotInfo.stats.PSObject.Properties['logicalSizeBytes'] -and $snap.snapshotInfo.stats.logicalSizeBytes -gt $objects[$objId]['logical']){
                                if($objects[$objId]['logical'] -eq 0 -or ($job.environment -notin @('kVMware', 'kAD') -and ($job.environment -ne 'kPhysical' -and $job.physicalParams.protectionType -ne 'kVolume'))){
                                    $objects[$objId]['logical'] = $snap.snapshotInfo.stats.logicalSizeBytes
                                }
                            }
                            if($job.environment -eq 'kVMware' -and $snap.snapshotInfo.stats.logicalSizeBytes -lt $objects[$objId]['logical'] -and $snap.snapshotInfo.stats.logicalSizeBytes -gt 0){
                                $objects[$objId]['logical'] = $snap.snapshotInfo.stats.logicalSizeBytes
                            }
                            if(!$snap -and $objId -in $objects.Keys -and $archivalInfo.stats.PSObject.Properties['logicalSizeBytes'] -and $archivalInfo.stats.logicalSizeBytes -gt $objects[$objId]['archiveLogical']){ #  -and $objects[$objId]['archiveLogical'] -gt 0){
                                $objects[$objId]['archiveLogical'] = $archivalInfo.stats.logicalSizeBytes
                            }
                            if($objId -in $objects.Keys){
                                if($runType -eq 'kLog'){
                                    $objects[$objId]['numLogs'] += 1
                                }else{
                                    $objects[$objId]['numSnaps'] += 1
                                }
                                if($snap){
                                    $objects[$objId]['lastDataLock'] = $lastDataLock
                                    $objects[$objId]['oldestBackup'] = $snap.snapshotInfo.startTimeUsecs
                                    $objects[$objId]['bytesRead'] += $snap.snapshotInfo.stats.bytesRead
                                    if($snap.snapshotInfo.startTimeUsecs -gt $growthDaysUsecs){
                                        $objects[$objId]['growth'] += $snap.snapshotInfo.stats.bytesRead
                                        $jobObjGrowth += $snap.snapshotInfo.stats.bytesRead
                                    }
                                }else{
                                    $objects[$objId]['oldestBackup'] = $archivalInfo.startTimeUsecs
                                    $objects[$objId]['archiveBytesRead'] += $archivalInfo.stats.bytesRead
                                }                                
                            }
                        }
                    }
                    if($run.PSObject.Properties['archivalInfo'] -and $run.archivalInfo.PSObject.Properties['archivalTargetResults']){
                        foreach($archiveResult in $run.archivalInfo.archivalTargetResults){
                            if($archiveResult.status -eq 'Succeeded'){
                                $archiveCount += 1
                                $oldestArchive = usecsToDate (($run.id -split ':')[-1])
                            }
                        }
                    }
                }
                if(!$runs.runs -or $runs.runs.Count -eq 0 -or $runs.runs[-1].id -eq $lastRunId){
                    break
                }else{
                    $lastRunId = $runs.runs[-1].id
                    if($runs.runs[-1].PSObject.Properties['localBackupInfo']){
                        $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs
                    }elseif($runs.runs[-1].PSObject.Properties['originalBackupInfo']){
                        $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs
                    }else{
                        $endUsecs = $runs.runs[-1].archivalInfo.archivalTargetResults[0].endTimeUsecs
                    }
                }
            }

            # consolidate DBs
            $parentObjects = @{}
            if($consolidateDBs){
                foreach($objId in $objects.Keys){
                    $thisObject = $objects[$objId]
                    if($job.environment -in @('kOracle', 'kSQL') -and $thisObject['parentObject'] -eq $false){
                        $sourceName = ''
                        if('sourceId' -in $thisObject.Keys){
                            if("$($thisObject['sourceId'])" -in $sourceNames.Keys){
                                $sourceName = $sourceNames["$($thisObject['sourceId'])"]
                            }else{
                                if($dbg){
                                    output "    getting source (2)"
                                }
                                $source = api get "protectionSources?id=$($thisObject['sourceId'])&excludeTypes=kFolder,kDatacenter,kComputeResource,kClusterComputeResource,kResourcePool,kDatastore,kHostSystem,kVirtualMachine,kVirtualApp,kStandaloneHost,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&useCachedData=true" -quiet
                                if($source -and $source.PSObject.Properties['protectionSource']){
                                    $sourceName = $source.protectionSource.name
                                    $sourceNames["$($thisObject['sourceId'])"] = $sourceName
                                }
                            }
                            if($thisObject['sourceId'] -notin $parentObjects.Keys){
                                
                                $parentObjects[$thisObject['sourceId']] = @{}
                                $parentObjects[$thisObject['sourceId']]['name'] = $sourceName
                                $parentObjects[$thisObject['sourceId']]['parentObject'] = $True
                                $parentObjects[$thisObject['sourceId']]['alloc'] = $thisObject['alloc']
                                $parentObjects[$thisObject['sourceId']]['logical'] = $thisObject['logical']
                                $parentObjects[$thisObject['sourceId']]['archiveLogical'] = $thisObject['archiveLogical']
                                $parentObjects[$thisObject['sourceId']]['bytesRead'] = $thisObject['bytesRead']
                                $parentObjects[$thisObject['sourceId']]['archiveBytesRead'] = $thisObject['archiveBytesRead']
                                $parentObjects[$thisObject['sourceId']]['growth'] = $thisObject['growth']
                                $parentObjects[$thisObject['sourceId']]['numSnaps'] = $thisObject['numSnaps']
                                $parentObjects[$thisObject['sourceId']]['numLogs'] = $thisObject['numLogs']
                                $parentObjects[$thisObject['sourceId']]['newestBackup'] = $thisObject['newestBackup']
                                $parentObjects[$thisObject['sourceId']]['oldestBackup'] = $thisObject['oldestBackup']
                            }else{
                                
                                $parentObjects[$thisObject['sourceId']]['alloc'] += $thisObject['alloc']
                                $parentObjects[$thisObject['sourceId']]['logical'] += $thisObject['logical']
                                $parentObjects[$thisObject['sourceId']]['archiveLogical'] += $thisObject['archiveLogical']
                                $parentObjects[$thisObject['sourceId']]['bytesRead'] += $thisObject['bytesRead']
                                $parentObjects[$thisObject['sourceId']]['archiveBytesRead'] += $thisObject['archiveBytesRead']
                                $parentObjects[$thisObject['sourceId']]['growth'] += $thisObject['growth']
                                if($thisObject['newestBackup'] -gt $parentObjects[$thisObject['sourceId']]['newestBackup']){
                                    $parentObjects[$thisObject['sourceId']]['newestBackup'] = $thisObject['newestBackup']
                                }
                                if($thisObject['oldestBackup'] -lt $parentObjects[$thisObject['sourceId']]['oldestBackup']){
                                    $parentObjects[$thisObject['sourceId']]['oldestBackup'] = $thisObject['oldestBackup']
                                }
                                if($thisObject['numSnaps'] -gt $parentObjects[$thisObject['sourceId']]['numSnaps']){
                                    $parentObjects[$thisObject['sourceId']]['numSnaps'] = $thisObject['numSnaps']
                                }
                                if($thisObject['numLogs'] -gt $parentObjects[$thisObject['sourceId']]['numLogs']){
                                    $parentObjects[$thisObject['sourceId']]['numLogs'] = $thisObject['numLogs']
                                }
                            }
                        }
                    }
                }
            }
            ForEach ($Key in $parentObjects.Keys) {
                $objects[$Key] = $parentObjects[$Key]
            }

            # process output
            $isCad = $false
            $jobFESize = 0
            foreach($objId in $objects.Keys){
                $thisObject = $objects[$objId]
                if($consolidateDBs -and $job.environment -in @('kSQL', 'kOracle') -and $thisObject['parentObject'] -eq $false){
                    continue
                }
                $jobFESize += $thisObject['logical']
                $jobFESize += $thisObject['bytesRead']
                if($thisObject['archiveLogical'] -gt 0){
                    $jobFESize += $thisObject['archiveLogical']
                    $jobFESize += $thisObject['archiveBytesRead']
                    $isCad = $True
                }
            }
            foreach($objId in $objects.Keys | Sort-Object){
                $thisObject = $objects[$objId]
                if($consolidateDBs -and $job.environment -in @('kSQL', 'kOracle') -and $thisObject['parentObject'] -eq $false){
                    continue
                }
                $objFESize = toUnits $thisObject['logical']

                if($thisObject['archiveLogical'] -gt 0){
                    $objFESize = toUnits $thisObject['archiveLogical']
                }
                if($jobReduction -gt 0){
                    $objGrowth = toUnits ($thisObject['growth'] / $jobReduction)
                }
                
                if($jobObjGrowth -ne 0){
                    $objGrowth = toUnits ($jobGrowth * $thisObject['growth'] / $jobObjGrowth)
                }
                $objGrowth = $objGrowth * $resiliencyFactor
                if($jobFESize -gt 0){
                    $objWeight = ($thisObject['logical'] + $thisObject['bytesRead']) / $jobFESize
                    if($thisObject['archiveLogical'] -gt 0){
                        $objWeight = ($thisObject['archiveLogical'] + $thisObject['archiveBytesRead']) / $jobFESize
                    }
                }else{
                    $objWeight = 0
                }
                if($jobWritten -gt 0){
                    $objWritten = $objWeight * $jobWritten
                }elseif($jobReduction -gt 0){
                    $objWritten = [math]::Round($objFESize / $jobReduction, 1)
                }else{
                    $objWritten = 0
                }
                if($dataIn -gt 0){
                    $objDataIn = [math]::Round($objWeight * $dataIn, 1)
                }elseif($jobReduction -gt 0){
                    $objDataIn = [math]::Round($objFESize / $jobReduction, 1)
                }else{
                    $objDataIn = 0
                }
                $objWrittenWithResiliency = $objWritten * $resiliencyFactor
                $sourceName = ''
                if('sourceId' -in $thisObject.Keys){
                    if("$($thisObject['sourceId'])" -in $sourceNames.Keys){
                        $sourceName = $sourceNames["$($thisObject['sourceId'])"]
                    }else{
                        if($dbg){
                            output "    getting source (3)"
                        }
                        $source = api get "protectionSources?id=$($thisObject['sourceId'])&excludeTypes=kFolder,kDatacenter,kComputeResource,kClusterComputeResource,kResourcePool,kDatastore,kHostSystem,kVirtualMachine,kVirtualApp,kStandaloneHost,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&useCachedData=true" -quiet
                        if($source -and $source.PSObject.Properties['protectionSource']){
                            $sourceName = $source.protectionSource.name
                            $sourceNames["$($thisObject['sourceId'])"] = $sourceName
                        }
                    }
                }else{
                    $sourceName = $thisObject['name']
                }
                # archive Stats
                $totalArchived = 0
                $vaultStats = ''
                if($cloudStats){
                    foreach($vaultSummary in $cloudStats.dataTransferSummary){
                        foreach($cloudJob in $vaultSummary.dataTransferPerProtectionJob){
                            if($cloudJob.protectionJobName -eq $job.name){
                                if($cloudJob.storageConsumed -gt 0){
                                    $totalArchived += ($objWeight * $cloudJob.storageConsumed)
                                    $vaultStats += "[$($vaultSummary.vaultName)]$(toUnits ($objWeight * $cloudJob.storageConsumed)) "
                                    if($isCad -eq $True){
                                        $jobReduction = [math]::Round($jobFESize / $cloudJob.storageConsumed, 1)
                                    }
                                }
                            }
                        }
                    }
                }
                $fqObjectName = $thisObject['name']
                if($thisObject['name'] -ne $sourceName){
                    $fqObjectName = "$($sourceName)/$($thisObject['name'])" -replace '//', '/'
                }
                $alloc = toUnits $thisObject['logical']
                if($job.environment -in @('kVMware', 'kAD') -or ($job.environment -eq 'kPhysical' -and $job.physicalParams.protectionType -eq 'kVolume')){
                    $alloc = toUnits $thisObject['alloc']
                }
                $sumObjectsUsed += $thisObject['logical']
                $sumObjectsWritten += $objWritten
                $sumObjectsWrittenWithResiliency += $objWrittenWithResiliency
                if($alloc -eq 0){
                    $alloc = $objFESize
                }

                """$($cluster.name)"",""$origin"",""$statsAge"",""$($job.name)"",""$tenant"",""$($job.storageDomainId)"",""$sdName"",""$($job.environment)"",""$sourceName"",""$($thisObject['name'])"",""$alloc"",""$objFESize"",""$(toUnits $objDataIn)"",""$(toUnits $objWritten)"",""$(toUnits $objWrittenWithResiliency)"",""$jobReduction"",""$objGrowth"",""$($thisObject['numSnaps'])"",""$($thisObject['numLogs'])"",""$(usecsToDate $thisObject['oldestBackup'])"",""$(usecsToDate $thisObject['newestBackup'])"",""$($thisObject['lastDataLock'])"",""$archiveCount"",""$oldestArchive"",""$(toUnits $totalArchived)"",""$vaultStats"",""$($job.description)"",""$($thisObject['vmTags'])""" | Out-File -FilePath $outfileName -Append
                if($secondFormat){
                    """$($cluster.name)"",""$monthString"",""$fqObjectName"",""$($job.description)"",""$(toUnits $objWrittenWithResiliency)""" | Out-File -FilePath $outfile2 -Append
                }
            }
        }elseif($job.environment -in @('kView')){
            $stats = $viewRunStats
            if($stats){    
                $thisStat = $stats.statsList | Where-Object {$_.id -eq $v1JobId}
            }
            $endUsecs = $nowUsecs
            $lastDataLock = '-'
            $lastRunId = 0
            while($True){
                if($dbg){
                    output "    getting runs"
                }
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true"
                if($lastRunId -ne 0){
                    $runs.runs = $runs.runs | Where-Object {$_.id -lt $lastRunId}
                }
                foreach($run in $runs.runs){
                    if($run.isLocalSnapshotsDeleted -ne $True){
                        if($run.PSObject.Properties['localBackupInfo']){
                            $runInfo = $run.localBackupInfo
                        }elseif($run.PSObject.Properties['originalBackupInfo']){
                            $runInfo = $run.originalBackupInfo
                        }else{
                            $runInfo = $run.archivalInfo.archivalTargetResults[0]
                        }
                        if($lastDataLock -eq '-' -and $runInfo.PSObject.Properties['dataLockConstraints'] -and $runInfo.dataLockConstraints.PSObject.Properties['expiryTimeUsecs'] -and $runInfo.dataLockConstraints.expiryTimeUsecs -gt 0){
                            if($runInfo.dataLockConstraints.expiryTimeUsecs -gt $nowUsecs){
                                $lastDataLock = usecsToDate $runInfo.dataLockConstraints.expiryTimeUsecs
                            }
                        }
                        foreach($object in $run.objects){
                            if($object.PSObject.Properties['localSnapshotInfo']){
                                $snap = $object.localSnapshotInfo
                            }else{
                                $snap = $object.originalBackupInfo
                            }
                            if($object.object.name -notin $viewHistory.Keys){
                                $viewHistory[$object.object.name] = @{}
                                $viewHistory[$object.object.name]['stats'] = $thisStat
                                $viewHistory[$object.object.name]['numSnaps'] = 0
                                $viewHistory[$object.object.name]['numLogs'] = 0
                                if($snap){
                                    $viewHistory[$object.object.name]['newestBackup'] = usecsToDate $snap.snapshotInfo.startTimeUsecs
                                    $viewHistory[$object.object.name]['oldestBackup'] = usecsToDate $snap.snapshotInfo.startTimeUsecs
                                }
                                $viewHistory[$object.object.name]['archiveCount'] = 0
                                $viewHistory[$object.object.name]['oldestArchive'] = '-'
                                $viewHistory[$object.object.name]['lastDataLock'] = $lastDataLock
                            }
                            if($snap){
                                $viewHistory[$object.object.name]['oldestBackup'] = usecsToDate $snap.snapshotInfo.startTimeUsecs
                                $viewHistory[$object.object.name]['numSnaps'] += 1
                            }
                            $viewHistory[$object.object.name]['lastDataLock'] = $lastDataLock
                        }
                    }
                    if($run.PSObject.Properties['archivalInfo'] -and $run.archivalInfo.PSObject.Properties['archivalTargetResults']){
                        foreach($archiveResult in $run.archivalInfo.archivalTargetResults){
                            if($archiveResult.status -eq 'Succeeded'){
                                foreach($object in $run.objects){
                                    if($object.object.name -notin $viewHistory.Keys){
                                        $viewHistory[$object.object.name] = @{}
                                        $viewHistory[$object.object.name]['stats'] = $thisStat
                                        $viewHistory[$object.object.name]['numSnaps'] = 0
                                        $viewHistory[$object.object.name]['numLogs'] = 0
                                        $viewHistory[$object.object.name]['newestBackup'] = $null
                                        $viewHistory[$object.object.name]['oldestBackup'] = $null
                                        $viewHistory[$object.object.name]['archiveCount'] = 0
                                        $viewHistory[$object.object.name]['oldestArchive'] = '-'
                                        $viewHistory[$object.object.name]['lastDataLock'] = $null
                                    }
                                }
                                $viewHistory[$object.object.name]['archiveCount'] += 1
                                $viewHistory[$object.object.name]['oldestArchive'] = usecsToDate (($run.id -split ':')[-1])
                            }
                        }
                    }
                }
                if(!$runs.runs -or $runs.runs.Count -eq 0 -or $runs.runs[-1].id -eq $lastRunId){
                    break
                }else{
                    $lastRunId = $runs.runs[-1].id
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
    
    # views
    $views = api get -v2 "file-services/views?maxCount=2000&includeTenants=true&includeStats=true&includeProtectionGroups=true&includeInactive=true"
    $stats = api get "stats/consumers?msecsBeforeCurrentTimeToCompare=$msecsBeforeCurrentTimeToCompare&consumerType=kViews"
    $viewJobStats = @{}
    
    # build total job FE sizes
    foreach($view in $views.views){
        try{
            $jobName = $view.viewProtection.protectionGroups[-1].groupName
            if($view.PSObject.Properties['stats']){
                $viewStats = $view.stats.dataUsageStats
            }else{
                continue
            }
            if($jobName -notin $viewJobAltStats.Keys){
                $viewJobAltStats[$jobName] = @{"totalConsumed" = 0}
            }
            $viewJobAltStats[$jobName]["totalConsumed"] += $viewStats.storageConsumedBytes
        }catch{

        }
    }
    
    foreach($view in $views.views){
        $origin = 'local'
        try{
            $jobName = $view.viewProtection.protectionGroups[-1].groupName
            $thisJob = $jobs.protectionGroups | Where-Object {$_.name -eq $jobName}
            if($thisJob.environment -eq "kRemoteAdapter"){
                continue
            }
            if($thisJob){
                if($thisJob.isActive -ne $True){
                    $origin = 'replica'
                }
            }
            if($jobName -notin $viewJobStats.Keys){
                $viewJobStats[$jobName] = $viewHistory[$view.name]['stats']
            }

        }catch{
            $jobName = '-'
        }
        if($view.PSObject.Properties['stats']){
            $viewStats = $view.stats.dataUsageStats
        }else{
            continue
        }
        
        $statsAge = '-'
        $numSnaps = 0
        $numLogs = 0
        $oldestBackup = '-'
        $newestBackup = '-'
        $archiveCount = 0
        $oldestArchive = '-'
        $lastDataLock = '-'
        if($jobName -ne '-'){
            if($view.name -in $viewHistory.Keys){
                $newestBackup = $viewHistory[$view.name]['newestBackup']
                $oldestBackup = $viewHistory[$view.name]['oldestBackup']
                $numSnaps = $viewHistory[$view.name]['numSnaps']
                $oldestArchive = $viewHistory[$view.name]['oldestArchive']
                $archiveCount = $viewHistory[$view.name]['archiveCount']
                $lastDataLock = $viewHistory[$view.name]['lastDataLock']
            }
        }
        $sourceName = $view.storageDomainName
        $viewName = $view.name
        output "  $viewName"
        $dataIn = 0
        $dataInAfterDedup = 0
        $jobWritten = 0
        $consumption = 0
        $objFESize = toUnits $viewStats.totalLogicalUsageBytes
        $objGrowth = 0
        if($jobName -ne '-' -and $jobName -in $viewJobStats.Keys){
            $objWeight = $viewStats.storageConsumedBytes / $viewJobAltStats[$jobName]["totalConsumed"]
            $dataIn = $viewJobStats[$jobName].stats.dataInBytes * $objWeight
            $dataInAfterDedup = $viewJobStats[$jobName].stats.dataInBytesAfterDedup * $objWeight
            $jobWritten = $viewJobStats[$jobName].stats.dataWrittenBytes * $objWeight
            $consumption =  $viewJobStats[$jobName].stats.localTotalPhysicalUsageBytes * $objWeight
            $objGrowth = toUnits ($objWeight * ($viewJobStats[$jobName].stats.storageConsumedBytes - $viewJobStats[$jobName].stats.storageConsumedBytesPrev))
        }else{
            $objWeight = 1
            $dataIn = $viewStats.dataInBytes
            $dataInAfterDedup = $viewStats.dataInBytesAfterDedup
            $jobWritten = $viewStats.dataWrittenBytes
            $consumption = $viewStats.localTotalPhysicalUsageBytes
            $objGrowth = toUnits ($viewStats.storageConsumedBytes - $viewStats.storageConsumedBytesPrev)
        }
        $statsTimeUsecs = $viewStats.dataWrittenBytesTimestampUsec
        if($statsTimeUsecs -gt 0){
            $statsAge = [math]::Round(($nowUsecs - $statsTimeUsecs) / 86400000000, 0)
        }
        
        if($dataInAfterDedup -gt 0 -and $jobWritten -gt 0){
            $dedup = [math]::Round($dataIn / $dataInAfterDedup, 1)
            $compression = [math]::Round($dataInAfterDedup / $jobWritten, 1)
            $jobReduction = [math]::Round(($dataIn / $dataInAfterDedup) * ($dataInAfterDedup / $jobWritten), 1)
        }else{
            $jobReduction = 1
        }
        # archive stats
        $totalArchived = 0
        $vaultStats = ''
        if($cloudStats){
            foreach($vaultSummary in $cloudStats.dataTransferSummary){
                foreach($cloudJob in $vaultSummary.dataTransferPerProtectionJob){
                    if($cloudJob.protectionJobName -eq $jobName){
                        if($cloudJob.storageConsumed -gt 0){
                            $totalArchived += ($objWeight * $cloudJob.storageConsumed)
                            $vaultStats += "[$($vaultSummary.vaultName)]$(toUnits ($objWeight * $cloudJob.storageConsumed)) "
                        }
                    }
                }
            }
        }
        $sumObjectsUsed += $viewStats.totalLogicalUsageBytes
        $sumObjectsWritten += $jobWritten
        $sumObjectsWrittenWithResiliency += $consumption
        """$($cluster.name)"",""$origin"",""$statsAge"",""$($jobName)"",""$($view.tenantId -replace ".$")"",""$($view.storageDomainId)"",""$($view.storageDomainName)"",""kView"",""$sourceName"",""$viewName"",""$objFESize"",""$objFESize"",""$(toUnits $dataIn)"",""$(toUnits $jobWritten)"",""$(toUnits $consumption)"",""$jobReduction"",""$objGrowth"",""$numSnaps"",""$numLogs"",""$oldestBackup"",""$newestBackup"",""$lastDataLock"",""$archiveCount"",""$oldestArchive"",""$(toUnits $totalArchived)"",""$vaultStats"",""$($view.description)"",""""" | Out-File -FilePath $outfileName -Append
        if($secondFormat){
            """$($cluster.name)"",""$monthString"",""$viewName"",""$($view.description)"",""$(toUnits $consumption)""" | Out-File -FilePath $outfile2 -Append
        }
    }
    $garbageStart = (dateToUsecs (Get-Date -Hour 0 -Minute 0 -Second 0)) / 1000
    $bookKeeperStart = (dateToUsecs ((Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-29))) / 1000
    $bookKeeperEnd = (dateToUsecs ((Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(1))) / 1000
    $bookKeeperStats = api get "statistics/timeSeriesStats?startTimeMsecs=$bookKeeperStart&schemaName=MRCounters&metricName=bytes_value&rollupIntervalSecs=180&rollupFunction=average&entityId=BookkeeperChunkBytesPhysical&endTimeMsecs=$bookKeeperEnd"
    $bookKeeperBytes = $bookKeeperStats.dataPointVec[-1].data.int64Value
    $clusterUsedBytes = $cluster.stats.usagePerfStats.totalPhysicalUsageBytes
    $unaccounted = $clusterUsedBytes - $bookKeeperBytes
    $unaccountedPercent = 0
    $garbageStats = api get "statistics/timeSeriesStats?endTimeMsecs=$bookKeeperEnd&entityId=$($cluster.id)&metricName=kMorphedGarbageBytes&metricUnitType=0&range=day&rollupFunction=average&rollupIntervalSecs=360&schemaName=kBridgeClusterStats&startTimeMsecs=$garbageStart"
    $garbageBytes = $garbageStats.dataPointVec[-1].data.int64Value
    $garbagePercent = 0
    $otherUnaccountedBytes = $unaccounted - $garbageBytes
    $otherUnaccountedPercent = 0
    if($clusterUsedBytes -gt 0){
        $unaccountedPercent = [math]::Round(100 * ($unaccounted / $clusterUsedBytes), 1)
        $garbagePercent = [math]::Round(100 * ($garbageBytes / $clusterUsedBytes), 1)
        $otherUnaccountedPercent = $unaccountedPercent - $garbagePercent
    }
    $storageVarianceFactor = [math]::Round($clusterUsedBytes / $sumObjectsWrittenWithResiliency, 4)
    """$($cluster.name)"",""$clusterUsed"",""$(toUnits $bookKeeperBytes)"",""$(toUnits $unaccounted)"",""$unaccountedPercent"",""$(toUnits $garbageBytes)"",""$garbagePercent"",""$(toUnits $otherUnaccountedBytes)"",""$otherUnaccountedPercent"",""$clusterReduction"",""$(toUnits $sumObjectsUsed)"",""$(toUnits $sumObjectsWritten)"",""$(toUnits $sumObjectsWrittenWithResiliency)"",""$storageVarianceFactor"",""$scriptVersion"",""$($cluster.clusterSoftwareVersion)""" | Out-File -FilePath $clusterStatsFileName -Append
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
            reportStorage
        }
    }else{
        reportStorage
    }
}

output "`nCompleted`n"
output "       Output saved to: $outfileName"
output "Cluster stats saved to: $clusterStatsFileName"
if($secondFormat){
    output "Second format saved to: $outfile2`n"
}
output "     Log file saved to: $logFileName`n"
