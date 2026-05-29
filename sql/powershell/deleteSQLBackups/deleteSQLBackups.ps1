# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$serverName,  # optional names of vms to expunge (comma separated)
    [Parameter()][string]$serverList = '',  # optional textfile of vms to expunge (one per line)
    [Parameter()][string]$jobName,
    [Parameter()][string]$tenantId = $null,
    [Parameter()][int]$olderThan = 0,
    [Parameter()][switch]$delete, # delete or just a test run
    [Parameter()][int]$numRuns = 500
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

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
$vms = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $True)

# logging
$runDate = get-date -UFormat %Y-%m-%d_%H-%M-%S
$logfile = Join-Path -Path $PSScriptRoot -ChildPath "expungeSQLBackups-$runDate.txt"

function log($text){
    "$text" | Tee-Object -FilePath $logfile -Append
}

log "- Started at $(get-date) -------`n"

# display run mode
if($delete){
    log "----------------------------------"
    log "  *PERMANENT DELETE MODE*         "
    log "  - selection will be deleted!!!"
    log "  - logging to $logfile"
    log "  - press CTRL-C to exit"
    log "----------------------------------`n"
}else {
    log "--------------------------"
    log "  *TEST RUN MODE*"
    log "  - not deleting"
    log "  - logging to $logfile"
    log "--------------------------`n"
}

$olderThanUsecs = dateToUsecs
if($olderThan){
    $olderThanUsecs = timeAgo $olderThan days
}

$jobs = api get -v2 "data-protect/protection-groups?environments=kSQL"

if($jobName -and $jobName -notin @($jobs.protectionGroups.name)){
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
    exit 1
}

