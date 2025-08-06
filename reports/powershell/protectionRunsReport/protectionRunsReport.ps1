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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][int]$days,
    [Parameter()][switch]$includeObjectDetails,
    [Parameter()][switch]$includeLogs,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
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
$headings = "Cluster Name`tTenant`tJob Name`tJob ID`tEnvironment`tPolicy Name`tRun Type`tRun Start Time`tRun End Time`tDuration (Min)`tRun Status`tLogical ($unit)`tRead ($unit)`tWritten ($unit)`tMessage"

if($includeObjectDetails){
   $headings = "Cluster Name`tTenant`tJob Name`tJob ID`tEnvironment`tPolicy Name`tRun Type`tRun Start Time`tRegistered Source`tObject Name`tStart Time`tEnd Time`tDuration (Min)`tStatus`tLogical ($unit)`tRead ($unit)`tWritten ($unit)`tMessage"
}
$headings | Out-File -FilePath $outfileName

# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

$incObjects = $false
if($includeObjectDetails){
    $incObjects = $True
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -noPromptForPassword $noPrompt
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
        $environment = $job.environment.subString(1)
        $tenant = $job.permissions.name
        "{0} ({1})" -f $job.name, $environment
        $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
        while($True){
            $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=$incObjects"
            foreach($run in $runs.runs){
                if($True){ # if(! $includeObjectDetails){ # -or ! $run.PSObject.Properties['isLocalSnapshotsDeleted'] -or $run.isLocalSnapshotsDeleted -ne $True){
                    # run level stats
                    if($run.PSObject.Properties['localBackupInfo']){
                        $runType = $run.localBackupInfo.runType.subString(1)
                    }else{
                        break
                    }
                    if($runType -eq 'Regular'){
                        $runType = 'Incremental'
                    }
                    if($includeLogs -or $runType -ne 'Log'){
                        $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
                        if($days -and $daysBack -gt $runStartTime){
                            break
                        }
                        $message = ''
                        $status = $run.localBackupInfo.status
                        if($status -in @('SucceededWithWarning', 'Failed')){
                            $message = $run.localBackupInfo.messages[0]
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
                        if(! $includeObjectDetails){
                            # write to output file
                            $cluster.name, $tenant, $job.name, $job.id, $environment, $policyName, $runType, $runStartTime, $runEndTime, $durationMinutes, $status, $logicalSizeBytes, $bytesRead, $bytesWritten, $message -join "`t" | Out-File -FilePath $outfileName -Append
                        } 
                        if($days -and $daysBack -gt $runStartTime){
                            break
                        }
                        # object level stats
                        if($includeObjectDetails){ # -and (! $run.PSObject.Properties['isLocalSnapshotsDeleted'] -or $run.isLocalSnapshotsDeleted -ne $True)){
                            foreach($object in $run.objects){
                                # $object | toJson
                                $objectName = $object.object.name
                                if($environment -notin @('Oracle', 'SQL') -or ($environment -in @('Oracle', 'SQL') -and $object.object.objectType -ne 'kHost')){
                                    if($object.object.PSObject.Properties['sourceId']){
                                        $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
                                        $registeredSourceName = $registeredSource.rootNode.name
                                    }else{
                                        $registeredSourceName = $objectName
                                    }
                                    $objectStatus = $object.localSnapshotInfo.snapshotInfo.status.subString(1)
                                    $message = ''
                                    if($objectStatus -notin @('Successful', 'Canceled')){
                                        if($object.localSnapshotInfo.PSObject.Properties['failedAttempts'] -and $object.localSnapshotInfo.failedAttempts -ne $null){
                                            $message = $object.localSnapshotInfo.failedAttempts[-1].message
                                        }else{
                                            $object.localSnapshotInfo | toJson | Out-file 'debug.json'
                                        }
                                    }
                                    $objectStartTimeUsecs = $object.localSnapshotInfo.snapshotInfo.startTimeUsecs
                                    if($objectStartTimeUsecs -gt 0){
                                        $objectStartTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.startTimeUsecs
                                    }else{
                                        $objectStartTime = $runStartTime
                                    }
                                    $objectEndTime = $null
                                    $objectDurationMinutes = 0
                                    if($object.localSnapshotInfo.snapshotInfo.PSObject.Properties['endTimeUsecs']){
                                        $objectEndTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.endTimeUsecs
                                        $objectDurationMinutes = "{0:n0}" -f ($objectEndTime - $objectStartTime).totalMinutes
                                    }
                                    $objectLogicalSizeBytes = toUnits $object.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
                                    $objectBytesWritten = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesWritten
                                    $objectBytesRead = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesRead
                                    "        {0}" -f $objectName
                                    # write to output file
                                    $cluster.name, $tenant, $job.name, $job.id, $environment, $policyName, $runType, $runStartTime, $registeredSourceName, $objectName, $objectStartTime, $objectEndTime, $objectDurationMinutes, $objectStatus, $objectLogicalSizeBytes, $objectBytesRead, $objectBytesWritten, $message -join "`t" | Out-File -FilePath $outfileName -Append
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

"`nOutput saved to $outfilename`n"
