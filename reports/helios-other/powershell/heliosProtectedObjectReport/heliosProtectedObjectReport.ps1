[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username='helios',
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -helios

$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "heliosProtectedObjectReport-$dateString.csv"

"`nCluster Name,Job Name,Environment,Object Name,Object Type,Parent,Policy Name,Frequency (Minutes),Last Backup,Last Status,Job Paused,Alert Recipients" | Out-File -FilePath $outfileName

foreach($cluster in heliosClusters){
    Write-Host ''
    heliosCluster $cluster

    $policies = api get -v2 "data-protect/policies"
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&onlyReturnBasicSummary=true"
    $sources = api get "protectionSources?numLevels=2&excludeTypes=kDatastore,kVirtualMachine,kVirtualApp,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&useCachedData=true"

    $objects = @{}

    # "`nGathering Job Info from $($cluster.name)..."
    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        "    $($job.name)"
        $policy = $policies.policies | Where-Object id -eq $job.policyId
        $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?includeObjectDetails=true&numRuns=7"
        if($runs.runs[0].PSObject.Properties['localBackupInfo']){
            $runDates = @($runs.runs.localBackupInfo.startTimeUsecs)
            $lastStatus = $runs.runs[0].localBackupInfo.status
        }else{
            $runDates = @($runs.runs.archivalInfo.archivalTargetResults.startTimeUsecs)
            $lastStatus = $runs.runs[0].archivalInfo.archivalTargetResults.status
        }
        
        foreach($run in $runs.runs){
            foreach($object in $run.objects.object){
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
                        'lastStatus' = $lastStatus;
                        'jobPaused' = $job.isPaused
                        'jobAlertRecipients' = $job.alertPolicy.alertTargets.emailAddress -join '; '
                    }
                    if($object.PSObject.Properties['sourceId']){
                        $objects[$object.id].sourceId = $object.sourceId
                    }
                }
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
                $lastRunDate = usecsToDate $object.runDates[0]
            }else{
                $frequency = '-'
                $lastRunDate = '-'
            }
            
            if(!$parent){
                $object.parent = '-'
            }
            $report = @($report + ("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11}" -f $cluster.name, $object.jobName, $object.environment.subString(1), $object.name, $object.objectType.subString(1), $object.parent, $object.policyName, $frequency, $lastRunDate, $object.lastStatus, $object.jobPaused, $object.jobAlertRecipients))
        }
    }

    $report | Sort-Object | Out-File -FilePath $outfileName -Append
}

"`nReport saved to $outfilename`n"
