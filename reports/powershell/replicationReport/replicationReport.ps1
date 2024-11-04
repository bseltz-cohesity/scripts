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
    [Parameter()][Int64]$numRuns = 1000,
    [Parameter()][string]$outputPath = '.',
    [Parameter()][array]$environment,
    [Parameter()][array]$excludeEnvironment
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
$objectFileName = $(Join-Path -Path $outputPath -ChildPath "replicationReport-perObject-$($cluster.name)-$dateString.csv")
"""Job Name"",""Job Type"",""Run Start Time"",""Source Name"",""Replication Delay Sec"",""Replication Duration Sec"",""Logical Replicated $unit"",""Physical Replicated $unit"",""Status"",""Target Cluster"",""Percent Completed""" | Out-File -FilePath $objectFileName
$runFileName = $(Join-Path -Path $outputPath -ChildPath "replicationReport-perRun-$($cluster.name)-$dateString.csv")
"""Job Name"",""Job Type"",""Run Start Time"",""Replication Start Time"",""Replication End Time"",""Replication Duration (Sec)"",""Entries Changed"",""Logical Replicated $unit"",""Physical Replicated $unit"",""Status"",""Target Cluster""" | Out-File -FilePath $runFileName
$dayFileName = $(Join-Path -Path $outputPath -ChildPath "replicationReport-perDay-$($cluster.name)-$dateString.csv")
"""Job Name"",""Job Type"",""Day"",""Replication Duration (Sec)"",""Logical Replicated $unit"",""Physical Replicated $unit"",""Target Cluster""" | Out-File -FilePath $dayFileName
$jobFileName = $(Join-Path -Path $outputPath -ChildPath "replicationReport-perJob-$($cluster.name)-$dateString.csv")
"""Job Name"",""Job Type"",""Max Replication Duration (Sec)"",""Avg Replication Duration (Sec)"",""Max Logical Replicated $unit"",""Avg Logical Replicated $unit"",""Max Physical Replicated $unit"",""Avg Physical Replicated $unit"",""Target Cluster""" | Out-File -FilePath $jobFileName

