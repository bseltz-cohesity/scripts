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
    [Parameter()][string]$objectType,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'GiB',
    [Parameter()][int]$numRuns = 500
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

if($days){
    $daysBack = (Get-Date).AddDays(-$days)
    $daysBackUsecs = dateToUsecs $daysBack
}

# outfile
$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "protectionRunsReport-$dateString.tsv"

# headings
$headings = "Start Time`tEnd Time`tDuration`tstatus`tslaStatus`tsnapshotStatus`tobjectName`tsourceName`tgroupName`tpolicyName`tObject Type`tbackupType`tSystem Name`tLogical Size $unit`tData Read $unit`tData Written $unit`tOrganization Name"

$headings | Out-File -FilePath $outfileName

# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt
    if(!$cohesity_api.authorized){
        Write-Host "Not authenticated to $v" -ForegroundColor Yellow
        continue
    }

    $cluster = api get cluster
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"
    $sources = api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false
    $policies = api get -v2 data-protect/policies

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $endUsecs = dateToUsecs $now
        $environment = $job.environment
        $tenant = $job.permissions.name
        if(!$objectType -or $objectType -eq $environment){
            "{0} ({1})" -f $job.name, $environment
            $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
            while($True){
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true"
                foreach($run in $runs.runs){
                    if(! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
                        if($run.PSObject.Properties['localBackupInfo']){
                            $runType = $run.localBackupInfo.runType
                        }else{
                            break
                        }
                        if($includeLogs -or $runType -ne 'kLog'){
                            $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
                            if($days -and $daysBack -gt $runStartTime){
                                break
                            }
                            $status = $run.localBackupInfo.status
                            if($run.localBackupInfo.isSlaViolated){
                                $slaStatus = 'Missed'
                            }else{
                                $slaStatus = 'Met'
                            }
                            $runEndTime = $null
                            $durationMinutes = "{0:n0}" -f ($now - $runStartTime).totalMinutes
                            if($run.localBackupInfo.PSObject.Properties['endTimeUsecs']){
                                $runEndTime = usecsToDate $run.localBackupInfo.endTimeUsecs
                                $durationMinutes = "{0:n0}" -f ($runEndTime - $runStartTime).totalMinutes
                            }
                            $logicalSizeBytes = toUnits $run.localBackupInfo.localSnapshotStats.logicalSizeBytes
                            $bytesWritten = toUnits $run.localBackupInfo.localSnapshotStats.bytesWritten
                            $bytesRead = toUnits $run.localBackupInfo.localSnapshotStats.bytesRead
                            "    {0} ({1})" -f $runStartTime, $runType
                            if($days -and $daysBack -gt $runStartTime){
                                break
                            }
                            if(! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
                                foreach($object in $run.objects){
                                    $objectName = $object.object.name
                                    if($environment -notin @('Oracle', 'SQL') -or ($environment -in @('Oracle', 'SQL') -and $object.object.objectType -ne 'kHost')){
                                        if($object.object.PSObject.Properties['sourceId']){
                                            $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
                                            $registeredSourceName = $registeredSource.rootNode.name
                                        }else{
                                            $registeredSourceName = $objectName
                                        }
                                        $objectStatus = $object.localSnapshotInfo.snapshotInfo.status
                                        if($objectStatus -eq 'kSuccessful'){
                                            $objectStatus = 'kSuccess'
                                        }
                                        $objectStartTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.startTimeUsecs
                                        $objectEndTime = $null
                                        $objectDurationSeconds = "{0:n0}" -f ($now - $objectStartTime).totalSeconds
                                        if($object.localSnapshotInfo.snapshotInfo.PSObject.Properties['endTimeUsecs']){
                                            $objectEndTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.endTimeUsecs
                                            $objectDurationSeconds = "{0:n0}" -f ($objectEndTime - $objectStartTime).totalSeconds
                                        }
                                        $objectLogicalSizeBytes = toUnits $object.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
                                        $objectBytesWritten = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesWritten
                                        $objectBytesRead = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesRead
                                        "        {0}" -f $objectName
                                        $objectStartTime, $objectEndTime, $objectDurationSeconds, $objectStatus, $slaStatus, 'Active', $objectName, $registeredSourceName, $job.name, $policyName, $environment, $runType, $cluster.name, $objectLogicalSizeBytes, $objectBytesRead, $objectBytesWritten, $tenant -join "`t" | Out-File -FilePath $outfileName -Append
                                    }
                                }
                            }
                        }
                    }
                }
                if($runs.runs.Count -eq $numRuns){
                    $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
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
