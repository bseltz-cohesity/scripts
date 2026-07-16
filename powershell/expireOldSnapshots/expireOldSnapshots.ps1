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
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$jobname = $null,
    [Parameter(Mandatory = $True)][string]$daysToKeep,
    [Parameter()][ValidateSet("kRegular","kFull","kLog","kSystem","kAll")][string]$backupType = 'kAll',
    [Parameter()][switch]$commit,
    [Parameter()][Int64]$numRuns = 1000,
    [Parameter()][Int64]$daysBack = 0,
    [Parameter()][switch]$skipWeeklies,
    [Parameter()][switch]$skipMonthlies,
    [Parameter()][switch]$skipYearlies,
    [Parameter()][switch]$localOnly,
    [Parameter()][switch]$replicasOnly,
    [Parameter()][switch]$reduceYoungerSnapshots,
    [Parameter()][switch]$skipIfNoReplicas,
    [Parameter()][switch]$skipIfNoArchives
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

# filter on jobname (V2 protection groups API)
if($localOnly){
    $jobs = (api get -v2 "data-protect/protection-groups?isActive=true").protectionGroups
}elseif($replicasOnly){
    $jobs = (api get -v2 "data-protect/protection-groups?isActive=false").protectionGroups
}else{
    $jobs = (api get -v2 "data-protect/protection-groups").protectionGroups
}
$jobs = $jobs | Where-Object {$_.isDeleted -ne $True}

