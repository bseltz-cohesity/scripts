# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][int]$days,
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB')][string]$unit = 'MiB',
    [Parameter()][int]$numRuns = 500
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

if($days){
    $daysBack = (Get-Date).AddDays(-$days)
    $daysBackUsecs = dateToUsecs $daysBack
}

# outfile
$cluster = api get cluster
$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "openshiftRunsReport-$($cluster.name)-$dateString.csv"

# headings
"""Cluster Name"",""Tenant"",""Job Name"",""Run Type"",""Source Name"",""Namespace"",""Start Time"",""End Time"",""Status"",""NameSpace"",""VM""" | Out-File -FilePath $outfileName

# convert to units
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
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

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kKubernetes"

if(! $jobs.protectionGroups){
    Write-Host "No Kubernetes Protected on this cluster" -ForegroundColor Yellow
    exit 1
}
if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$sources = api get protectionSources/registrationInfo?includeApplicationsTreeInfo=false
$policies = api get -v2 data-protect/policies

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $endUsecs = dateToUsecs (Get-Date)
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $environment = $job.environment.subString(1)
        $tenant = $job.permissions.name
        $job.name
        $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
        $lastRunId = 0
        while($True){
            if($days){
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&startTimeUsecs=$daysBackUsecs&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true"
            }else{
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true"
            }
            if($lastRunId -ne 0){
                # skip runs we already saw
                $runs.runs = $runs.runs | Where-Object {$_.id -lt $lastRunId}
            }
            foreach($run in $runs.runs){

                # run level stats
                if($run.PSObject.Properties['localBackupInfo']){
                    $runType = $run.localBackupInfo.runType.subString(1)
                }else{
                    break
                }
                if($runType -eq 'Regular'){
                    $runType = 'Incremental'
                }

                $runStartTime = usecsToDate $run.localBackupInfo.startTimeUsecs
                if($days -and $daysBack -gt $runStartTime){
                    break
                }
                $status = $run.localBackupInfo.status
                $runEndTime = $null
                if($run.localBackupInfo.PSObject.Properties['endTimeUsecs']){
                    $runEndTime = usecsToDate $run.localBackupInfo.endTimeUsecs
                }
                "    {0} ({1})" -f $runStartTime, $status
                # write to output file
                """$($cluster.name)"",""$tenant"",""$($job.name)"",""$runType"",""$runStartTime"",""-"",""-"",""-"",""-"",""$status"",""-""" | Out-File -FilePath $outfileName -Append
                # object level stats
                foreach($object in $run.objects){
                    $objectName = $object.object.name
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
                    if($registeredSourceName){
                        "        {0}: {1}" -f $registeredSourceName, $objectName
                    }else{
                        "        {0}" -f $objectName
                    }
                    $snapId = $object.localSnapshotInfo.snapshotInfo.snapshotId
                    $metaParams = @{
                        "environment" = "kKubernetes";
                        "kubernetesParams" = @{
                            "objectId" = $object.object.id
                        }
                    }
                    $metaInfo = api post -v2 "data-protect/snapshots/$snapId/meta-info" $metaParams
                    $vms = $metaInfo.kubernetesParams.backedUpResources.resourceList.name
                    foreach($vm in $vms){
                        # write to output file
                        """$($cluster.name)"",""$tenant"",""$($job.name)"",""$runType"",""$runStartTime"",""$registeredSourceName"",""$objectName"",""$objectStartTime"",""$objectEndTime"",""$objectStatus"",""$vm""" | Out-File -FilePath $outfileName -Append
                    }
                }
            }
            if(!$runs.runs -or $runs.runs.Count -eq 0 -or $runs.runs[-1].id -eq $lastRunId){
                # if there are no runs then we are done
                break
            }else{
                $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs
                if($endUsecs -lt 0 -or $endUsecs -lt $daysBackUsecs){
                    break
                }
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
