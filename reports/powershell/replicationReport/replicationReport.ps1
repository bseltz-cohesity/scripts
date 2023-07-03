### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'MiB',
    [Parameter()][int]$daysBack = 7,
    [Parameter()][Int64]$numRuns = 100,
    [Parameter()][Int64]$backDays = 0
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
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

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$objectFileName = "replicationReport-perObject-$($cluster.name)-$dateString.csv"
"""Job Name"",""Job Type"",""Run Start Time"",""Source Name"",""Replication Delay Sec"",""Replication Duration Sec"",""Logical Replicated $unit"",""Physical Replicated $unit"",""Target Cluster""" | Out-File -FilePath $objectFileName
$runFileName = "replicationReport-perRun-$($cluster.name)-$dateString.csv"
"""Job Name"",""Job Type"",""Run Start Time"",""Replication End Time"",""Entries Changed"",""Logical Replicated $unit"",""Physical Replicated $unit"",""Target Cluster""" | Out-File -FilePath $runFileName

$now = (Get-Date).AddDays(-$backDays)
$daysBackUsecs = dateToUsecs $now.AddDays(-$daysBack)

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $jobId = $job.id
        $jobName = $job.name
        "$jobName"
        $jobType = $job.environment.Substring(1)
        $endUsecs = dateToUsecs $now
        while($True){
            if($endUsecs -le $daysBackUsecs){
                break
            }
            $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=True&numRuns=$numRuns"
            if($runs.runs.Count -gt 0){
                $endUsecs = $runs.runs[-1].localBackupInfo.startTimeUsecs - 1
            }else{
                break
            }
            foreach($run in $runs.runs){
                if($run.PSObject.Properties['originalBackupInfo']){
                    $runStartTimeUsecs = $run.originalBackupInfo.startTimeUsecs
                }else{
                    $runStartTimeUsecs = $run.localBackupInfo.startTimeUsecs
                }
                if($runStartTimeUsecs -lt $daysBackUsecs){
                    break
                }
                # per run stats
                $repls = @{}
                foreach($repl in $run.replicationInfo.replicationTargetResults){
                    $repls[$repl.clusterName] = @{
                        'endTime' = (usecsToDate $repl.endTimeUsecs);
                        'entriesChanged' = $repl.entriesChanged;
                        'logicalReplicated' = 0;
                        'physicalReplicated' = 0;
                    }
                }
                # per object stats
                foreach($server in ($run.objects | Sort-Object -Property {$_.object.name})){
                    $sourceName = $server.object.name
                    if(!($run.environment -eq 'kAD' -and $server.object.objectType -eq 'kDomainController')){
                        if($server.PSObject.Properties['replicationInfo']){
                            foreach($target in $server.replicationInfo.replicationTargetResults){
                                $remoteCluster = $target.clusterName
                                $replicaQueuedTime = $target.queuedTimeUsecs
                                $replicaStartTime = $target.startTimeUsecs
                                $replicaEndTime = $target.endTimeUsecs
                                $replicaDelay = [math]::Round(($replicaStartTime - $replicaQueuedTime) / 1000000)
                                $replicaDuration = [math]::Round(($replicaEndTime - $replicaStartTime) / 1000000)
                                $logicalReplicated = toUnits $target.stats.logicalBytesTransferred
                                $physicalReplicated = toUnits $target.stats.physicalBytesTransferred
                                $repls[$remoteCluster]['logicalReplicated'] += $logicalReplicated
                                $repls[$remoteCluster]['physicalReplicated'] += $physicalReplicated
                                """$jobName"",""$jobType"",""$(usecsToDate $runStartTimeUsecs)"",""$sourceName"",""$replicaDelay"",""$replicaDuration"",""$logicalReplicated"",""$physicalReplicated"",""$remoteCluster""" | Out-File -FilePath $objectFileName -Append
                            }
                        }
                    }
                }
                # per run stats
                foreach($remoteCluster in $repls.Keys){
                    """$jobName"",""$jobType"",""$(usecsToDate $runStartTimeUsecs)"",""$($repls[$remoteCluster]['endTime'])"",""$($repls[$remoteCluster]['entriesChanged'])"",""$($repls[$remoteCluster]['logicalReplicated'])"",""$($repls[$remoteCluster]['physicalReplicated'])"",""$remoteCluster""" | Out-File -FilePath $runFileName -Append
                }
            }
        }
    }
}

"`nOutput saved to:`n    {0}`n    {1}`n" -f $objectFileName, $runFileName
