# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][array]$vip,
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][int]$days,
    [Parameter()][switch]$includeLogs,
    [Parameter()][switch]$fullOnly,
    [Parameter()][switch]$localOnly,
    [Parameter()][string]$objectType,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'GiB',
    [Parameter()][string]$outputPath = '.',
    [Parameter()][int]$numRuns = 120
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
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = $(Join-Path -Path $outputPath -ChildPath "protectionRunsReport-$dateString.csv")

# headings
$headings = "Start Time,End Time,Duration,status,slaStatus,snapshotStatus,objectName,sourceName,groupName,policyName,Object Type,backupType,System Name,Logical Size $unit,Data Read $unit,Data Written $unit,Organization Name"

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

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated to $v" -ForegroundColor Yellow
        continue
    }

    $cluster = api get cluster
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false$query&includeTenants=true"
    $sources = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false"
    $policies = api get -v2 data-protect/policies

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $endUsecs = dateToUsecs $now
        $environment = $job.environment
        $tenant = $job.permissions.name
        if(!$objectType -or $objectType -eq $environment){
            "{0} ({1})" -f $job.name, $environment
            $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
            if(!$policyName){
                $policyName = '-'
            }
            while($True){
                if($fullOnly){
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&runTypes=kFull$tail"
                }elseif($includeLogs){
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true$tail"
                }else{
                    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true&runTypes=kIncremental,kFull$tail"
                }
                foreach($run in $runs.runs){
                    $localSources = @{}
                    if(! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
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
                            foreach($object in $run.objects){
                                if($run.PSObject.Properties['localBackupInfo']){
                                    $snapshotInfo = $object.localSnapshotInfo.snapshotInfo
                                }elseif($run.PSObject.Properties['originalBackupInfo']){
                                    $snapshotInfo = $object.originalBackupInfo.snapshotInfo
                                }else{
                                    $snapshotInfo = $object.archivalInfo.archivalTargetResults[0]
                                }
                                $objectName = $object.object.name
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
                                    "        {0}" -f $objectName
                                    $objectStartTime, $objectEndTime, $objectDurationSeconds, $objectStatus, $slaStatus, 'Active', $objectName, $registeredSourceName, $job.name, $policyName, $environment, $runType, $cluster.name, $objectLogicalSizeBytes, $objectBytesRead, $objectBytesWritten, $tenant -join "," | Out-File -FilePath $outfileName -Append
                                }
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
                    if($endUsecs -lt 0 -or $endUsecs -lt $daysBackUsecs){
                        break
                    }
                }else{
                    break
                }
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