$now = Get-Date  # -Hour 0 -Minute 0 -Second 0
$nowUsecs = dateToUsecs $now
$midnight = Get-Date -Hour 0 -Minute 0 -Second 0
$daysBackUsecs = dateToUsecs $midnight.AddDays(-$daysBack)

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $jobId = $job.id
        $jobName = $job.name
        $jobType = $job.environment.Substring(1)
        if($environment -and ($job.environment -notin $environment -and $jobType -notin $environment)){
            continue
        }
        if($excludeEnvironment -and ($job.environment -in $excludeEnvironment -or $jobType -in $excludeEnvironment)){
            continue
        }
        "$jobName"
        $endUsecs = $nowUsecs
        while($True){
            if($endUsecs -le $daysBackUsecs){
                break
            }
            $runs = api get -v2 "data-protect/protection-groups/$jobId/runs?startTimeUsecs=$daysBackUsecs&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=True&numRuns=$numRuns"
            if($runs.runs.Count -gt 0){
                $endUsecs = $runs.runs[-1].localBackupInfo.startTimeUsecs - 1
            }else{
                break
            }
            # per day stats
            $perDayRepls = @{}
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
                    if($repl.PSObject.Properties['endTimeUsecs']){
                        $endTimeUsecs = $repl.endTimeUsecs
                    }else{
                        $endTimeUsecs = $nowUsecs
                    }
                    $repls[$repl.clusterName] = @{
                        'startTimeUsecs' = $null;
                        'endTimeUsecs' = $endTimeUsecs;
                        'entriesChanged' = $repl.entriesChanged;
                        'logicalReplicated' = 0;
                        'physicalReplicated' = 0;
                        'status' = $repl.status
                    }
                    # if($repl.status -ne 'Succeeded'){
                    #     $repl | ConvertTo-Json -Depth 99
                    # }
                }
                # per object stats
                foreach($server in ($run.objects | Sort-Object -Property {$_.object.name})){
                    $sourceName = $server.object.name
                    if(!($run.environment -eq 'kAD' -and $server.object.objectType -eq 'kDomainController')){
                        if($server.PSObject.Properties['replicationInfo']){
                            foreach($target in $server.replicationInfo.replicationTargetResults){
                                $status = $target.status
                                # if($status -ne 'Succeeded'){
                                #     $target | ConvertTo-Json -Depth 99
                                # }
                                if($target.PSObject.Properties['percentageCompleted']){
                                    $percentCompleted = $target.percentageCompleted
                                }else{
                                    $percentCompleted = 0
                                }
                                $remoteCluster = $target.clusterName
                                $replicaQueuedTime = $target.queuedTimeUsecs
                                if($target.PSObject.Properties['startTimeUsecs']){
                                    $replicaStartTime = $target.startTimeUsecs
                                }else{
                                    $replicaStartTime = $nowUsecs
                                }
                                if($target.PSObject.Properties['endTimeUsecs']){
                                    $replicaEndTime = $target.endTimeUsecs
                                }else{
                                    $replicaEndTime = $nowUsecs
                                }
                                # $replicaEndTime = $target.endTimeUsecs
                                $replicaDelay = [math]::Round(($replicaStartTime - $replicaQueuedTime) / 1000000)
                                $replicaDuration = [math]::Round(($replicaEndTime - $replicaStartTime) / 1000000)
                                $logicalReplicated = toUnits $target.stats.logicalBytesTransferred
                                $physicalReplicated = toUnits $target.stats.physicalBytesTransferred
                                $repls[$remoteCluster]['logicalReplicated'] += $logicalReplicated
                                $repls[$remoteCluster]['physicalReplicated'] += $physicalReplicated
                                if($repls[$remoteCluster]['startTimeUsecs'] -eq $null -or $replicaStartTime -lt $repls[$remoteCluster]['startTimeUsecs']){
                                    $repls[$remoteCluster]['startTimeUsecs'] = $replicaStartTime
                                }
                                """$jobName"",""$jobType"",""$(usecsToDate $runStartTimeUsecs)"",""$sourceName"",""$replicaDelay"",""$replicaDuration"",""$logicalReplicated"",""$physicalReplicated"",""$status"",""$remoteCluster"",""$percentCompleted""" | Out-File -FilePath $objectFileName -Append
                            }
                        }
                    }
                }
                # per run stats
                foreach($remoteCluster in $repls.Keys){
                    if($repls[$remoteCluster]['status'] -eq 'Succeeded' -and $repls[$remoteCluster]['startTimeUsecs'] -ne $null){
                        $replicaDuration = [math]::Round(($repls[$remoteCluster]['endTimeUsecs'] - $repls[$remoteCluster]['startTimeUsecs']) / 1000000, 0)
                        """$jobName"",""$jobType"",""$(usecsToDate $runStartTimeUsecs)"",""$(usecsToDate $repls[$remoteCluster]['startTimeUsecs'])"",""$(usecsToDate $repls[$remoteCluster]['endTimeUsecs'])"",""$replicaDuration"",""$($repls[$remoteCluster]['entriesChanged'])"",""$($repls[$remoteCluster]['logicalReplicated'])"",""$($repls[$remoteCluster]['physicalReplicated'])"",""$($repls[$remoteCluster]['status'])"",""$remoteCluster""" | Out-File -FilePath $runFileName -Append
                        # per day stats
                        $replDay = usecsToDate $repls[$remoteCluster]['startTimeUsecs'] -format 'yyyy-MM-dd'
                        if($remoteCluster -notin $perDayRepls.Keys){
                            $perDayRepls[$remoteCluster] = @{}
                        }
                        if($replDay -notin $perDayRepls[$remoteCluster].Keys){
                            $perDayRepls[$remoteCluster][$replDay] = @{
                                'duration' = 0;
                                'logicalReplicated' = 0;
                                'physicalReplicated' = 0
                            }
                        }
                        $perDayRepls[$remoteCluster][$replDay]['duration'] += $replicaDuration
                        $perDayRepls[$remoteCluster][$replDay]['logicalReplicated'] += $repls[$remoteCluster]['logicalReplicated']
                        $perDayRepls[$remoteCluster][$replDay]['physicalReplicated'] += $repls[$remoteCluster]['physicalReplicated']
                    }else{
                        if($repls[$remoteCluster]['startTimeUsecs'] -eq $null){
                            $replStartTime = $nowUsecs
                        }else{
                            $replStartTime = $repls[$remoteCluster]['startTimeUsecs']
                        }
                        $replicaDuration = [math]::Round(($repls[$remoteCluster]['endTimeUsecs'] - $replStartTime) / 1000000, 0)
                        $endTime = usecsToDate $repls[$remoteCluster]['endTimeUsecs']
                        if($repls[$remoteCluster]['status'] -in @('Accepted', 'Running')){
                            $endTime = ''
                        }
                        """$jobName"",""$jobType"",""$(usecsToDate $runStartTimeUsecs)"",""$(usecsToDate $replStartTime)"",""$($endTime)"",""$replicaDuration"",""$($repls[$remoteCluster]['entriesChanged'])"",""$($repls[$remoteCluster]['logicalReplicated'])"",""$($repls[$remoteCluster]['physicalReplicated'])"",""$($repls[$remoteCluster]['status'])"",""$remoteCluster""" | Out-File -FilePath $runFileName -Append
                    }
                }
            }
            if($runs.runs.Count -lt $numRuns){
                break
            }
        }
        # per day stats
        foreach($remoteCluster in $perDayRepls.Keys | Sort-Object){
            # per job stats
            $maxDuration = 0
            $totalDuration = 0
            $days = 0
            $maxLogical = 0
            $totalLogical = 0
            $maxPhysical = 0
            $totalPhysical = 0
            foreach($day in $perDayRepls[$remoteCluster].Keys | Sort-Object -Descending){
                # per day stats
                """$jobName"",""$jobType"",""$day"",""$($perDayRepls[$remoteCluster][$day]['duration'])"",""$($perDayRepls[$remoteCluster][$day]['logicalReplicated'])"",""$($perDayRepls[$remoteCluster][$day]['physicalReplicated'])"",""$remoteCluster""" | Out-File -FilePath $dayFileName -Append
                # per job stats
                $totalDuration += $perDayRepls[$remoteCluster][$day]['duration']
                $totalLogical += $perDayRepls[$remoteCluster][$day]['logicalReplicated']
                $totalPhysical += $perDayRepls[$remoteCluster][$day]['physicalReplicated']
                if($perDayRepls[$remoteCluster][$day]['duration'] -gt $maxDuration){
                    $maxDuration = $perDayRepls[$remoteCluster][$day]['duration']
                }
                if($perDayRepls[$remoteCluster][$day]['logicalReplicated'] -gt $maxLogical){
                    $maxLogical = $perDayRepls[$remoteCluster][$day]['logicalReplicated']
                }
                if($perDayRepls[$remoteCluster][$day]['physicalReplicated'] -gt $maxPhysical){
                    $maxPhysical = $perDayRepls[$remoteCluster][$day]['physicalReplicated']
                }
                $days += 1
            }
            # per job stats
            $avgDuration = [math]::Round($totalDuration / $days, 0)
            $avgLogical = [math]::Round($totalLogical / $days, 1)
            $avgPhysical = [math]::Round($totalPhysical / $days, 1)
            """$jobName"",""$jobType"",""$maxDuration"",""$avgDuration"",""$maxLogical"",""$avgLogical"",""$maxPhysical"",""$avgPhysical"",""$remoteCluster""" | Out-File -FilePath $jobFileName -Append
        }
    }
}

"`nOutput saved to:`n    {0}`n    {1}`n    {2}`n    {3}`n" -f $objectFileName, $runFileName, $dayFileName, $jobFileName
