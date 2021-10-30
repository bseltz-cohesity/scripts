[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$days = 7
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-sqlProtectedObjectReport-$dateString.csv"

"Cluster Name,Job Name,Environment,Object Name,Object Type,Parent,Policy Name,Frequency (Minutes),Run Type,Status,Start Time,End Time,Duration (Minutes),Expires,Job Paused" | Out-File -FilePath $outfileName

$policies = api get -v2 "data-protect/policies"
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kSQL"
$sources = api get protectionSources

$objects = @{}

"`nGathering Job Info from $($cluster.name)..."
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    "    $($job.name)"
    $policy = $policies.policies | Where-Object id -eq $job.policyId
    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?includeObjectDetails=true&startTimeUsecs=$(timeAgo $days days)&numRuns=1000"
    if('kLog' -in $runs.runs.localBackupInfo.runType){
        $runDates = ($runs.runs | Where-Object {$_.localBackupInfo.runType -eq 'kLog'}).localBackupInfo.startTimeUsecs
    }else{
        $runDates = $runs.runs.localBackupInfo.startTimeUsecs
    }
    foreach($run in $runs.runs){
        foreach($thisobject in $run.objects){
            $object = $thisobject.object
            $localSnapshotInfo = $thisobject.localSnapshotInfo
            if($object.id -notin $objects.Keys){
                $objects[$object.id] = @{
                    'name' = $object.name;
                    'id' = $object.id;
                    'objectType' = $object.objectType;
                    'environment' = $object.environment;
                    'jobName' = $job.name;
                    'policyName' = $policy.name;
                    'jobEnvironment' = $job.environment;
                    'runDates' = $runDates;
                    'sourceId' = '';
                    'parent' = '';
                    'runs' = New-Object System.Collections.Generic.List[System.Object];              
                    'jobPaused' = $job.isPaused;
                    
                }
                if($object.PSObject.Properties['sourceId']){
                    $objects[$object.id].sourceId = $object.sourceId
                }
            }
            $objects[$object.id].runs.Add(@{
                'status' = $localSnapshotInfo.snapshotInfo.status; 
                'startTime' = $localSnapshotInfo.snapshotInfo.startTimeUsecs; 
                'endTime' = $localSnapshotInfo.snapshotInfo.endTimeUsecs;
                'expiry' = $localSnapshotInfo.snapshotInfo.expiryTimeUsecs;
                'runType' = $run.localBackupInfo.runType
            })
        }
    }
}

$report = @()

foreach($id in $objects.Keys){
    $object = $objects[$id]
    $parent = $null
    if($object.sourceId -ne ''){
        $parent = $objects[$object.sourceId]
        if(!$parent){
            $parent = $sources.protectionSource | Where-Object id -eq $object.sourceId
        }
    }
    if($parent -or ($object.environment -eq $object.jobEnvironment)){
        $object.parent = $parent.name
        if($object.runDates.count -gt 1){
            $frequency = [math]::Round((($object.runDates[0] - $object.runDates[-1]) / ($object.runDates.count - 1)) / (1000000 * 60))
        }else{
            $frequency = '-'
        }
        $lastRunDate = usecsToDate $object.runDates[0]
        if(!$parent){
            $object.parent = '-'
        }
        foreach($run in $object.runs){
            $status = $run.status.subString(1)
            $startTime = (usecsToDate $run.startTime).ToString('MM/dd/yyyy HH:mm')
            $endTime = (usecsToDate $run.endTime).ToString('MM/dd/yyyy HH:mm')
            $expireTime = (usecsToDate $run.expiry).ToString('MM/dd/yyyy HH:mm')
            $duration = [math]::Round(($run.endTime - $run.startTime) / (1000000 * 60))
            $runType = $run.runType.subString(1)
            $report = @($report + ("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14}" -f $cluster.name, $object.jobName, $object.environment.subString(1), $object.name, $object.objectType.subString(1), $object.parent, $object.policyName, $frequency, $runType, $status, $startTime, $endTime, $duration, $expireTime, $object.jobPaused))
        }
    }
}

$report | Out-File -FilePath $outfileName -Append
$report = Import-Csv -Path $outfileName
$report | Sort-Object -Property 'Cluster Name', 'Job Name', 'Object Name', @{Expression={$_.'Start Time'}; Descending=$True} | Export-Csv -Path $outfileName

"`nOutput saved to $outfilename`n"
