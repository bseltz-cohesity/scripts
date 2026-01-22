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
    [Parameter()][int]$days,
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

$tail = ''
if($days){
    $daysBack = (Get-Date).AddDays(-$days)
    $daysBackUsecs = dateToUsecs $daysBack
    $tail = "&startTimeUsecs=$daysBackUsecs"
}

# outfile
$now = Get-Date
$nowUsecs = dateToUsecs $now
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = $(Join-Path -Path $outputPath -ChildPath "protectionRunsReport-$dateString.csv")

# headings
$headings = "Start Time,End Time,Duration,status,slaStatus,snapshotStatus,objectName,sourceName,groupName,policyName,Object Type,backupType,System Name,Logical Size $unit,Data Read $unit,Data Written $unit,Organization Name,DataLock Expiry,Legal Hold"

$headings | Out-File -FilePath $outfileName

# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return ("{0:n1}" -f ($val/($conversion[$unit]))).replace(',','')
}

$query = ''
if($localOnly){
    $query = '&isActive=true'
}

function dateToString($dt, $format='yyyy-MM-dd HH:mm:ss'){
    if($dt -eq $null){
        return ''
    }else{
        if($amPmFormat){
            $format = 'yyyy-MM-dd hh:mm:ss tt'
        }
        return ($dt.ToString($format) -replace [char]8239, ' ')
    }
}

function reportRuns(){

    $cluster = api get cluster
    $jobs = api get -v2 "data-protect/protection-groups?includeTenants=true$query"
    $sources = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false"
    $policies = api get -v2 data-protect/policies

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $endUsecs = $nowUsecs
        $environment = $job.environment
        $tenant = $job.permissions.name
        if(!$objectType -or $objectType -eq $environment){
            "{0} ({1})" -f $job.name, $environment
            $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
            if(!$policyName){
                $policyName = '-'
            }
            $lastRunId = 0
            while($True){
                if($fullOnly){
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&excludeNonRestorableRuns=true&includeObjectDetails=true&runTypes=kFull$tail"
                }elseif($includeLogs){
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&excludeNonRestorableRuns=true&includeObjectDetails=true$tail"
                }else{
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&excludeNonRestorableRuns=true&includeObjectDetails=true&runTypes=kIncremental,kFull$tail"
                }
                if(!$runs.runs -or $runs.runs.Count -eq 0 -or $runs.runs[-1].id -eq $lastRunId){
                    break
                }
                $runs.runs = $runs.runs | Where-Object {$_.id -ne $lastRunId}
                $lastRunId = $runs.runs[-1].id
                foreach($run in $runs.runs){
                    $localSources = @{}
                    if(! $run.PSObject.Properties['isLocalSnapshotsDeleted'] -or $run.isLocalSnapshotsDeleted -ne $True){
                        if($run.PSObject.Properties['localBackupInfo']){
                            $backupInfo = $run.localBackupInfo
                        }elseif($run.PSObject.Properties['originalBackupInfo']){
                            $backupInfo = $run.originalBackupInfo
                        }else{
                            $backupInfo = $run.archivalInfo.archivalTargetResults[0]
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
                            "    {0} ({1})" -f $runStartTime, $runType
                            foreach($object in $run.objects){
                                if($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -eq 'kHost'){
                                    $localSources["$($object.object.id)"] = $object.object.name
                                }
                            }
                            $lockUntil = ''
                            if($backupInfo.PSObject.Properties['dataLockConstraints']){
                                if($backupInfo.dataLockConstraints.expiryTimeUsecs -gt $nowUsecs -and $backupInfo.dataLockConstraints.mode -eq 'Compliance'){
                                    $lockUntil = usecsToDate $backupInfo.dataLockConstraints.expiryTimeUsecs -format 'yyyy-MM-dd hh:mm'
                                }
                            }
                            foreach($object in $run.objects){
                                if($run.PSObject.Properties['localBackupInfo']){
                                    $snapshotInfo = $object.localSnapshotInfo.snapshotInfo
                                }elseif($run.PSObject.Properties['originalBackupInfo']){
                                    $snapshotInfo = $object.originalBackupInfo.snapshotInfo
                                }else{
                                    $snapshotInfo = $object.archivalInfo.archivalTargetResults[0]
                                }
                                $objectName = $object.object.name
                                $onLegalHold = $object.onLegalHold
                                if($environment -notin @('kOracle', 'kSQL') -or ($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -ne 'kHost')){
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
                                    $objectStatus = $snapshotInfo.status
                                    if($objectStatus -eq 'kSuccessful'){
                                        $objectStatus = 'kSuccess'
                                    }
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
                                    $objectBytesWritten = toUnits $snapshotInfo.stats.bytesWritten
                                    $objectBytesRead = toUnits $snapshotInfo.stats.bytesRead
                                    # "        {0}" -f $objectName
                                    if(!$onHoldOnly -or $onLegalHold -eq $True){
                                        $(dateToString $objectStartTime), $(dateToString $objectEndTime), $objectDurationSeconds, $objectStatus, $slaStatus, 'Active', $objectName, $registeredSourceName, $job.name, $policyName, $environment, $runType, $cluster.name, $objectLogicalSizeBytes, $objectBytesRead, $objectBytesWritten, $tenant, $lockUntil, $onLegalHold -join "," | Out-File -FilePath $outfileName -Append
                                    }                                    
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