$sources = api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false
$policies = api get -v2 data-protect/policies

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $endUsecs = $olderThanUsecs
    if(!$jobName -or $job.name -eq $jobName){
        while($True){
            $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeObjectDetails=true&excludeNonRestorableRuns=true"
            foreach($run in $runs.runs){
                if($run.PSObject.Properties['localBackupInfo']){
                    $runInfo = $run.localBackupInfo
                }elseif($run.PSObject.Properties['originalBackupInfo']){
                    $runInfo = $run.originalBackupInfo
                }else{
                    continue
                }
                $runStartTimeUsecs = $runInfo.startTimeUsecs
                foreach($object in $run.objects){
                    if($object.PSObject.Properties['localSnapshotInfo']){
                        $snapInfo = $object.localSnapshotInfo
                    }elseif($object.PSObject.Properties['originalBackupInfo']){
                        $snapInfo = $object.originalBackupInfo
                    }else{
                        continue
                    }
                    if($object.object.name -in $vms -and $snapInfo.snapshotInfo.PSObject.Properties['expiryTimeUsecs']){
                        if($delete){
                            $v1JobId = ($job.id -split ':')[-1]
                            $exactRun = api get "/backupjobruns?exactMatchStartTimeUsecs=$runStartTimeUsecs&id=$v1JobId&excludeTasks=true"
                            $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                            $deleteObjectParams = @{
                                "jobRuns" = @(
                                    @{
                                        "copyRunTargets" = @(
                                            @{
                                                "daysToKeep" = 0;
                                                "type" = "kLocal"
                                            }
                                        );
                                        "jobUid" = @{
                                            'clusterId' = $jobUid.clusterId;
                                            'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                                            'id' = $jobUid.objectId;
                                        };
                                        "runStartTimeUsecs" = $runStartTimeUsecs;
                                        "sourceIds" = @(
                                            $object.object.id
                                        )
                                    }
                                )
                            }
                            log "Deleting $($object.object.name) from $($job.name) ($(usecsToDate $runStartTimeUsecs))"
                            $null = api put protectionRuns $deleteObjectParams
                        }else{
                            log "Would delete $($object.object.name) from $($job.name) ($(usecsToDate $runStartTimeUsecs))"
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


#                 if(! $includeObjectDetails -or ! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
#                     # run level stats
#                     if($run.PSObject.Properties['localBackupInfo']){
#                         $runType = $run.localBackupInfo.runType.subString(1)
#                     }else{
#                         break
#                     }
#                     if($runType -eq 'Regular'){
#                         $runType = 'Incremental'
#                     }
#                     if($includeLogs -or $runType -ne 'Log'){
#                         $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
#                         if($days -and $daysBack -gt $runStartTime){
#                             break
#                         }
#                         $status = $run.localBackupInfo.status
#                         $runEndTime = $null
#                         $durationMinutes = "{0:n0}" -f ($now - $runStartTime).totalMinutes
#                         if($run.localBackupInfo.PSObject.Properties['endTimeUsecs']){
#                             $runEndTime = usecsToDate $run.localBackupInfo.endTimeUsecs
#                             $durationMinutes = "{0:n0}" -f ($runEndTime - $runStartTime).totalMinutes
#                         }
#                         $logicalSizeBytes = toUnits $run.localBackupInfo.localSnapshotStats.logicalSizeBytes
#                         $bytesWritten = toUnits $run.localBackupInfo.localSnapshotStats.bytesWritten
#                         $bytesRead = toUnits $run.localBackupInfo.localSnapshotStats.bytesRead
#                         "    {0} ({1})" -f $runStartTime, $runType
#                         if(! $includeObjectDetails){
#                             # write to output file
#                             $cluster.name, $tenant, $job.name, $environment, $runType, $runStartTime, $runEndTime, $durationMinutes, $status, $logicalSizeBytes, $bytesRead, $bytesWritten -join "`t" | Out-File -FilePath $outfileName -Append
#                         } 
#                         if($days -and $daysBack -gt $runStartTime){
#                             break
#                         }
#                         # object level stats
#                         if($includeObjectDetails -and ! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
#                             foreach($object in $run.objects){
#                                 $objectName = $object.object.name
#                                 if($environment -notin @('Oracle', 'SQL') -or ($environment -in @('Oracle', 'SQL') -and $object.object.objectType -ne 'kHost')){
#                                     if($object.object.PSObject.Properties['sourceId']){
#                                         $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
#                                         $registeredSourceName = $registeredSource.rootNode.name
#                                     }else{
#                                         $registeredSourceName = $objectName
#                                     }
#                                     $objectStatus = $object.localSnapshotInfo.snapshotInfo.status.subString(1)
#                                     $objectStartTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.startTimeUsecs
#                                     $objectEndTime = $null
#                                     $objectDurationMinutes = "{0:n0}" -f ($now - $objectStartTime).totalMinutes
#                                     if($object.localSnapshotInfo.snapshotInfo.PSObject.Properties['endTimeUsecs']){
#                                         $objectEndTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.endTimeUsecs
#                                         $objectDurationMinutes = "{0:n0}" -f ($objectEndTime - $objectStartTime).totalMinutes
#                                     }
#                                     $objectLogicalSizeBytes = toUnits $object.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
#                                     $objectBytesWritten = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesWritten
#                                     $objectBytesRead = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesRead
#                                     if($registeredSourceName){
#                                         "        {0}: {1}" -f $registeredSourceName, $objectName
#                                     }else{
#                                         "        {0}" -f $objectName
#                                     }
#                                     # write to output file
#                                     $cluster.name, $tenant, $job.name, $environment, $runType, $runStartTime, $registeredSourceName, $objectName, $objectStartTime, $objectEndTime, $objectDurationMinutes, $objectStatus, $objectLogicalSizeBytes, $objectBytesRead, $objectBytesWritten -join "`t" | Out-File -FilePath $outfileName -Append
#                                 }
#                             }
#                         }
#                     }
#                 }
#             }
#             if($runs.runs.Count -eq $numRuns){
#                 $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
#                 if($endUsecs -lt 0 -or $endUsecs -lt $daysBackUsecs){
#                     break
#                 }
#             }else{
#                 break
#             }
#         }
#     }
# }
