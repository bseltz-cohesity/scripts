[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password,
    [Parameter()][switch]$useApiKey,
    [Parameter()][array]$objectName,
    [Parameter()][string]$objectList
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)


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

$objectNames = @(gatherList -Param $objectName -FilePath $objectList -Name 'objects' -Required $false)


### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -password $password -useApiKey 
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password 
}

$cluster = api get cluster

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-protectedObjectReport-$dateString.csv"

"`nCluster Name,Job Name,Environment,Object Name,Object Type,Parent,Policy Name,Frequency (Minutes),Last Backup,Last Status,Job Paused" | Out-File -FilePath $outfileName

$policies = api get -v2 "data-protect/policies"
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true"
$sources = api get protectionSources

$objects = @{}

"`nGathering Job Info from $($cluster.name)..."
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    "    $($job.name)"
    $policy = $policies.policies | Where-Object id -eq $job.policyId
    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?includeObjectDetails=true&numRuns=7"
    if($runs.runs[0].PSObject.Properties['localBackupInfo']){
        $isCad = $false
        if('kLog' -in $runs.runs.localBackupInfo.runType){
            $runDates = ($runs.runs | Where-Object {$_.localBackupInfo.runType -eq 'kLog'}).localBackupInfo.startTimeUsecs
        }else{
            $runDates = $runs.runs.localBackupInfo.startTimeUsecs
        }
    }else{
        $isCad = $True
        # $runs.runs[0] | toJson
        if('kLog' -in $runs.runs.archivalInfo.archivalTargetResults[0].runType){
            $runDates = ($runs.runs | Where-Object {$_.archivalInfo.archivalTargetResults.runType -eq 'kLog'}).archivalInfo.archivalTargetResults[0].startTimeUsecs
        }else{
            $runDates = $runs.runs.archivalInfo.archivalTargetResults.startTimeUsecs
        }
    }

    # $lastStatus = $runs.runs[0].localBackupInfo.status
    foreach($run in $runs.runs){
        foreach($object in $run.objects){
            if($isCad){
                $snapInfo = $object.archivalInfo.archivalTargetResults[0]
                $lastStatus = $snapInfo.status
            }else{
                $snapInfo = $object.localSnapshotInfo.snapshotInfo
                $lastStatus = $snapInfo.status.subString(1)
            }
            if($object.object.id -notin $objects.Keys){
                $objects[$object.object.id] = @{
                    'name' = $object.object.name;
                    'id' = $object.object.id;
                    'objectType' = $object.object.objectType;
                    'environment' = $object.object.environment;
                    'jobName' = $job.name;
                    'policyName' = $policy.name;
                    'jobEnvironment' = $job.environment;
                    'runDates' = $runDates;
                    'sourceId' = '';
                    'parent' = '';
                    'lastStatus' = $lastStatus;
                    'jobPaused' = $job.isPaused
                }
                if($object.object.PSObject.Properties['sourceId']){
                    $objects[$object.object.id].sourceId = $object.object.sourceId
                }
            }
        }
    }
}

$report = @()

foreach($id in $objects.Keys){
    $object = $objects[$id]
    if($objectNames.Count -eq 0 -or $object.name -in $objectNames){
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
            $report = @($report + ("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}" -f $cluster.name, $object.jobName, $object.environment.subString(1), $object.name, $object.objectType.subString(1), $object.parent, $object.policyName, $frequency, $lastRunDate, $object.lastStatus, $object.jobPaused))
        }
    }
}

$report | Sort-Object | Out-File -FilePath $outfileName -Append

"`nOutput saved to $outfilename`n"
