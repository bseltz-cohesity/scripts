# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][array]$clusterName = $null,
    [Parameter()][int]$days,
    [Parameter()][switch]$includeObjectDetails,
    [Parameter()][switch]$includeLogs,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
    [Parameter()][int]$numRuns = 100
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

if($days){
    $daysBack = (Get-Date).AddDays(-$days)
    $daysBackUsecs = dateToUsecs $daysBack
}

# outfile
$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "heliosProtectionRunsReport-$dateString.tsv"

# headings
$headings = "Cluster Name
Tenant
Job Name
Environment
Policy Name
Run Type
Run Start Time
Run End Time
Duration (Min)
Run Status
Logical ($unit)
Read ($unit)
Written ($unit)"

if($includeObjectDetails){
   $headings = "Cluster Name
Tenant
Job Name
Environment
Policy Name
Run Type
Run Start Time
Registered Source
Object Name
Start Time
End Time
Duration (Min)
Status
Logical ($unit)
Read ($unit)
Written ($unit)"
}
$headings = $headings -split "`n" -join "`t"
$headings | Out-File -FilePath $outfileName -Encoding utf8


# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

if(! $clusterName){
    $clusterName = (heliosClusters).name
}

foreach($c in $clusterName){
    heliosCluster $c
    $cluster = api get cluster
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"
    $sources = api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false
    $policies = api get -v2 data-protect/policies

    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $endUsecs = dateToUsecs (Get-Date)
        if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
            $environment = $job.environment.subString(1)
            $tenant = $job.permissions.name
            "{0} ({1})" -f $job.name, $environment
            $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
            while($True){
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true"
                foreach($run in $runs.runs){
                    if((! $includeObjectDetails -or ! $run.PSObject.Properties['isLocalSnapshotsDeleted'])){
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
                            $status = $run.localBackupInfo.status
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
                                $cluster.name, $tenant, $job.name, $environment, $policyName, $runType, $runStartTime, $runEndTime, $durationMinutes, $status, $logicalSizeBytes, $bytesRead, $bytesWritten -join "`t" | Out-File -FilePath $outfileName -Append
                            }
                            # object level stats
                            if($includeObjectDetails -and ! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
                                foreach($object in $run.objects){
                                    $objectName = $object.object.name
                                    if($environment -notin @('Oracle', 'SQL') -or ($environment -in @('Oracle', 'SQL') -and $object.object.objectType -ne 'kHost')){
                                        if($object.object.PSObject.Properties['sourceId']){
                                            $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
                                            $registeredSourceName = $registeredSource.rootNode.name
                                        }else{
                                            $registeredSourceName = $objectName
                                        }
                                        $objectStatus = $object.localSnapshotInfo.snapshotInfo.status.subString(1)
                                        $objectStartTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.startTimeUsecs
                                        $objectEndTime = $null
                                        $objectDurationMinutes = "{0:n0}" -f ($now - $objectStartTime).totalMinutes
                                        if($object.localSnapshotInfo.snapshotInfo.PSObject.Properties['endTimeUsecs']){
                                            $objectEndTime = usecsToDate $object.localSnapshotInfo.snapshotInfo.endTimeUsecs
                                            $objectDurationMinutes = "{0:n0}" -f ($objectEndTime - $objectStartTime).totalMinutes
                                        }
                                        $objectLogicalSizeBytes = toUnits $object.localSnapshotInfo.snapshotInfo.stats.logicalSizeBytes
                                        $objectBytesWritten = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesWritten
                                        $objectBytesRead = toUnits $object.localSnapshotInfo.snapshotInfo.stats.bytesRead
                                        "        {0}" -f $objectName
                                        # write to output file
                                        $cluster.name, $tenant, $job.name, $environment, $policyName, $runType, $runStartTime, $registeredSourceName, $objectName, $objectStartTime, $objectEndTime, $objectDurationMinutes, $objectStatus, $objectLogicalSizeBytes, $objectBytesRead, $objectBytesWritten -join "`t" | Out-File -FilePath $outfileName -Append
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
