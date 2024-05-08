# version: 2024-05-07

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
# $clusterStatsFileName = $outfileName -replace ('.csv', '-clusterstats.csv')
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
"""Cluster Name"",""Total Used $unit"",""BookKeeper Used $unit"",""Unaccounted Usage $unit"",""Unaccounted Percent"",""Reduction Ratio"",""All Objects Front End Size $unit"",""All Objects Stored (After Reduction) $unit"",""All Objects Stored (After Reduction and Resiliency) $unit"",""Storage Variance Factor""" | Out-File -FilePath $clusterStatsFileName

if($secondFormat){
    $outfile2 = "customFormat2-storagePerObjectReport-$dateString.csv"
    """Cluster Name"",""Month"",""Object Name"",""Description"",""$unit Written plus Resiliency""" | Out-File -FilePath $outfile2
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
        $vaults = api get vaults?includeFortKnoxVault=true
        if($vaults){
            $nowMsecs = [Int64]((dateToUsecs) / 1000)
            $weekAgoMsecs = $nowMsecs - ($growthDays * 86400000)
            $cloudStart = $cluster.createdTimeMsecs
            $cloudStatURL = "reports/dataTransferToVaults?endTimeMsecs=$nowMsecs&startTimeMsecs=$cloudStart"
            foreach($vault in $vaults){
                $cloudStatURL += "&vaultIds=$($vault.id)"
            }
            output "  getting external target stats..."
            $cloudStats = api get $cloudStatURL
        }
    }
    
    if($skipDeleted){
        $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true&useCachedData=true"
    }else{
        $jobs = api get -v2 "data-protect/protection-groups?includeTenants=true&useCachedData=true"
    }
    
    $storageDomains = api get viewBoxes
    
    $sourceNames = @{}
    $msecsBeforeCurrentTimeToCompare = $growthDays * 24 * 60 * 60 * 1000
    $growthDaysUsecs = $growthDays * 24 * 60 * 60 * 1000000
    $nowUsecs = dateToUsecs
    
    # local backup stats
    $cookie = ''
    $localStats = @{'statsList'= @()}
    while($True){
        $theseStats = api get "stats/consumers?consumerType=kProtectionRuns&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)&cookie=$cookie"
        if($theseStats -and $theseStats.PSObject.Properties['statsList']){
            $localStats['statsList'] = @($localStats['statsList'] + $theseStats.statsList)
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

    # replica backup stats
    $cookie = ''
    $replicaStats = @{'statsList'= @()}
    while($True){
        $theseStats = api get "stats/consumers?consumerType=kReplicationRuns&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)&cookie=$cookie"
        if($theseStats -and $theseStats.PSObject.Properties['statsList']){
            $replicaStats['statsList'] = @($replicaStats['statsList'] + $theseStats.statsList)
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

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $statsAge = '-'
        $origin = 'local'
        if($job.isActive -ne $True){
            $origin = 'replica'
        }
        if($job.environment -eq 'kVMware'){
            $vmsearch = api get "/searchvms?allUnderHierarchy=true&entityTypes=kVMware&jobIds=$(($job.id -split ':')[2])&vmName=$($job.name)"
        }
        $v1JobId = ($job.id -split ':')[2]
        if($job.environment -notin @('kView', 'kRemoteAdapter')){
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
            while($True){
                if($dbg){
                    output "    getting runs"
                }
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true"
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

                            if($job.environment -eq 'kVMware' -and $objects[$objId]['fetb'] -eq 0){
                                if($dbg){
                                    Write-Host "    getting fetb"
                                }
                                # $vmsearch = api get "/searchvms?allUnderHierarchy=true&entityTypes=kVMware&jobIds=$(($job.id -split ':')[2])&vmName=$($object.object.name)"
                                $vms = $vmsearch.vms | Where-Object {$_.vmDocument.objectName -eq $object.object.name}
                                if($vms){
                                    $vmbytes = $vms[0].vmDocument.objectId.entity.vmwareEntity.frontEndSizeInfo.sizeBytes
                                    if($vmbytes -gt 0){
                                        # Write-Host "$($object.object.name) $objId $vmbytes"
                                        $objects[$objId]['logical'] = $vmbytes
                                        $objects[$objId]['fetb'] = $vmbytes
                                    }
                                    $tagAttrs = $vms[0].vmDocument.attributeMap | Where-Object xKey -match 'VMware_tag'
                                    if($tagAttrs){
                                        $objects[$objId]['vmTags'] = $tagAttrs.xValue -join ';'
                                    }
                                }
                            }
                            if($snap -and $objId -in $objects.Keys -and $snap.snapshotInfo.stats.PSObject.Properties['logicalSizeBytes'] -and $snap.snapshotInfo.stats.logicalSizeBytes -gt $objects[$objId]['logical']){
                                if($job.environment -ne 'kVMware' -or $objects[$objId]['logical'] -eq 0){
                                    $objects[$objId]['logical'] = $snap.snapshotInfo.stats.logicalSizeBytes
                                }
                            }
                            if($job.environment -eq 'kVMware' -and $snap.snapshotInfo.stats.logicalSizeBytes -lt $objects[$objId]['logical'] -and $snap.snapshotInfo.stats.logicalSizeBytes -gt 0){
                                # Write-Host "$($object.object.name)  $($snap.snapshotInfo.stats.logicalSizeBytes) -----------------------"  # =========================================
                                $objects[$objId]['logical'] = $snap.snapshotInfo.stats.logicalSizeBytes
                            }
                            if(!$snap -and $objId -in $objects.Keys -and $archivalInfo.stats.PSObject.Properties['logicalSizeBytes'] -and $archivalInfo.stats.logicalSizeBytes -gt $objects[$objId]['archiveLogical'] -and $objects[$objId]['archiveLogical'] -gt 0){
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
                                    # if($snap.snapshotInfo.startTimeUsecs -gt $growthDaysUsecs){
                                    #     $objects[$objId]['growth'] += $snap.snapshotInfo.stats.bytesRead
                                    #     $jobObjGrowth += $snap.snapshotInfo.stats.bytesRead
                                    # }
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
                if($runs.runs.Count -eq $numRuns){
                    if($runs.runs[-1].PSObject.Properties['localBackupInfo']){
                        $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
                    }else{
                        $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs - 1
                    }
                }else{
                    break
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
                                # Write-Host "$sourceName - $($thisObject['name']) - $($thisObject['sourceId']) - new - $($parentObjects[$thisObject['sourceId']]['bytesRead'])"
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
                $objGrowth = toUnits ($thisObject['growth'] / $jobReduction)
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
                }else{
                    $objWritten = [math]::Round($objFESize / $jobReduction, 1)
                }
                if($dataIn -gt 0){
                    $objDataIn = [math]::Round($objWeight * $dataIn, 1)
                }else{
                    $objDataIn = [math]::Round($objFESize / $jobReduction, 1)
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
                if($job.environment -eq 'kVMware'){
                    # Write-Host "$($thisObject['name']) $objFESize" # ============================================
                    $alloc = toUnits $thisObject['alloc']
                }
                $sumObjectsUsed += $thisObject['logical']
                $sumObjectsWritten += $objWritten
                $sumObjectsWrittenWithResiliency += $objWrittenWithResiliency
                """$($cluster.name)"",""$origin"",""$statsAge"",""$($job.name)"",""$tenant"",""$($job.storageDomainId)"",""$sdName"",""$($job.environment)"",""$sourceName"",""$($thisObject['name'])"",""$alloc"",""$objFESize"",""$(toUnits $objDataIn)"",""$(toUnits $objWritten)"",""$(toUnits $objWrittenWithResiliency)"",""$jobReduction"",""$objGrowth"",""$($thisObject['numSnaps'])"",""$($thisObject['numLogs'])"",""$(usecsToDate $thisObject['oldestBackup'])"",""$(usecsToDate $thisObject['newestBackup'])"",""$($thisObject['lastDataLock'])"",""$archiveCount"",""$oldestArchive"",""$(toUnits $totalArchived)"",""$vaultStats"",""$($job.description)"",""$($thisObject['vmTags'])""" | Out-File -FilePath $outfileName -Append
                if($secondFormat){
                    """$($cluster.name)"",""$monthString"",""$fqObjectName"",""$($job.description)"",""$(toUnits $objWrittenWithResiliency)""" | Out-File -FilePath $outfile2 -Append
                }
            }
        }elseif($job.environment -in @('kView', 'kRemoteAdapter')){
            if($job.isActive -eq $True){
                $stats = $localStats
            }else{
                $stats = $replicaStats
            }
            if($stats){
                
                $thisStat = $stats.statsList | Where-Object {$_.id -eq $v1JobId}
            }
            $endUsecs = $nowUsecs
            $lastDataLock = '-'
            while($True){
                if($dbg){
                    output "    getting runs"
                }
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true"
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
                                $viewHistory[$object.object.name]['newestBackup'] = usecsToDate $snap.snapshotInfo.startTimeUsecs
                                $viewHistory[$object.object.name]['oldestBackup'] = usecsToDate $snap.snapshotInfo.startTimeUsecs
                                $viewHistory[$object.object.name]['archiveCount'] = 0
                                $viewHistory[$object.object.name]['oldestArchive'] = '-'
                                $viewHistory[$object.object.name]['lastDataLock'] = $lastDataLock
                            }
                            $viewHistory[$object.object.name]['oldestBackup'] = usecsToDate $snap.snapshotInfo.startTimeUsecs
                            $viewHistory[$object.object.name]['numSnaps'] += 1
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
                if($runs.runs.Count -eq $numRuns){
                    if($runs.runs[-1].PSObject.Properties['localBackupInfo']){
                        $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
                    }else{
                        $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs - 1
                    }
                }else{
                    break
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
        if($view.PSObject.Properties['stats']){
            $viewStats = $view.stats.dataUsageStats
        }elseif($view.name -in $viewHistory.Keys){
            $viewStats = $viewHistory[$view.name]['stats'].stats
        }else{
            continue
        }
        try{
            $jobName = $view.viewProtection.protectionGroups[-1].groupName
        }catch{
            $jobName = '-'
        }
        if($jobName -notin $viewJobStats.Keys){
            $viewJobStats[$jobName] = 0
        }
        $viewJobStats[$jobName] += $viewStats.totalLogicalUsageBytes
    }
    
    foreach($view in $views.views){
        if($view.PSObject.Properties['stats']){
            $viewStats = $view.stats.dataUsageStats
        }elseif($view.name -in $viewHistory.Keys){
            $viewStats = $viewHistory[$view.name]['stats'].stats
        }else{
            continue
        }
        $origin = 'local'
        $statsAge = '-'
        try{
            $jobName = $view.viewProtection.protectionGroups[-1].groupName
            $thisJob = $jobs.protectionGroups | Where-Object {$_.name -eq $jobName}
            if($thisJob){
                if($thisJob.isActive -ne $True){
                    $origin = 'replica'
                }
            }
        }catch{
            $jobName = '-'
        }
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
        if($jobName -ne '-' -and $viewJobStats[$jobName] -gt 0){
            $objWeight = $viewStats.totalLogicalUsageBytes / $viewJobStats[$jobName]
        }else{
            $objWeight = 1
        }
        $dataIn = $viewStats.dataInBytes
        $dataInAfterDedup = $viewStats.dataInBytesAfterDedup
        $jobWritten = $viewStats.dataWrittenBytes
        $statsTimeUsecs = $viewStats.dataWrittenBytesTimestampUsec
        if($statsTimeUsecs -gt 0){
            $statsAge = [math]::Round(($nowUsecs - $statsTimeUsecs) / 86400000000, 0)
        }
        $consumption = $viewStats.localTotalPhysicalUsageBytes
        if($dataInAfterDedup -gt 0 -and $jobWritten -gt 0){
            $dedup = [math]::Round($dataIn / $dataInAfterDedup, 1)
            $compression = [math]::Round($dataInAfterDedup / $jobWritten, 1)
            $jobReduction = [math]::Round(($dataIn / $dataInAfterDedup) * ($dataInAfterDedup / $jobWritten), 1)
        }else{
            $jobReduction = 1
        }
        $stat = $stats.statsList | Where-Object name -eq $viewName
        $objGrowth = 0
        if($stat){
            $objGrowth = toUnits ($stat.stats.storageConsumedBytes - $stat.stats.storageConsumedBytesPrev)
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
    $bookKeeperStart = (dateToUsecs ((Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-29))) / 1000
    $bookKeeperEnd = (dateToUsecs ((Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(1))) / 1000
    $bookKeeperStats = api get "statistics/timeSeriesStats?startTimeMsecs=$bookKeeperStart&schemaName=MRCounters&metricName=bytes_value&rollupIntervalSecs=180&rollupFunction=average&entityId=BookkeeperChunkBytesPhysical&endTimeMsecs=$bookKeeperEnd"
    $bookKeeperBytes = $bookKeeperStats.dataPointVec[-1].data.int64Value
    $clusterUsedBytes = $cluster.stats.usagePerfStats.totalPhysicalUsageBytes
    $unaccounted = $clusterUsedBytes - $bookKeeperBytes
    $unaccountedPercent = [math]::Round(100 * ($unaccounted / $clusterUsedBytes), 1)
    $storageVarianceFactor = [math]::Round($clusterUsedBytes / $sumObjectsWrittenWithResiliency, 4)
    """$($cluster.name)"",""$clusterUsed"",""$(toUnits $bookKeeperBytes)"",""$(toUnits $unaccounted)"",""$unaccountedPercent"",""$clusterReduction"",""$(toUnits $sumObjectsUsed)"",""$(toUnits $sumObjectsWritten)"",""$(toUnits $sumObjectsWrittenWithResiliency)"",""$storageVarianceFactor""" | Out-File -FilePath $clusterStatsFileName -Append
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
