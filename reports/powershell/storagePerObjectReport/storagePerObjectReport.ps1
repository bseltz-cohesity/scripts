# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][int]$numRuns = 100,
    [Parameter()][int]$growthDays = 7,
    [Parameter()][switch]$skipDeleted,
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'GiB',
    [Parameter()][switch]$dbg
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return [math]::Round($val/$conversion[$unit], 1)
    # return "{0:n1}" -f ($val/($conversion[$unit]))
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$cluster = api get "cluster?fetchStats=true"
try{
    $clusterReduction = [math]::Round($cluster.stats.usagePerfStats.dataInBytes / $cluster.stats.usagePerfStats.dataInBytesAfterjobReduction, 1)
}catch{
    $clusterReduction = 1
}

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "storagePerObjectReport-$($cluster.name)-$dateString.csv"

$vaults = api get vaults
if($vaults){
    $nowMsecs = [Int64]((dateToUsecs) / 1000)
    $weekAgoMsecs = $nowMsecs - (86400000)
    $cloudStatURL = "reports/dataTransferToVaults?endTimeMsecs=$nowMsecs&startTimeMsecs=$weekAgoMsecs"
    foreach($vault in $vaults){
        $cloudStatURL += "&vaultIds=$($vault.id)"
    }
    $cloudStats = api get $cloudStatURL 
}

