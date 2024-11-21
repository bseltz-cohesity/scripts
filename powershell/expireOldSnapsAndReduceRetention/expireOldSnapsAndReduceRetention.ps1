# usage: ./expireOldReplicas.ps1 -vip mycluster `
#                                -username myuser `
#                                -domain mydomain.net `
#                                -jobname myjob1, myjob2 `
#                                -daysToKeep 14 `
#                                -expire

# omitting the -expire parameter: the script will only display all the snapshots older than -daysToKeep
# including the -expire parameter: the script will actually expire all the snaps older than -daysToKeep 

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
    [Parameter()][switch]$expire,
    [Parameter()][Int64]$numRuns = 1000,
    [Parameter()][Int64]$daysBack = 0,
    [Parameter()][switch]$skipMonthlies,
    [Parameter()][switch]$skipYearlies
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

# filter on jobname
$jobs = api get protectionJobs
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

# find protectionRuns that are older than daysToKeep
"Searching for old snapshots..."

foreach ($job in $jobs | Sort-Object -Property name) {
    $job.name
    $jobId = $job.id

    $endUsecs = dateToUsecs (Get-Date)
    while($True){
        # paging: get numRuns at a time
        if($endUsecs -le $daysBackUsecs){
            break
        }
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true&excludeNonRestoreableRuns=true" | Where-Object {$_.backupRun.stats.endTimeUsecs -lt $endUsecs}
        if($runs){
            $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs
        }else{
            break
        }
        # runs with undeleted snapshots
        foreach ($run in $runs | Where-Object{$_.backupRun.snapshotsDeleted -ne $True -and ($_.backupRun.runType -eq $backupType -or $backupType -eq 'kAll')}){
            if($run.backupRun.stats.startTimeUsecs -le $daysBackUsecs){
                break
            }
            $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
            $startdateusecs = $run.copyRun[0].runStartTimeUsecs
            if((! $skipMonthlies -or $startdate.Day -ne 1) -and (! $skipYearlies -or $startdate.DayOfYear -ne 1)){
                if ($startdateusecs -lt $daysToKeepUsecs) {
                    ### if -expire switch is set, expire the local snapshot
                    if ($expire) {
                        $exactRun = api get /backupjobruns?exactMatchStartTimeUsecs=$startdateusecs`&id=$jobId
                        $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                        ### expire the snapshot
                        "    Expiring $($job.name) Snapshot from $startdate"
                        $expireRun = @{'jobRuns' = @(
                                @{'expiryTimeUsecs'     = 0;
                                    'jobUid'            = @{
                                        'clusterId' = $jobUid.clusterId;
                                        'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                                        'id' = $jobUid.objectId;
                                    }
                                    'runStartTimeUsecs' = $startdateusecs;
                                    'copyRunTargets'    = @(
                                        @{'daysToKeep' = 0;
                                            'type'     = 'kLocal';
                                        }
                                    )
                                }
                            )
                        }
                        $null = api put protectionRuns $expireRun
                    }else{
                        ### just print old snapshots if we're not expiring
                        "    Would expire $($job.name) $($startdate)"
                    }
                }else{
                    $newExpiryUsecs = [int64](dateToUsecs $startdate.addDays($daysToKeep))
                    if($run.copyRun[0].expiryTimeUsecs -gt ($newExpiryUsecs + 86400000000)){
                        $reduceByDays = [int64][math]::floor(($run.copyRun[0].expiryTimeUsecs - $newExpiryUsecs) / 86400000000)
                        ### if -expire is set, reduce the retention
                        if ($expire -and $reduceByDays -ge 1) {
                            $exactRun = api get /backupjobruns?exactMatchStartTimeUsecs=$startdateusecs`&id=$jobId
                            $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                            ### edit the snapshot
                            "    Reducing retention for $($job.name) Snapshot from $startdate"
                            $editRun = @{'jobRuns' = @(
                                    @{
                                        'jobUid'            = @{
                                            'clusterId' = $jobUid.clusterId;
                                            'clusterIncarnationId' = $jobUid.clusterIncarnationId;
                                            'id' = $jobUid.objectId;
                                        }
                                        'runStartTimeUsecs' = $startdateusecs;
                                        'copyRunTargets'    = @(
                                            @{'daysToKeep' = -$reduceByDays;
                                                'type'     = 'kLocal';
                                            }
                                        )
                                    }
                                )
                            }
                            $null = api put protectionRuns $editRun
                        }else{
                            ### just print snapshots we would expire
                            "    Would reduce $($job.name) $($startdate) by $reduceByDays days"
                        }    
                    }
                }
            }else{
                if($skipYearlies -and $startdate.DayOfYear -eq 1){
                    "    Skipping yearly $($job.name) $($startdate)"
                }else{
                    "    Skipping monthly $($job.name) $($startdate)"
                }
            }
        }
    }
}