if($jobname){
    $jobs = $jobs | Where-Object { $_.name -in $jobname }
    $notfoundJobs = $jobname | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$cluster = api get cluster
if($daysBack -gt 0){
    $daysBackUsecs = dateToUsecs (get-date).AddDays(-$daysBack)
}else{
    $daysBackUsecs = ($cluster.createdTimeMsecs * 1000)
}

$daysToKeepUsecs = timeAgo $daysToKeep days

# a run backed up directly on this cluster has 'localBackupInfo'; a run replicated in from
# another cluster has 'originalBackupInfo' instead (no 'localBackupInfo' at all)
function getRunBackupInfo($run){
    if($run.PSObject.Properties['localBackupInfo'] -and $run.localBackupInfo){
        return $run.localBackupInfo
    }elseif($run.PSObject.Properties['originalBackupInfo'] -and $run.originalBackupInfo){
        return $run.originalBackupInfo
    }else{
        return $null
    }
}

# same local/replicated split applies per-object: 'localSnapshotInfo' for locally backed up
# objects, 'originalBackupInfo' for objects that arrived via replication
function getObjectExpiry($object){
    if($object.PSObject.Properties['localSnapshotInfo'] -and $object.localSnapshotInfo -and $object.localSnapshotInfo.snapshotInfo -and $null -ne $object.localSnapshotInfo.snapshotInfo.expiryTimeUsecs){
        return $object.localSnapshotInfo.snapshotInfo.expiryTimeUsecs
    }elseif($object.PSObject.Properties['originalBackupInfo'] -and $object.originalBackupInfo -and $object.originalBackupInfo.snapshotInfo -and $null -ne $object.originalBackupInfo.snapshotInfo.expiryTimeUsecs){
        return $object.originalBackupInfo.snapshotInfo.expiryTimeUsecs
    }else{
        return $null
    }
}

# current expiry lives per-object (there's no run-level expiry field in V2) - all objects in
# a run share the same retention, so the first object with a valid expiry is representative
function getCurrentExpiry($run){
    foreach($object in $run.objects){
        $expiry = getObjectExpiry $object
        if($null -ne $expiry){
            return $expiry
        }
    }
    return $null
}

# find protectionRuns that are older than daysToKeep
Write-Host "Searching for old snapshots..."

$foundSnapsToProcess = $False

foreach ($job in $jobs | Sort-Object -Property name) {
    $job.name
    $jobUrlId = $job.id
    $endUsecs = dateToUsecs (Get-Date)

    Get-Runs -jobId $job.id -numRuns $numRuns -endTimeUsecs $endUsecs -startTimeUsecs $daysBackUsecs -includeObjectDetails | Where-Object{
        $backupInfo = getRunBackupInfo $_
        $backupInfo -and $_.isLocalSnapshotsDeleted -ne $True -and ($backupInfo.runType -eq $backupType -or $backupType -eq 'kAll')
    } | ForEach-Object {
        $run = $_
        $backupInfo = getRunBackupInfo $run
        if($backupInfo.startTimeUsecs -le $daysBackUsecs){
            break
        }
        $startdate = usecstodate $backupInfo.startTimeUsecs
        $startdateusecs = $backupInfo.startTimeUsecs
        if((! $skipMonthlies -or $startdate.Day -ne 1) -and (! $skipYearlies -or $startdate.DayOfYear -ne 1) -and (! $skipWeeklies -or $startdate.DayOfWeek -ne 'Sunday')){
            if ($startdateusecs -lt $daysToKeepUsecs) {
                # check for replicas/archives
                $skipNoReplicas = $False
                $skipNoArchives = $False
                if($skipIfNoReplicas -or $skipIfNoArchives){
                    if($skipIfNoReplicas){
                        $skipNoReplicas = $True
                    }
                    if($skipIfNoArchives){
                        $skipNoArchives = $True
                    }
                    foreach($replicaResult in $run.replicationInfo.replicationTargetResults){
                        if($replicaResult.status -eq 'Succeeded' -and $replicaResult.expiryTimeUsecs -gt $endUsecs){
                            $skipNoReplicas = $False
                        }
                    }
                    foreach($archiveResult in $run.archivalInfo.archivalTargetResults){
                        if($archiveResult.status -eq 'Succeeded' -and $archiveResult.expiryTimeUsecs -gt $endUsecs){
                            $skipNoArchives = $False
                        }
                    }
                    if($skipIfNoReplicas){
                        if($skipNoReplicas -eq $True){
                            Write-Host "    Skipping $($job.name) $($startdate) (not replicated)"
                        }
                    }elseif($skipIfNoArchives){
                        if($skipNoArchives -eq $True){
                             Write-Host "    Skipping $($job.name) $($startdate) (not archived)"
                        }
                    }
                }
                if($skipNoArchives -eq $False -and $skipNoReplicas -eq $False){
                    # if -commit switch is set, expire the snapshot
                    if ($commit) {
                        Write-Host "    Expiring $($job.name) Snapshot from $startdate"
                        $expireRun = @{
                            'updateProtectionGroupRunParams' = @(
                                @{
                                    'runId'                     = $run.id;
                                    'replicationSnapshotConfig' = @{};
                                    'localSnapshotConfig'       = @{
                                        'deleteSnapshot' = $True
                                    }
                                }
                            )
                        }
                        try{
                            $null = api put -v2 "data-protect/protection-groups/$jobUrlId/runs" $expireRun
                        }catch{
                            Write-Host "    Error While Expiring $($job.name) Snapshot from $startdate" -ForegroundColor Yellow
                        }
                    }else{
                        # just print old snapshots if we're not expiring
                        Write-Host "    Would expire $($job.name) $($startdate)"
                        $foundSnapsToProcess = $True
                    }
                }
            }elseif($reduceYoungerSnapshots){
                $currentExpireUsecs = getCurrentExpiry $run
                if($null -eq $currentExpireUsecs){
                    Write-Host "    No snapshot expiry found for $($job.name) $($startdate) - skipping" -ForegroundColor Yellow
                }else{
                    $newExpiryUsecs = [int64](dateToUsecs $startdate.addDays($daysToKeep))
                    if($currentExpireUsecs -gt ($newExpiryUsecs + 86400000000)){
                        $reduceByDays = [int64][math]::floor(($currentExpireUsecs - $newExpiryUsecs) / 86400000000)
                        # if -commit switch is set, reduce the retention
                        if ($commit -and $reduceByDays -ge 1) {
                            Write-Host "    Reducing retention for $($job.name) Snapshot from $startdate"
                            $editRun = @{
                                'updateProtectionGroupRunParams' = @(
                                    @{
                                        'runId'                     = $run.id;
                                        'replicationSnapshotConfig' = @{};
                                        'localSnapshotConfig'       = @{
                                            'daysToKeep' = -$reduceByDays
                                        }
                                    }
                                )
                            }
                            $null = api put -v2 "data-protect/protection-groups/$jobUrlId/runs" $editRun
                        }else{
                            # just print snapshots we would reduce
                            Write-Host "    Would reduce $($job.name) $($startdate) by $reduceByDays days"
                            $foundSnapsToProcess = $True
                        }
                    }
                }
            }
        }else{
            if($skipYearlies -and $startdate.DayOfYear -eq 1){
                Write-Host "    Skipping yearly $($job.name) $($startdate)"
            }elseif($skipMonthlies -and $startdate.Day -eq 1){
                Write-Host "    Skipping monthly $($job.name) $($startdate)"
            }else{
                Write-Host "    Skipping weekly $($job.name) $($startdate)"
            }
        }
    }
}
if($foundSnapsToProcess -eq $True){
    Write-Host "`nNo changes applied. Use -commit to apply changes`n" -ForegroundColor Yellow
}