# headings
"""Job Name"",""Tenant"",""Environment"",""Source Name"",""Object Name"",""Logical $unit"",""$unit Written"",""$unit Written plus Resiliency"",""Job Reduction Ratio"",""$unit Written Last $growthDays Days"",""$unit Archived"",""$unit per Archive Target"",""Description""" | Out-File -FilePath $outfileName

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

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($job.environment -notin @('kView', 'kRemoteAdapter')){
        Write-Host $job.name
        $tenant = $job.permissions.name
        # get resiliency factor
        $resiliencyFactor = 0
        if($job.PSObject.Properties['storageDomainId']){
            $sd = $storageDomains | Where-Object id -eq $job.storageDomainId
            if($sd){
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
            }
        }
        $objects = @{}
        $v1JobId = ($job.id -split ':')[2]
        $jobObjGrowth = 0
        $jobGrowth = 0

        # job stats
        if($job.isActive -eq $True){
            $stats = api get "stats/consumers?consumerType=kProtectionRuns&consumerIdList=$($v1JobId)&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)"
        }else{
            $stats = api get "stats/consumers?consumerType=kReplicationRuns&consumerIdList=$($v1JobId)&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)"
        }
        if($stats -and $stats.PSObject.Properties['statsList']){
            try{
                $dataIn = $stats.statsList[0].stats.dataInBytes
                $dataInAfterDedup = $stats.statsList[0].stats.dataInBytesAfterDedup
                $jobWritten = $stats.statsList[0].stats.dataWrittenBytes
                $storageConsumedBytes = $stats.statsList[0].stats.storageConsumedBytes
            }catch{
                $dataIn = 0
                $dataInAfterDedup = 0
                $jobWritten = 0
                $storageConsumedBytes = 0
            }
            try{
                $storageConsumedBytesPrev = $stats.statsList[0].stats.storageConsumedBytesPrev
            }catch{
                $storageConsumedBytesPrev = 0
            }
            
            if($storageConsumedBytes -gt 0 -and $storageConsumedBytesPrev -gt 0){
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
        $endUsecs = $nowUsecs
        while($True){
            if($dbg){
                Write-Host "    getting runs"
            }
            $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true"
            foreach($run in $runs.runs | Where-Object isLocalSnapshotsDeleted -ne $True){
                foreach($object in $run.objects | Where-Object {$_.object.environment -ne $job.environment}){
                    $sourceNames["$($object.object.id)"] = $object.object.name
                }
                foreach($object in $run.objects){
                    $objId = "$($object.object.id)"
                    if($object.PSObject.Properties['localSnapshotInfo']){
                        $snap = $object.localSnapshotInfo
                    }else{
                        $snap = $object.originalBackupInfo
                    }
                    if($objId -notin $objects.Keys -and !($job.environment -eq 'kAD' -and $object.object.environment -eq 'kAD') -and !($job.environment -in @('kSQL', 'kOracle') -and $object.object.objectType -eq 'kHost')){
                        $objects[$objId] = @{}
                        $objects[$objId]['name'] = $object.object.name
                        $objects[$objId]['logical'] = 0
                        $objects[$objId]['bytesRead'] = 0
                        $objects[$objId]['growth'] = 0
                        if($object.object.PSObject.Properties['sourceId']){
                            $objects[$objId]['sourceId'] = $object.object.sourceId
                        }
                        if(! $snap.snapshotInfo.stats.PSObject.Properties['logicalSizeBytes']){
                            if($dbg){
                                Write-Host "    getting source"
                            }
                            $csource = api get "protectionSources?id=$objId&useCachedData=true" -quiet
                            if( $csource.protectedSourcesSummary.Count -gt 0){
                                $objects[$objId]['logical'] = $csource.protectedSourcesSummary[0].totalLogicalSize
                            }else{
                                $objects[$objId]['logical'] = 0
                            }
                        }else{
                            $objects[$objId]['logical'] = $snap.snapshotInfo.stats.logicalSizeBytes
                        }
                    }
                    if($objId -in $objects.Keys -and $snap.snapshotInfo.stats.PSObject.Properties['logicalSizeBytes'] -and $snap.snapshotInfo.stats.logicalSizeBytes -gt $objects[$objId]['logical']){
                        $objects[$objId]['logical'] = $snap.snapshotInfo.stats.logicalSizeBytes
                    }
                    if($objId -in $objects.Keys){
                        $objects[$objId]['bytesRead'] += $snap.snapshotInfo.stats.bytesRead
                        if($snap.snapshotInfo.startTimeUsecs -gt $growthDaysUsecs){
                            $objects[$objId]['growth'] += $snap.snapshotInfo.stats.bytesRead
                            $jobObjGrowth += $snap.snapshotInfo.stats.bytesRead
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
        # process output
        $jobFESize = 0
        foreach($objId in $objects.Keys){
            $thisObject = $objects[$objId]
            $jobFESize += $thisObject['logical']
            $jobFESize += $thisObject['bytesRead']
        }
        
        foreach($objId in $objects.Keys | Sort-Object){
            $thisObject = $objects[$objId]
            $objFESize = toUnits $thisObject['logical']
            $objGrowth = toUnits ($thisObject['growth'] / $jobReduction)
            if($jobObjGrowth -ne 0){
                $objGrowth = toUnits ($jobGrowth * $thisObject['growth'] / $jobObjGrowth)
            }
            if($jobFESize -gt 0){
                $objWeight = ($thisObject['logical'] + $thisObject['bytesRead']) / $jobFESize
            }else{
                $objWeight = 0
            }
            if($jobWritten -gt 0){
                $objWritten = $objWeight * $jobWritten
            }else{
                $objWritten = [math]::Round($objFESize / $jobReduction, 1)
            }
            $objWrittenWithResiliency = $objWritten * $resiliencyFactor
            $sourceName = ''
            if('sourceId' -in $thisObject.Keys){
                if("$($thisObject['sourceId'])" -in $sourceNames.Keys){
                    $sourceName = $sourceNames["$($thisObject['sourceId'])"]
                }else{
                    if($dbg){
                        Write-Host "    getting source (2)"
                    }
                    $source = api get "protectionSources?id=$($thisObject['sourceId'])&excludeTypes=kFolder,kDatacenter,kComputeResource,kClusterComputeResource,kResourcePool,kDatastore,kHostSystem,kVirtualMachine,kVirtualApp,kStandaloneHost,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&useCachedData=true"
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
                            }
                        }
                    }
                }
            }
            """$($job.name)"",""$tenant"",""$($job.environment)"",""$sourceName"",""$($thisObject['name'])"",""$objFESize"",""$(toUnits $objWritten)"",""$(toUnits $objWrittenWithResiliency)"",""$jobReduction"",""$objGrowth"",""$(toUnits $totalArchived)"",""$vaultStats"",""$($job.description)""" | Out-File -FilePath $outfileName -Append
        }
    }
}

# views
$views = api get -v2 "file-services/views?maxCount=2000&includeTenants=true&includeStats=true&includeProtectionGroups=true"
$stats = api get "stats/consumers?msecsBeforeCurrentTimeToCompare=$msecsBeforeCurrentTimeToCompare&consumerType=kViews"
$viewJobStats = @{}

# build total job FE sizes
foreach($view in $views.views){
    try{
        $jobName = $view.viewProtection.protectionGroups[-1].groupName
    }catch{
        $jobName = '-'
    }
    if($jobName -notin $viewJobStats.Keys){
        $viewJobStats[$jobName] = 0
    }
    $viewJobStats[$jobName] += $view.stats.dataUsageStats.totalLogicalUsageBytes
}

foreach($view in $views.views){
    try{
        $jobName = $view.viewProtection.protectionGroups[-1].groupName
    }catch{
        $jobName = '-'
    }
    $sourceName = $view.storageDomainName
    $viewName = $view.name
    Write-Host $viewName
    $dataIn = 0
    $dataInAfterDedup = 0
    $jobWritten = 0
    $consumption = 0
    $objFESize = toUnits $view.stats.dataUsageStats.totalLogicalUsageBytes
    if($jobName -ne '-'){
        $objWeight = $view.stats.dataUsageStats.totalLogicalUsageBytes / $viewJobStats[$jobName]
    }else{
        $objWeight = 1
    }
    $dataIn = $view.stats.dataUsageStats.dataInBytes
    $dataInAfterDedup = $view.stats.dataUsageStats.dataInBytesAfterDedup
    $jobWritten = $view.stats.dataUsageStats.dataWrittenBytes
    $consumption = $view.stats.dataUsageStats.localTotalPhysicalUsageBytes
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
    """$($jobName)"",""$($view.tenantId -replace “.$”)"",""kView"",""$sourceName"",""$viewName"",""$objFESize"",""$(toUnits $jobWritten)"",""$(toUnits $consumption)"",""$jobReduction"",""$objGrowth"",""$(toUnits $totalArchived)"",""$vaultStats"",""$($view.description)""" | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfilename`n"
