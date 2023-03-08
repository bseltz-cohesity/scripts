### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter(Mandatory = $True)][string]$replicateTo, # name of replication target
    [Parameter()][int]$olderThan = 0, # archive snapshots older than x days
    [Parameter()][string]$IfExpiringAfter = -1, # do not archve if the snapshot is going to expire within x days
    [Parameter()][string]$keepFor = 0, # set archive retention to x days from original backup date
    [Parameter()][switch]$replicate, # actually replicate (otherwise test run)
    [Parameter()][int]$newerThan,
    [Parameter()][switch]$resync,
    [Parameter()][switch]$includeLogs,
    [Parameter()][int]$numRuns = 1000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

$jobs = api get "protectionJobs"

# catch invalid job names
if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

### cluster Id
$cluster = api get cluster
$clusterId = $cluster.id

### get replication target info
$remote = api get remoteClusters | Where-Object {$_.name -eq $replicateTo}
if(!$remote){
    Write-Warning "Replication target $replicateTo not found"
    exit
}

### olderThan days in usecs
$olderThanUsecs = timeAgo $olderThan days
if($newerThan){
    $newerThanUsecs = timeAgo $newerThan days
}else{
    $newerThanUsecs = $cluster.createdTimeMsecs * 1000
}

### find protectionRuns with old local snapshots that are not archived yet and sort oldest to newest
"searching for old snapshots..."
foreach($job in $jobs | Sort-Object -Property name| Where-Object {$_.isDeleted -ne $true}){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        Write-Host $job.name
        $theseRuns = @{}
        $endUsecs = $olderThanUsecs
        while($True){
            $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&startTimeUsecs=$newerThanUsecs&excludeTasks=true"
            if($runs.Count -gt 0){
                $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs - 1
            }else{
                break
            }
            # filter on expired and run type
            $runs = $runs | Where-Object {$_.backupRun.snapshotsDeleted -eq $false}
            if(!$includeLogs){
                $runs = $runs | Where-Object {$_.backupRun.runType -ne 'kLog'}
            }
            foreach($run in $runs){
                ### determine if replica already exists
                $alreadyReplicated = $false
                foreach($copyRun in $run.copyRun){
                    if($copyRun.target.type -eq 'kRemote'){
                        if($copyRun.target.replicationTarget.clusterName -eq $replicateTo){
                            if($copyRun.status -eq 'kSuccess' -and $copyRun.expiryTimeUsecs -ne 0){
                                $alreadyReplicated = $True
                            }
                            if($copyRun.status -eq 'kRunning' -or $copyRun.status -eq 'kAccepted'){
                                $alreadyReplicated = $True
                            }
                        }
                    }
                }

                $runDate = usecsToDate $run.copyRun[0].runStartTimeUsecs
                $thisJobName = $run.jobName

                if($alreadyReplicated -eq $false){

                    ### calculate daysToKeep
                    $startTimeUsecs = $run.backupRun.stats.startTimeUsecs

                    if($keepFor -gt 0){
                        $expireTimeUsecs = $startTimeUsecs + ([int]$keepFor * 86400000000)
                    }else{
                        $expireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
                    }
                    $now = dateToUsecs $(get-date)
                    $daysToKeep = [math]::Round(($expireTimeUsecs - $now) / 86400000000) + 1
                    if($daysToKeep -eq 0){
                        $daysToKeep = 1
                    }

                    ### create replication task definition
                    $replicationTask = @{
                        'jobRuns' = @(
                            @{
                                'copyRunTargets'    = @(
                                    @{
                                        "replicationTarget" = @{
                                            "clusterId" = $remote.clusterId;
                                            "clusterName" = $remote.name
                                        };
                                        'daysToKeep'     = [int] $daysToKeep;
                                        'type'           = 'kRemote'
                                    }
                                );
                                'runStartTimeUsecs' = $run.copyRun[0].runStartTimeUsecs;
                                'jobUid'            = $run.jobUid
                            }
                        )
                    }
        
                    ### If the Local Snapshot is not expiring soon...
                    if($daysToKeep -gt $IfExpiringAfter){
                        if($replicate){
                            Write-Host "    $runDate  (will replicate for $daysToKeep days)" -ForegroundColor Green
                            $theseRuns["$startTimeUsecs"] = $replicationTask
                        }
                        else {
                            Write-Host "    $runDate  (would replicate for $daysToKeep days)" -ForegroundColor Green
                        }
                    }
                    else {
                        Write-Host "    $runDate  (skipping, expiring in $daysToKeep days)" -ForegroundColor Gray
                    }
                }else{
                    if($resync){
                        ### create replication task definition
                        $replicationTask = @{
                            'jobRuns' = @(
                                @{
                                    'copyRunTargets'    = @(
                                        @{
                                            "replicationTarget" = @{
                                                "clusterId" = $remote.clusterId;
                                                "clusterName" = $remote.name
                                            };
                                            'type'           = 'kRemote'
                                        }
                                    );
                                    'runStartTimeUsecs' = $run.copyRun[0].runStartTimeUsecs;
                                    'jobUid'            = $run.jobUid
                                }
                            )
                        }
                        if($replicate){
                            Write-Host "    $runDate  (will resync)" -ForegroundColor Green
                            $theseRuns["$startTimeUsecs"] = $replicationTask
                        }else{
                            Write-Host "    $runDate  (would resync)" -ForegroundColor Green
                        }
                    }else{
                        Write-Host "    $runDate  (already replicated)" -ForegroundColor Blue
                    }
                }
            }
        }
        if($theseRuns.Keys.Count -gt 0){
            Write-Host "    Performing replications in time order..."
        }
        foreach($startTimeUsecs in $theseRuns.Keys | sort){
            Write-Host "        $(usecsToDate $startTimeUsecs)"
            $null = api put protectionRuns $theseRuns["$startTimeUsecs"]
        }
    }
}
