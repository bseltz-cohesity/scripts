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

# filter on jobname
if($localOnly){
    $jobs = api get protectionJobs?isActive=true
}elseif($replicasOnly){
    $jobs = api get protectionJobs?isActive=false
}else{
    $jobs = api get protectionJobs
}

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
Write-Host "Searching for old snapshots..."

$foundSnapsToProcess = $False

foreach ($job in $jobs | Sort-Object -Property name) {
    $job.name
    $jobId = $job.id
    $endUsecs = dateToUsecs (Get-Date)

    Get-Runs -jobId $job.id -numRuns $numRuns -endTimeUsecs $endUsecs -startTimeUsecs $daysBackUsecs | Where-Object{$_.backupRun.snapshotsDeleted -ne $True -and ($_.backupRun.runType -eq $backupType -or $backupType -eq 'kAll')} | ForEach-Object {
        $run = $_
        if($run.backupRun.stats.startTimeUsecs -le $daysBackUsecs){
            break
        }
        $startdate = usecstodate $run.copyRun[0].runStartTimeUsecs
        $startdateusecs = $run.copyRun[0].runStartTimeUsecs
        if((! $skipMonthlies -or $startdate.Day -ne 1) -and (! $skipYearlies -or $startdate.DayOfYear -ne 1) -and (! $skipWeeklies -or $startdate.DayOfWeek -ne 'Sunday')){
            if ($startdateusecs -lt $daysToKeepUsecs) {
                # check for replicas/archvies
                $skipNoReplicas = $False
                $skipNoArchives = $False
                if($skipIfNoReplicas -or $skipIfNoArchives){
                    if($skipIfNoReplicas){
                        $skipNoReplicas = $True
                    }
                    if($skipIfNoArchives){
                        $skipNoArchives = $True
                    }
                    foreach($copyRun in $run.copyRun){
                        if($copyRun.target.type -eq 'kRemote' -and $copyRun.status -eq 'kSuccess' -and $copyRun.expiryTimeUsecs -gt $endUsecs){
                            $skipNoReplicas = $False
                        }
                        if($copyRun.target.type -eq 'kArchival' -and $copyRun.status -eq 'kSuccess' -and $copyRun.expiryTimeUsecs -gt $endUsecs){
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
                    # if -commit switch is set, expire the local snapshot
                    if ($commit) {
                        $exactRun = api get "/backupjobruns?exactMatchStartTimeUsecs=$startdateusecs&id=$jobId&excludeTasks=true"
                        try{
                            $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                            Write-Host "    Expiring $($job.name) Snapshot from $startdate"
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
                $newExpiryUsecs = [int64](dateToUsecs $startdate.addDays($daysToKeep))
                if($run.copyRun[0].expiryTimeUsecs -gt ($newExpiryUsecs + 86400000000)){
                    $reduceByDays = [int64][math]::floor(($run.copyRun[0].expiryTimeUsecs - $newExpiryUsecs) / 86400000000)
                    # if -commit switch is set, reduce the retention
                    if ($commit -and $reduceByDays -ge 1) {
                        $exactRun = api get "/backupjobruns?exactMatchStartTimeUsecs=$startdateusecs&id=$jobId&excludeTasks=true"
                        $jobUid = $exactRun[0].backupJobRuns.protectionRuns[0].backupRun.base.jobUid
                        Write-Host "    Reducing retention for $($job.name) Snapshot from $startdate"
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
                        # just print snapshots we would expire
                        Write-Host "    Would reduce $($job.name) $($startdate) by $reduceByDays days"
                        $foundSnapsToProcess = $True
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